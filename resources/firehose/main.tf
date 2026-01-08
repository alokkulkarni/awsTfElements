resource "aws_kinesis_firehose_delivery_stream" "log_stream" {
  name        = "${var.project_name}-firehose-logs"
  destination = "extended_s3"

  # Optional Kinesis Source Configuration
  dynamic "kinesis_source_configuration" {
    for_each = var.kinesis_source_arn != null ? [1] : []
    content {
      kinesis_stream_arn = var.kinesis_source_arn
      role_arn           = aws_iam_role.firehose_delivery.arn
    }
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_delivery.arn
    bucket_arn = var.destination_bucket_arn
    prefix     = "${var.destination_prefix}year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "${var.destination_prefix}errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_size = 5
    buffering_interval = 300

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_error_logging.name
      log_stream_name = "DestinationDelivery"
    }

    # Dynamic block for KMS if provided
    dynamic "processing_configuration" {
      for_each = var.enable_processing ? [1] : []
      content {
        enabled = "true"
        processors {
          type = "Lambda"
          parameters {
            parameter_name  = "LambdaArn"
            parameter_value = var.processing_lambda_arn
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "firehose_error_logging" {
  name = "/aws/kinesisfirehose/${var.project_name}-firehose-logs"
  retention_in_days = 7
  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM Role for Firehose to write to S3
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "firehose_delivery" {
  name = "${var.project_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_policy" "firehose_delivery_policy" {
  name        = "${var.project_name}-firehose-policy"
  description = "Permissions for Firehose to write to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          var.destination_bucket_arn,
          "${var.destination_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect = "Allow"
        Resource = var.kms_key_arn != null ? [var.kms_key_arn] : ["*"]
        Condition = var.kms_key_arn != null ? {} : {
            "StringEquals": {
                "aws:RequestedRegion": data.aws_region.current.name
            }
        } 
      },
      {
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Effect = "Allow"
        Resource = var.kinesis_source_arn != null ? [var.kinesis_source_arn] : []
      },
      {
         Action = [
             "logs:PutLogEvents"
         ]
         Effect = "Allow"
         Resource = [
             "${aws_cloudwatch_log_group.firehose_error_logging.arn}:*"
         ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_firehose_policy" {
  role       = aws_iam_role.firehose_delivery.name
  policy_arn = aws_iam_policy.firehose_delivery_policy.arn
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# IAM Role for CloudWatch Logs to push to Firehose
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "cloudwatch_to_firehose" {
  name = "${var.project_name}-cw-to-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_policy" "cloudwatch_to_firehose_policy" {
  name = "${var.project_name}-cw-to-firehose-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow",
            Action = "firehose:PutRecord",
            Resource = aws_kinesis_firehose_delivery_stream.log_stream.arn
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_to_firehose_attach" {
    role = aws_iam_role.cloudwatch_to_firehose.name
    policy_arn = aws_iam_policy.cloudwatch_to_firehose_policy.arn
}
