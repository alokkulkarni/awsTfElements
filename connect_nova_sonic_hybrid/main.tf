data "aws_caller_identity" "current" {}

# -------------------------------------------------------------------------
# Shared Resources (Bedrock Guardrail)
# -------------------------------------------------------------------------
module "bedrock_guardrail" {
  source      = "../resources/bedrock_guardrail"
  name        = "${var.project_name}-guardrail"
  description = "Guardrail for Hybrid Connect/Nova Sonic Architecture"
  tags = {
    Project = var.project_name
  }
}

# -------------------------------------------------------------------------
# IAM Roles (Zero Trust - Least Privilege)
# -------------------------------------------------------------------------

# Chat Lambda Role (Text Model Access Only)
resource "aws_iam_role" "lambda_chat_role" {
  name = "${var.project_name}-chat-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_chat_policy" {
  name = "${var.project_name}-chat-policy"
  role = aws_iam_role.lambda_chat_role.id

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = "bedrock:InvokeModel"
        # Restrict to specific text models and the specific guardrail
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
          module.bedrock_guardrail.guardrail_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.conversation_context.arn
      },
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = aws_lambda_function.mcp_server.arn
      }
    ]
  })
}

# Voice Lambda Role (Nova Sonic Stream Access Only)
resource "aws_iam_role" "lambda_voice_role" {
  name = "${var.project_name}-voice-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_voice_policy" {
  name = "${var.project_name}-voice-policy"
  role = aws_iam_role.lambda_voice_role.id

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = "bedrock:InvokeModelWithResponseStream"
        # Restrict to Nova Sonic model and the specific guardrail
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-sonic-v1:0",
          module.bedrock_guardrail.guardrail_arn
        ]
      },
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = aws_lambda_function.mcp_server.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = [
          aws_dynamodb_table.hallucination_feedback.arn,
          aws_dynamodb_table.conversation_context.arn
        ]
      }
    ]
  })
}

# -------------------------------------------------------------------------
# Lambda Functions
# -------------------------------------------------------------------------

data "archive_file" "lambda_chat_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_chat"
  output_path = "${path.module}/lambda_chat.zip"
}

resource "aws_lambda_function" "chat_fulfillment" {
  filename         = data.archive_file.lambda_chat_zip.output_path
  function_name    = "${var.project_name}-chat-fulfillment"
  role             = aws_iam_role.lambda_chat_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_chat_zip.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30

  environment {
    variables = {
      GUARDRAIL_ID       = module.bedrock_guardrail.guardrail_id
      GUARDRAIL_VERSION  = module.bedrock_guardrail.guardrail_version
      CONTEXT_TABLE_NAME = aws_dynamodb_table.conversation_context.name
      MCP_FUNCTION_NAME  = aws_lambda_function.mcp_server.function_name
    }
  }
}

data "archive_file" "lambda_voice_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_voice"
  output_path = "${path.module}/lambda_voice.zip"
}

resource "aws_lambda_function" "voice_orchestrator" {
  filename         = data.archive_file.lambda_voice_zip.output_path
  function_name    = "${var.project_name}-voice-orchestrator"
  role             = aws_iam_role.lambda_voice_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_voice_zip.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 60

  environment {
    variables = {
      GUARDRAIL_ID        = module.bedrock_guardrail.guardrail_id
      GUARDRAIL_VERSION   = module.bedrock_guardrail.guardrail_version
      MCP_FUNCTION_NAME   = aws_lambda_function.mcp_server.function_name
      FEEDBACK_TABLE_NAME = aws_dynamodb_table.hallucination_feedback.name
      CONTEXT_TABLE_NAME  = aws_dynamodb_table.conversation_context.name
    }
  }
}

# -------------------------------------------------------------------------
# Amazon Connect
# -------------------------------------------------------------------------

resource "aws_connect_instance" "this" {
  identity_management_type = "CONNECT_MANAGED"
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true
  instance_alias           = "${var.project_name}-instance"
  contact_lens_enabled     = true # Enable Contact Lens for Analytics
}

