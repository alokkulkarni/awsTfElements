data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# KMS Key for Encryption (Zero Trust)
# ---------------------------------------------------------------------------------------------------------------------
module "kms_key" {
  source      = "../resources/kms"
  description = "KMS key for Connect Comprehensive Stack"
  tags        = var.tags
  policy = jsonencode({
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

# Claim a Phone Number for Outbound Calls (DID)
resource "aws_connect_phone_number" "outbound" {
  target_arn   = module.connect_instance.arn
  country_code = "GB"
  type         = "DID"
  tags         = var.tags
}

# Claim a Toll-Free Phone Number
resource "aws_connect_phone_number" "toll_free" {
  target_arn   = module.connect_instance.arn
  country_code = "GB"
  type         = "TOLL_FREE"
  tags         = var.tags
}

# Associate Phone Numbers with Contact Flow (Inbound)
resource "null_resource" "associate_phone_numbers" {
  triggers = {
    instance_id     = module.connect_instance.id
    contact_flow_id = aws_connect_contact_flow.main_flow.contact_flow_id
    outbound_id     = aws_connect_phone_number.outbound.id
    toll_free_id    = aws_connect_phone_number.toll_free.id
    region          = var.region
  }

  provisioner "local-exec" {
    command = "aws connect associate-phone-number-contact-flow --instance-id ${self.triggers.instance_id} --phone-number-id ${self.triggers.outbound_id} --contact-flow-id ${self.triggers.contact_flow_id} --region ${self.triggers.region}"
  }

  provisioner "local-exec" {
    command = "aws connect associate-phone-number-contact-flow --instance-id ${self.triggers.instance_id} --phone-number-id ${self.triggers.toll_free_id} --contact-flow-id ${self.triggers.contact_flow_id} --region ${self.triggers.region}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws connect disassociate-phone-number-contact-flow --instance-id ${self.triggers.instance_id} --phone-number-id ${self.triggers.outbound_id} --region ${self.triggers.region} || true"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws connect disassociate-phone-number-contact-flow --instance-id ${self.triggers.instance_id} --phone-number-id ${self.triggers.toll_free_id} --region ${self.triggers.region} || true"
  }
  
  depends_on = [aws_connect_contact_flow.main_flow]
}

# Connect Storage Configuration
resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = module.connect_instance.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    s3_config {
      bucket_name   = module.connect_storage_bucket.id
      bucket_prefix = "chat-transcripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.arn
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
      bucket_name   = module.connect_storage_bucket.id
      bucket_prefix = "call-recordings"
      encryption_config {
        encryption_type = "KMS"
        key_id          = module.kms_key.arn
      }
    }
    storage_type = "S3"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Default Agent User
# ---------------------------------------------------------------------------------------------------------------------
data "aws_connect_security_profile" "agent" {
  instance_id = module.connect_instance.id
  name        = "Agent"
}

resource "aws_connect_routing_profile" "main" {
  instance_id = module.connect_instance.id
  name        = "Main Routing Profile"
  description = "Profile with outbound calling enabled"
  default_outbound_queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }
  
  media_concurrencies {
    channel     = "CHAT"
    concurrency = 2
  }
  
  media_concurrencies {
    channel     = "TASK"
    concurrency = 10
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
  }
  
  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
  }
  
  tags = var.tags
}

resource "aws_connect_user" "agent" {
  instance_id        = module.connect_instance.id
  name               = "agent1"
  password           = "Password123!"
  routing_profile_id = aws_connect_routing_profile.main.routing_profile_id
  security_profile_ids = [
    data.aws_connect_security_profile.agent.security_profile_id
  ]

  identity_info {
    first_name = "Agent"
    last_name  = "One"
    email      = "agent1@example.com"
  }

  phone_config {
    phone_type  = "SOFT_PHONE"
    auto_accept = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# DynamoDB for New Intent Logging
# ---------------------------------------------------------------------------------------------------------------------
module "intent_table" {
  source    = "../resources/dynamodb"
  name      = "${var.project_name}-new-intents"
  hash_key  = "utterance"
  range_key = "timestamp"
  tags      = var.tags
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
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Effect = "Allow"
        Resource = [
          module.intent_table.arn,
          module.auth_state_table.arn
        ]
      },
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = module.auth_sns_topic.topic_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lex_fallback" {
  name              = "/aws/lambda/${var.project_name}-lex-fallback"
  retention_in_days = 30
  tags              = var.tags
}

module "lex_fallback_lambda" {
  source        = "../resources/lambda"
  filename      = data.archive_file.lex_fallback_zip.output_path
  function_name = "${var.project_name}-lex-fallback"
  role_arn      = aws_iam_role.lambda_role.arn
  handler       = var.lex_fallback_lambda.handler
  runtime       = var.lex_fallback_lambda.runtime

  environment_variables = {
    INTENT_TABLE_NAME     = module.intent_table.name
    AUTH_STATE_TABLE_NAME = module.auth_state_table.name
    SNS_TOPIC_ARN         = module.auth_sns_topic.topic_arn
    CRM_API_ENDPOINT      = "${module.auth_api_gateway.api_endpoint}/customer"
    CRM_API_KEY           = "secret-api-key-123"
    ENABLE_VOICE_ID       = tostring(var.enable_voice_id)
    ENABLE_PIN_VALIDATION = tostring(var.enable_pin_validation)
    ENABLE_COMPANION_AUTH = tostring(var.enable_companion_auth)
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
  fulfillment_lambda_arn = module.lex_fallback_lambda.arn
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
  function_name = module.lex_fallback_lambda.function_name
  principal     = "lex.amazonaws.com"
  source_arn    = module.lex_bot.bot_arn
}

# Create Bot Version AFTER all intents are defined
resource "aws_lexv2models_bot_version" "this" {
  bot_id = module.lex_bot.bot_id
  locale_specification = {
    (var.locale) = {
      source_bot_version = "DRAFT"
    }
  }
  depends_on = [
    aws_lexv2models_intent.intents
  ]
}

# Create Bot Alias pointing to the version
resource "awscc_lex_bot_alias" "this" {
  bot_id      = module.lex_bot.bot_id
  bot_alias_name = "prod"
  bot_version = aws_lexv2models_bot_version.this.bot_version
  
  bot_alias_locale_settings = [
    {
      locale_id = var.locale
      bot_alias_locale_setting = {
        enabled = true
        code_hook_specification = {
          lambda_code_hook = {
            lambda_arn = module.lex_fallback_lambda.arn
            code_hook_interface_version = "1.0"
          }
        }
      }
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Connect Queue & Routing Profile
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_connect_queue" "queues" {
  for_each = var.queues

  instance_id           = module.connect_instance.id
  name                  = each.key
  description           = each.value.description
  hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
  tags                  = var.tags

  outbound_caller_config {
    outbound_caller_id_name      = "Connect Support"
    outbound_caller_id_number_id = aws_connect_phone_number.outbound.id
  }
}

# Note: The connect module might not output hours_of_operation_id. 
# If not, we need a data source to find the default one.

# ---------------------------------------------------------------------------------------------------------------------
# Auth State Table (DynamoDB)
# ---------------------------------------------------------------------------------------------------------------------
module "auth_state_table" {
  source             = "../resources/dynamodb"
  name               = "${var.project_name}-auth-state"
  hash_key           = "request_id"
  tags               = var.tags
  ttl_enabled        = true
  ttl_attribute_name = "ttl"
}

# ---------------------------------------------------------------------------------------------------------------------
# SNS Topic for Push Notifications
# ---------------------------------------------------------------------------------------------------------------------
module "auth_sns_topic" {
  source     = "../resources/sns"
  name       = "${var.project_name}-auth-push"
  kms_key_id = module.kms_key.key_id
  tags       = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Auth API Lambda (Backend for Mobile App)
# ---------------------------------------------------------------------------------------------------------------------
data "archive_file" "auth_api_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/auth_api"
  output_path = "${path.module}/lambda/auth_api.zip"
}

resource "aws_iam_role" "auth_api_role" {
  name = "${var.project_name}-auth-api-role"

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

resource "aws_iam_role_policy" "auth_api_policy" {
  name = "${var.project_name}-auth-api-policy"
  role = aws_iam_role.auth_api_role.id

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
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Effect   = "Allow"
        Resource = module.auth_state_table.arn
      }
    ]
  })
}

module "auth_api_lambda" {
  source        = "../resources/lambda"
  filename      = data.archive_file.auth_api_zip.output_path
  function_name = "${var.project_name}-auth-api"
  role_arn      = aws_iam_role.auth_api_role.arn
  handler       = "auth_handler.lambda_handler"
  runtime       = "python3.11"

  environment_variables = {
    AUTH_STATE_TABLE_NAME = module.auth_state_table.name
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CRM Mock API (Internal Microservice)
# ---------------------------------------------------------------------------------------------------------------------
data "archive_file" "crm_api_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/crm_api"
  output_path = "${path.module}/lambda/crm_api.zip"
}

resource "aws_iam_role" "crm_api_role" {
  name = "${var.project_name}-crm-api-role"

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

resource "aws_iam_role_policy" "crm_api_policy" {
  name = "${var.project_name}-crm-api-policy"
  role = aws_iam_role.crm_api_role.id

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
      }
    ]
  })
}

