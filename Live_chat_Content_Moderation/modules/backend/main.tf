# API Gateway
resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api-gateway/${var.project_name}"
  retention_in_days = 30
  tags              = var.tags
}

module "apigateway" {
  source = "../../../resources/apigateway"

  name                = "${var.project_name}-api"
  protocol_type       = "HTTP"
  stage_name          = "$default"
  auto_deploy         = true
  log_destination_arn = aws_cloudwatch_log_group.api_gw.arn
  log_format          = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )

  tags = var.tags
}


# SQS FIFO Queue
module "sqs_dlq" {
  source = "../../../resources/sqs"

  name                        = "${var.project_name}-dlq.fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  tags = var.tags
}

module "sqs_queue" {
  source = "../../../resources/sqs"

  name                        = "${var.project_name}-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = module.sqs_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

# Lambda Function
module "lambda" {
  source = "../../../resources/lambda"

  filename      = "lambda_function_payload.zip" # Placeholder
  function_name = "${var.project_name}-backend"
  role_arn      = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  environment_variables = merge(
    {
      QUEUE_URL         = module.sqs_queue.url
      GUARDRAIL_ID      = var.guardrail_id
      GUARDRAIL_VERSION = var.guardrail_version
    },
    { for k, v in var.dynamodb_tables : "${upper(k)}_TABLE_NAME" => v.name }
  )

  tags = var.tags
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda (Least Privilege)
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [for t in values(var.dynamodb_tables) : t.arn]
      },
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = module.sqs_queue.arn
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = module.sqs_dlq.arn
      },
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict to specific model ARN in production
      },
      {
        Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
# AppSync
module "appsync" {
  source = "../../../resources/appsync"

  name                         = "${var.project_name}-appsync"
  authentication_type          = "API_KEY" # Or AWS_IAM / AMAZON_COGNITO_USER_POOLS for better security
  xray_enabled                 = true
  log_cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn

  tags = var.tags
}

resource "aws_iam_role" "appsync_logs" {
  name = "${var.project_name}-appsync-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "appsync_logs" {
  role       = aws_iam_role.appsync_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppSyncPushToCloudWatchLogs"
}

resource "aws_appsync_datasource" "lambda" {
  api_id           = module.appsync.id
  name             = "LambdaDataSource"
  service_role_arn = aws_iam_role.appsync_role.arn
  type             = "AWS_LAMBDA"

  lambda_config {
    function_arn = module.lambda.arn
  }
}

# IAM Role for AppSync
resource "aws_iam_role" "appsync_role" {
  name = "${var.project_name}-appsync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "appsync_policy" {
  name = "${var.project_name}-appsync-policy"
  role = aws_iam_role.appsync_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = module.lambda.arn
      }
    ]
  })
}