# Connect Storage Config - Chat Transcripts
resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    s3_config {
      bucket_name   = aws_s3_bucket.audit_logs.id
      bucket_prefix = "connect/chat-transcripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = aws_kms_key.log_key.arn
      }
    }
    storage_type = "S3"
  }
}

# Connect Storage Config - Call Recordings
resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    s3_config {
      bucket_name   = aws_s3_bucket.audit_logs.id
      bucket_prefix = "connect/call-recordings"
      encryption_config {
        encryption_type = "KMS"
        key_id          = aws_kms_key.log_key.arn
      }
    }
    storage_type = "S3"
  }
}

# Associate Lambdas with Connect
resource "aws_connect_lambda_function_association" "chat" {
  instance_id  = aws_connect_instance.this.id
  function_arn = aws_lambda_function.chat_fulfillment.arn
}

resource "aws_connect_lambda_function_association" "voice" {
  instance_id  = aws_connect_instance.this.id
  function_arn = aws_lambda_function.voice_orchestrator.arn
}

# -------------------------------------------------------------------------
# Amazon Bedrock Logging
# -------------------------------------------------------------------------
resource "aws_bedrock_model_invocation_logging_configuration" "main" {
  logging_config {
    embedding_data_delivery_enabled = true
    image_data_delivery_enabled     = true
    text_data_delivery_enabled      = true
    
    s3_config {
      bucket_name = aws_s3_bucket.audit_logs.id
      key_prefix  = "bedrock/logs"
    }
  }
  depends_on = [aws_s3_bucket_policy.audit_logs]
}

# -------------------------------------------------------------------------
# Amazon Lex V2 (Chat Channel)
# -------------------------------------------------------------------------

resource "aws_lexv2models_bot" "chat_bot" {
  name                        = "${var.project_name}-chat-bot"
  description                 = "Lex Bot for Text Chat Channel"
  idle_session_ttl_in_seconds = 300
  role_arn                    = aws_iam_role.lex_role.arn

  data_privacy {
    child_directed = false
  }
}

resource "aws_iam_role" "lex_role" {
  name = "${var.project_name}-lex-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lex.amazonaws.com"
      }
    }]
  })
}

# Lex Bot Locale & Intent
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id          = aws_lexv2models_bot.chat_bot.id
  bot_version     = "DRAFT"
  locale_id       = "en_US"
  n_lu_intent_confidence_threshold = 0.40
}

resource "aws_lexv2models_intent" "fallback" {
  bot_id      = aws_lexv2models_bot.chat_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "FallbackIntent"
  
  parent_intent_signature = "AMAZON.FallbackIntent"

  fulfillment_code_hook {
    enabled = true
  }
}

resource "aws_lexv2models_slot_type" "department" {
  bot_id      = aws_lexv2models_bot.chat_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "DepartmentType"
  
  slot_type_values {
    sample_value { value = "Sales" }
  }
  slot_type_values {
    sample_value { value = "Support" }
  }
  slot_type_values {
    sample_value { value = "Billing" }
  }
  
  value_selection_setting {
    resolution_strategy = "OriginalValue"
  }
}

resource "aws_lexv2models_intent" "talk_to_agent" {
  bot_id      = aws_lexv2models_bot.chat_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "TalkToAgent"
  
  sample_utterance { utterance = "I want to speak to an agent" }
  sample_utterance { utterance = "Transfer me to {Department}" }
  sample_utterance { utterance = "Can I talk to {Department}" }
  sample_utterance { utterance = "Connect me to a human" }
  
  fulfillment_code_hook {
    enabled = true
  }
}

resource "aws_lexv2models_slot" "department" {
  bot_id      = aws_lexv2models_bot.chat_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  intent_id   = aws_lexv2models_intent.talk_to_agent.intent_id
  name        = "Department"
  slot_type_id = aws_lexv2models_slot_type.department.slot_type_id
  
  value_elicitation_setting {
    slot_constraint = "Required"
    prompt_specification {
      message_group {
        message {
          plain_text_message {
            value = "Which department would you like to speak with? Sales, Support, or Billing?"
          }
        }
      }
      max_retries = 3
    }
  }
}

