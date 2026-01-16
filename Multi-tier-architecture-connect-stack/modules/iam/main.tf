# ============================================================================
# IAM Roles and Policies Module
# This module creates all IAM roles and policies with least privilege principle
# ============================================================================

# ============================================================================
# AWS Connect IAM Role
# ============================================================================
resource "aws_iam_role" "connect" {
  name = "${var.project_name}-${var.environment}-connect-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "connect_policy" {
  name = "${var.project_name}-${var.environment}-connect-policy"
  role = aws_iam_role.connect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lex:PostContent",
          "lex:PostText",
          "lex:RecognizeText",
          "lex:RecognizeUtterance"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${var.region}:${var.account_id}:function:${var.project_name}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/connect/*"
      },
      {
        Sid    = "S3GeneralStorageAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-connect-storage-*/*"
      },
      {
        Sid    = "S3ListBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-connect-storage-*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-original-transcripts-*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-redacted-transcripts-*"
        ]
      },
      {
        Sid    = "S3OriginalTranscriptsWrite"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-original-transcripts-*/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "S3RedactedTranscriptsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-redacted-transcripts-*/*"
      },
      {
        Sid    = "ContactLensPermissions"
        Effect = "Allow"
        Action = [
          "connect:StartContactRecording",
          "connect:StopContactRecording",
          "connect:StartContactStreaming",
          "connect:StopContactStreaming"
        ]
        Resource = "*"
      },
      {
        Sid    = "KinesisVideoStreamPermissions"
        Effect = "Allow"
        Action = [
          "kinesisvideo:CreateStream",
          "kinesisvideo:DescribeStream",
          "kinesisvideo:GetDataEndpoint",
          "kinesisvideo:PutMedia"
        ]
        Resource = "arn:aws:kinesisvideo:${var.region}:${var.account_id}:stream/${var.project_name}-*"
      },
      {
        Sid    = "KMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [
          "arn:aws:kms:${var.region}:${var.account_id}:key/*"
        ]
      },
      {
        Sid    = "TranscriptAnalysisPermissions"
        Effect = "Allow"
        Action = [
          "transcribe:StartStreamTranscription",
          "transcribe:StartCallAnalyticsStreamTranscription",
          "comprehend:DetectPiiEntities",
          "comprehend:ContainsPiiEntities"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Lex Bot IAM Role
# ============================================================================
resource "aws_iam_role" "lex" {
  name = "${var.project_name}-${var.environment}-lex-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lexv2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lex_policy" {
  name = "${var.project_name}-${var.environment}-lex-policy"
  role = aws_iam_role.lex.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "polly:SynthesizeSpeech"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${var.region}:${var.account_id}:function:${var.project_name}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/lex/*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent",
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.region}:${var.account_id}:agent/*"
      }
    ]
  })
}

# ============================================================================
# Lambda Execution IAM Role
# ============================================================================
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-${var.environment}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:${var.region}:*:table/${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "connect:GetContactAttributes",
          "connect:UpdateContactAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Bedrock Agent IAM Role
# ============================================================================
resource "aws_iam_role" "bedrock_agent" {
  name = "${var.project_name}-${var.environment}-bedrock-agent-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${var.region}:${var.account_id}:agent/*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_agent_policy" {
  name = "${var.project_name}-${var.environment}-bedrock-agent-policy"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/bedrock/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-connect-storage/*"
      }
    ]
  })
}

# ============================================================================
# Bedrock Agent Knowledge Base IAM Role (if needed for future extensions)
# ============================================================================
resource "aws_iam_role" "bedrock_kb" {
  name = "${var.project_name}-${var.environment}-bedrock-kb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_kb_policy" {
  name = "${var.project_name}-${var.environment}-bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = "arn:aws:aoss:${var.region}:*:collection/*"
      }
    ]
  })
}