module "crm_api_lambda" {
  source        = "../resources/lambda"
  filename      = data.archive_file.crm_api_zip.output_path
  function_name = "${var.project_name}-crm-api"
  role_arn      = aws_iam_role.crm_api_role.arn
  handler       = "crm_handler.lambda_handler"
  runtime       = "python3.11"

  environment_variables = {
    API_KEY = "secret-api-key-123" # In prod, use Secrets Manager
  }

  tags = var.tags
}

# Add CRM Route to Auth API Gateway (Shared Gateway)
resource "aws_apigatewayv2_integration" "crm_integration" {
  api_id                 = module.auth_api_gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.crm_api_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "crm_route" {
  api_id    = module.auth_api_gateway.id
  route_key = "GET /customer"
  target    = "integrations/${aws_apigatewayv2_integration.crm_integration.id}"
}

resource "aws_lambda_permission" "apigw_invoke_crm" {
  statement_id  = "AllowAPIGatewayInvokeCRM"
  action        = "lambda:InvokeFunction"
  function_name = module.crm_api_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.auth_api_gateway.api_execution_arn}/*/*/customer"
}

# ---------------------------------------------------------------------------------------------------------------------
# Auth API Gateway (HTTP API)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "auth_api_gw" {
  name              = "/aws/apigateway/${var.project_name}-auth-api"
  retention_in_days = 7
  tags              = var.tags
}

