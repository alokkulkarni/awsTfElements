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
  source      = "../resources/s3"
  bucket_name = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"
  tags        = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Amazon Connect Instance
# ---------------------------------------------------------------------------------------------------------------------
module "connect_instance" {
  source         = "../resources/connect"
  instance_alias = var.connect_instance_alias
  tags           = var.tags
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

# ---------------------------------------------------------------------------------------------------------------------
# DynamoDB for New Intent Logging
# ---------------------------------------------------------------------------------------------------------------------
module "intent_table" {
  source     = "../resources/dynamodb"
  table_name = "${var.project_name}-new-intents"
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
  source_dir  = "${path.module}/lambda/lex_fallback"
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
        Resource = module.intent_table.table_arn
      }
    ]
  })
}

resource "aws_lambda_function" "lex_fallback" {
  filename         = data.archive_file.lex_fallback_zip.output_path
  function_name    = "${var.project_name}-lex-fallback"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lex_fallback_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  environment {
    variables = {
      INTENT_TABLE_NAME = module.intent_table.name
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Amazon Lex Bot
# ---------------------------------------------------------------------------------------------------------------------
# Using the module for the bot shell
module "lex_bot" {
  source                 = "../resources/lex"
  bot_name               = "${var.project_name}-bot"
  fulfillment_lambda_arn = aws_lambda_function.lex_fallback.arn
  tags                   = var.tags
}

# We need to define the Bot Locale, Intents, and Slots explicitly as the module is minimal
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id          = module.lex_bot.bot_id
  bot_version     = "DRAFT"
  locale_id       = "en_US"
  nlu_confidence_threshold = 0.40
}

resource "aws_lexv2models_intent" "fallback_intent" {
  bot_id      = module.lex_bot.bot_id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "FallbackIntent"
  parent_intent_signature = "AMAZON.FallbackIntent"

  fulfillment_code_hook {
    enabled = true
  }
}

resource "aws_lexv2models_intent" "transfer_agent" {
  bot_id      = module.lex_bot.bot_id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "TransferToAgent"
  description = "Transfer to a human agent"
  
  sample_utterances {
    utterance = "I want to speak to a human"
  }
  sample_utterances {
    utterance = "Agent please"
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
resource "aws_connect_queue" "agent_queue" {
  instance_id = module.connect_instance.id
  name        = "GeneralAgentQueue"
  description = "Queue for general agents"
  hours_of_operation_id = module.connect_instance.hours_of_operation_id # Using default from module output if available, else need to fetch
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
  description  = "Main flow with Lex integration"
  type         = "CONTACT_FLOW"
  content      = jsonencode({
    # Simplified JSON representation of a flow
    # In reality, this is a complex JSON structure. 
    # I will use a minimal valid structure or a placeholder.
    Version = "2019-10-30"
    StartAction = "GetUserInput"
    Actions = [
      {
        Identifier = "GetUserInput"
        Type = "GetUserInput"
        Parameters = {
          Text = "How can I help you today?"
          BotName = module.lex_bot.bot_name
          BotAlias = "TestBotAlias" # Need to create alias
        }
        Transitions = {
          NextAction = "CheckIntent"
          Errors = [],
          Conditions = []
        }
      },
      {
        Identifier = "CheckIntent"
        Type = "CheckAttribute"
        # ... logic to check intent and route to queue ...
        Transitions = {
            NextAction = "TransferToQueue"
        }
      },
      {
        Identifier = "TransferToQueue"
        Type = "TransferToQueue"
        Parameters = {
            QueueId = aws_connect_queue.agent_queue.arn
        }
      }
    ]
  })
  tags = var.tags
}

# We need a Bot Alias for Connect to use
resource "aws_lexv2models_bot_alias" "test_alias" {
  bot_id      = module.lex_bot.bot_id
  bot_alias_name = "TestBotAlias"
  bot_version = "DRAFT"
  bot_alias_locale_settings {
    locale_id = aws_lexv2models_bot_locale.en_us.locale_id
    bot_alias_locale_setting {
      enabled = true
      code_hook_specification {
        lambda_code_hook {
          code_hook_interface_version = "1.0"
          lambda_arn = aws_lambda_function.lex_fallback.arn
        }
      }
    }
  }
}

# Associate Lex Bot with Connect Instance
resource "aws_connect_bot_association" "this" {
  instance_id = module.connect_instance.id
  lex_bot {
    lex_region = var.region
    name       = module.lex_bot.bot_name
  }
}