resource "aws_lexv2models_bot_version" "initial" {
  bot_id = aws_lexv2models_bot.chat_bot.id
  locale_specification = {
    (aws_lexv2models_bot_locale.en_us.locale_id) = {
      source_bot_version = "DRAFT"
    }
  }
  depends_on = [
    aws_lexv2models_intent.fallback,
    aws_lexv2models_intent.talk_to_agent
  ]
}

resource "awscc_lex_bot_alias" "prod" {
  bot_id      = aws_lexv2models_bot.chat_bot.id
  bot_version = aws_lexv2models_bot_version.initial.bot_version
  bot_alias_name = "prod"
  
  bot_alias_locale_settings = [
    {
      locale_id = "en_US"
      bot_alias_locale_setting = {
        enabled = true
        code_hook_specification = {
          lambda_code_hook = {
            code_hook_interface_version = "1.0"
            lambda_arn = aws_lambda_function.chat_fulfillment.arn
          }
        }
      }
    }
  ]
}

# Associate Lex with Connect
resource "aws_connect_bot_association" "this" {
  instance_id = aws_connect_instance.this.id
  lex_bot {
    lex_region = var.aws_region
    name       = awscc_lex_bot_alias.prod.arn 
  }
}

# Allow Lex to invoke Chat Lambda
resource "aws_lambda_permission" "lex_invoke_chat" {
  statement_id  = "AllowLexInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_fulfillment.function_name
  principal     = "lex.amazonaws.com"
  source_arn    = awscc_lex_bot_alias.prod.arn
}

resource "aws_dynamodb_table" "conversation_context" {
  name         = "${var.project_name}-conversation-context"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ContactId"

  attribute {
    name = "ContactId"
    type = "S"
  }

  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.log_key.arn
  }

  tags = {
    Purpose = "Context Preservation for Fallback"
  }
}

# -------------------------------------------------------------------------
# Connect Agent Queues & Routing
# -------------------------------------------------------------------------

# Get Default Hours of Operation
data "aws_connect_hours_of_operation" "default" {
  instance_id = aws_connect_instance.this.id
  name        = "Basic Hours"
}

# Create Queues
resource "aws_connect_queue" "sales" {
  instance_id           = aws_connect_instance.this.id
  name                  = "Sales"
  description           = "Sales Department Queue"
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  tags = {
    Department = "Sales"
  }
}

resource "aws_connect_queue" "support" {
  instance_id           = aws_connect_instance.this.id
  name                  = "Support"
  description           = "Customer Support Queue"
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  tags = {
    Department = "Support"
  }
}

resource "aws_connect_queue" "billing" {
  instance_id           = aws_connect_instance.this.id
  name                  = "Billing"
  description           = "Billing & Payments Queue"
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  tags = {
    Department = "Billing"
  }
}

# -------------------------------------------------------------------------
# Connect Contact Flow (Nova Sonic IVR)
# -------------------------------------------------------------------------

resource "aws_connect_contact_flow" "nova_sonic_ivr" {
  instance_id  = aws_connect_instance.this.id
  name         = "Nova Sonic Intelligent IVR"
  description  = "Main entry point using Nova Sonic with Lex Fallback"
  type         = "CONTACT_FLOW"
  content      = templatefile("${path.module}/contact_flows/nova_sonic_ivr.json.tftpl", {
    voice_lambda_arn   = aws_lambda_function.voice_orchestrator.arn
    sales_queue_arn    = aws_connect_queue.sales.arn
    support_queue_arn  = aws_connect_queue.support.arn
    billing_queue_arn  = aws_connect_queue.billing.arn
    lex_bot_name       = aws_lexv2models_bot.chat_bot.name
    lex_bot_alias_arn  = awscc_lex_bot_alias.prod.arn
  })
}

# -------------------------------------------------------------------------
# Lambda Permissions (Connect -> Voice Lambda)
# -------------------------------------------------------------------------

resource "aws_lambda_permission" "connect_invoke_voice" {
  statement_id  = "AllowConnectInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.voice_orchestrator.function_name
  principal     = "connect.amazonaws.com"
  source_arn    = aws_connect_instance.this.arn
}