module "auth_api_gateway" {
  source              = "../resources/apigateway"
  name                = "${var.project_name}-auth-api"
  protocol_type       = "HTTP"
  stage_name          = "$default"
  log_destination_arn = aws_cloudwatch_log_group.auth_api_gw.arn
  log_format = jsonencode({
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
  })
  tags = var.tags
}

resource "aws_apigatewayv2_integration" "auth_integration" {
  api_id                 = module.auth_api_gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.auth_api_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth_route" {
  api_id    = module.auth_api_gateway.id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.auth_integration.id}"
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.auth_api_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.auth_api_gateway.api_execution_arn}/*/*/auth"
}


data "aws_connect_hours_of_operation" "default" {
  instance_id = module.connect_instance.id
  name        = "Basic Hours" # Default name usually
}

# ---------------------------------------------------------------------------------------------------------------------
# Connect Contact Flow
# ---------------------------------------------------------------------------------------------------------------------
# This defines the IVR/Chat experience
resource "aws_connect_contact_flow" "main_flow" {
  instance_id = module.connect_instance.id
  name        = "MainIVRFlow"
  description = "Main flow with Lex integration and Agent Routing"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/${var.contact_flow_template_path}", {
    lex_bot_alias_arn    = awscc_lex_bot_alias.this.arn
    general_queue_arn    = aws_connect_queue.queues["GeneralAgentQueue"].arn
    account_queue_arn    = aws_connect_queue.queues["AccountQueue"].arn
    lending_queue_arn    = aws_connect_queue.queues["LendingQueue"].arn
    onboarding_queue_arn = aws_connect_queue.queues["OnboardingQueue"].arn
    locale               = replace(var.locale, "_", "-")
  })
  tags = var.tags

  depends_on = [null_resource.lex_bot_association]
}



# Associate Lex Bot with Connect Instance
resource "null_resource" "lex_bot_association" {
  triggers = {
    instance_id   = module.connect_instance.id
    bot_alias_arn = awscc_lex_bot_alias.this.arn
    region        = var.region
  }

  provisioner "local-exec" {
    command = "aws connect associate-bot --instance-id ${self.triggers.instance_id} --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} --region ${self.triggers.region}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws connect disassociate-bot --instance-id ${self.triggers.instance_id} --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} --region ${self.triggers.region}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudTrail for Auditing
# ---------------------------------------------------------------------------------------------------------------------
module "cloudtrail_bucket" {
  source           = "../resources/s3"
  bucket_name      = "${var.project_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  enable_lifecycle = true
  attach_policy    = true
  policy           = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
  tags             = var.tags
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
  depends_on                    = [module.cloudtrail_bucket]
  enable_log_file_validation    = true

  tags = var.tags
}

