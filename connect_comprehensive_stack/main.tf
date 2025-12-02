data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# KMS Key for Encryption (Zero Trust)
# ---------------------------------------------------------------------------------------------------------------------
module "kms_key" {
  source      = "../resources/kms"
  description = "KMS key for Connect Comprehensive Stack"
  tags        = var.tags
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Connect to use the key"
        Effect = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 Bucket for Connect Storage (Recordings, Transcripts)
# ---------------------------------------------------------------------------------------------------------------------
module "connect_storage_bucket" {
  source           = "../resources/s3"
  bucket_name      = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"
  enable_lifecycle = true
  tags             = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Amazon Connect Instance
# ---------------------------------------------------------------------------------------------------------------------
module "connect_instance" {
  source                    = "../resources/connect"
  instance_alias            = var.connect_instance_alias
  contact_flow_logs_enabled = true
  contact_lens_enabled      = true
  tags                      = var.tags
}

# Connect Storage Configuration
resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = module.connect_instance.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    s3_config {
      bucket_name = module.connect_storage_bucket.id
      bucket_prefix = "chat-transcripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.key_id
      }
    }
    storage_type = "S3"
  }
}

resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = module.connect_instance.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    s3_config {
      bucket_name = module.connect_storage_bucket.id
      bucket_prefix = "call-recordings"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.key_id
      }
    }
    storage_type = "S3"
  }
}

resource "aws_connect_instance_storage_config" "real_time_analysis" {
  instance_id   = module.connect_instance.id
  resource_type = "REAL_TIME_CONTACT_ANALYSIS_SEGMENTS"

  storage_config {
    s3_config {
      bucket_name = module.connect_storage_bucket.id
      bucket_prefix = "real-time-analysis"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.key_id
      }
    }
    storage_type = "S3"
  }
}

resource "aws_connect_instance_storage_config" "contact_trace_records" {
  instance_id   = module.connect_instance.id
  resource_type = "CONTACT_TRACE_RECORDS"

  storage_config {
    s3_config {
      bucket_name = module.connect_storage_bucket.id
      bucket_prefix = "contact-trace-records"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.key_id
      }
    }
    storage_type = "S3"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DynamoDB for New Intent Logging
# ---------------------------------------------------------------------------------------------------------------------
module "intent_table" {
  source     = "../resources/dynamodb"
  name       = "${var.project_name}-new-intents"
  hash_key   = "utterance"
  range_key  = "timestamp"
  tags       = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Bedrock Guardrail
# ---------------------------------------------------------------------------------------------------------------------
module "bedrock_guardrail" {
  source                    = "../resources/bedrock_guardrail"
  name                      = "${var.project_name}-guardrail"
  description               = "Guardrail for Connect Chatbot"
  blocked_input_messaging   = "I cannot process that input."
  blocked_outputs_messaging = "I cannot provide that output."
  tags                      = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Lambda for Lex Fallback (calls Bedrock)
# ---------------------------------------------------------------------------------------------------------------------
data "archive_file" "lex_fallback_zip" {
  type        = "zip"
  source_dir  = "${path.module}/${var.lex_fallback_lambda.source_dir}"
  output_path = "${path.module}/lambda/lex_fallback.zip"
}

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
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect   = "Allow"
        Resource = "*" # Scope to specific model ARN in production
      },
      {
        Action = [
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = module.intent_table.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lex_fallback" {
  name              = "/aws/lambda/${var.project_name}-lex-fallback"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_lambda_function" "lex_fallback" {
  filename         = data.archive_file.lex_fallback_zip.output_path
  function_name    = "${var.project_name}-lex-fallback"
  role             = aws_iam_role.lambda_role.arn
  handler          = var.lex_fallback_lambda.handler
  source_code_hash = data.archive_file.lex_fallback_zip.output_base64sha256
  runtime          = var.lex_fallback_lambda.runtime
  timeout          = var.lex_fallback_lambda.timeout

  environment {
    variables = {
      INTENT_TABLE_NAME = module.intent_table.name
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags
  
  depends_on = [aws_cloudwatch_log_group.lex_fallback]
}

# ---------------------------------------------------------------------------------------------------------------------
# Amazon Lex Bot
# ---------------------------------------------------------------------------------------------------------------------
# Using the module for the bot shell
module "lex_bot" {
  source                 = "../resources/lex"
  bot_name               = "${var.project_name}-bot"
  fulfillment_lambda_arn = aws_lambda_function.lex_fallback.arn
  locale                 = var.locale
  voice_id               = var.voice_id
  tags                   = var.tags
}

# We need to define the Bot Locale, Intents, and Slots explicitly as the module is minimal
# Note: The module creates the locale "en_US" and a FallbackIntent.

resource "aws_lexv2models_intent" "intents" {
  for_each = var.lex_intents

  bot_id      = module.lex_bot.bot_id
  bot_version = "DRAFT"
  locale_id   = module.lex_bot.locale_id
  name        = each.key
  description = each.value.description
  
  dynamic "sample_utterance" {
    for_each = each.value.utterances
    content {
      utterance = sample_utterance.value
    }
  }

  dynamic "fulfillment_code_hook" {
    for_each = each.value.fulfillment_enabled ? [1] : []
    content {
      enabled = true
    }
  }
}

# Permission for Lex to invoke Lambda
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lex_fallback.function_name
  principal     = "lex.amazonaws.com"
  source_arn    = module.lex_bot.bot_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# Connect Queue & Routing Profile
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_connect_queue" "queues" {
  for_each = var.queues

  instance_id = module.connect_instance.id
  name        = each.key
  description = each.value.description
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  tags        = var.tags
}

# Note: The connect module might not output hours_of_operation_id. 
# If not, we need a data source to find the default one.

data "aws_connect_hours_of_operation" "default" {
  instance_id = module.connect_instance.id
  name        = "Basic Hours" # Default name usually
}

# ---------------------------------------------------------------------------------------------------------------------
# Connect Contact Flow
# ---------------------------------------------------------------------------------------------------------------------
# This defines the IVR/Chat experience
resource "aws_connect_contact_flow" "main_flow" {
  instance_id  = module.connect_instance.id
  name         = "MainIVRFlow"
  description  = "Main flow with Lex integration and Agent Routing"
  type         = "CONTACT_FLOW"
  content      = templatefile("${path.module}/${var.contact_flow_template_path}", {
    lex_bot_name         = module.lex_bot.bot_name
    general_queue_arn    = aws_connect_queue.queues["GeneralAgentQueue"].arn
    account_queue_arn    = aws_connect_queue.queues["AccountQueue"].arn
    lending_queue_arn    = aws_connect_queue.queues["LendingQueue"].arn
    onboarding_queue_arn = aws_connect_queue.queues["OnboardingQueue"].arn
    locale               = replace(var.locale, "_", "-")
  })
  tags = var.tags
}



# Associate Lex Bot with Connect Instance
resource "aws_connect_bot_association" "this" {
  instance_id = module.connect_instance.id
  lex_bot {
    lex_region = var.region
    name       = module.lex_bot.bot_name
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudTrail for Auditing
# ---------------------------------------------------------------------------------------------------------------------
module "cloudtrail_bucket" {
  source            = "../resources/s3"
  bucket_name       = "${var.project_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  enable_lifecycle  = true
  attach_policy     = true
  policy            = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
  tags              = var.tags
}

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.project_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.project_name}-cloudtrail-${data.aws_caller_identity.current.account_id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = module.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true

  tags = var.tags
  
  depends_on = [module.cloudtrail_bucket]
}

