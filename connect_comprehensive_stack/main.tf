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

# ===== PHONE NUMBER ASSOCIATION TO PRIMARY CONTACT FLOW =====
# Both inbound phone numbers (DID and Toll-Free) are associated with
# the BedrockPrimaryFlow contact flow which routes calls to the Lex bot
# for AI-powered conversation with Bedrock and intelligent agent transfer.
# ==============================================================
# Associate Phone Numbers with Contact Flow (Inbound)
resource "null_resource" "associate_phone_numbers" {
  triggers = {
    instance_id     = module.connect_instance.id
    contact_flow_id = aws_connect_contact_flow.bedrock_primary.contact_flow_id
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
  
  depends_on = [aws_connect_contact_flow.bedrock_primary]
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

# Contact Lens Real-Time Call Transcripts
# Contact Trace Records storage not supported for this instance type
# resource "aws_connect_instance_storage_config" "contact_trace_records" {
#   instance_id   = module.connect_instance.id
#   resource_type = "CONTACT_TRACE_RECORDS"
#
#   storage_config {
#     s3_config {
#       bucket_name   = module.connect_storage_bucket.id
#       bucket_prefix = "contact-trace-records"
#       encryption_config {
#         encryption_type = "KMS"
#         key_id          = module.kms_key.arn
#       }
#     }
#     storage_type = "S3"
#   }
# }

# ---------------------------------------------------------------------------------------------------------------------
# Default Agent User
# ---------------------------------------------------------------------------------------------------------------------
data "aws_connect_security_profile" "agent" {
  instance_id = module.connect_instance.id
  name        = "Agent"
}

data "aws_connect_security_profile" "admin" {
  instance_id = module.connect_instance.id
  name        = "Admin"
}

# ---------------------------------------------------------------------------------------------------------------------
# Routing Profiles
# ---------------------------------------------------------------------------------------------------------------------
# Main Routing Profile - Advanced profile with multiple specialized queues
# - Handles voice (1 concurrent), chat (2 concurrent), and tasks (10 concurrent)
# - Routes to GeneralAgentQueue only
# - Enables outbound calling capability
# - Best for: Senior agents handling general inquiries
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

# Basic Routing Profile - Entry-level profile with multiple queue routing
# - Handles voice (1 concurrent), chat (2 concurrent), and tasks (1 concurrent)
# - Routes to both BasicQueue and GeneralAgentQueue
# - Lower task concurrency for training/learning
# - Best for: New agents, testing, or simple routing scenarios
resource "aws_connect_routing_profile" "basic" {
  instance_id = module.connect_instance.id
  name        = "Bedrock Basic Routing Profile"
  description = "Entry-level profile for basic queue routing"
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
    concurrency = 1
  }

  # BasicQueue configuration for both VOICE and CHAT
  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = data.aws_connect_queue.basic.queue_id
  }
  
  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = data.aws_connect_queue.basic.queue_id
  }

  # GeneralAgentQueue configuration for both VOICE and CHAT
  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
  }
  
  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
  }
  
  tags = var.tags
}

# Data source to reference the existing BasicQueue (not managed by Terraform)
data "aws_connect_queue" "basic" {
  instance_id = module.connect_instance.id
  name        = "BasicQueue"
}

# ---------------------------------------------------------------------------------------------------------------------
# Agent Users
# ---------------------------------------------------------------------------------------------------------------------
# Agent 1 - Uses Basic Routing Profile (entry-level)
resource "aws_connect_user" "agent_basic" {
  instance_id        = module.connect_instance.id
  name               = "agent1"
  password           = "Password123!"
  routing_profile_id = aws_connect_routing_profile.basic.routing_profile_id
  security_profile_ids = [
    data.aws_connect_security_profile.admin.security_profile_id
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

# Agent 2 - Uses Main Routing Profile (advanced)
resource "aws_connect_user" "agent_main" {
  instance_id        = module.connect_instance.id
  name               = "agent2"
  password           = "Password123!"
  routing_profile_id = aws_connect_routing_profile.main.routing_profile_id
  security_profile_ids = [
    data.aws_connect_security_profile.admin.security_profile_id
  ]

  identity_info {
    first_name = "Agent"
    last_name  = "Two"
    email      = "agent2@example.com"
  }

  phone_config {
    phone_type  = "SOFT_PHONE"
    auto_accept = true
  }

  tags = var.tags
}

# Agent 3 - Non-admin, main routing profile
resource "aws_connect_user" "agent3" {
  instance_id        = module.connect_instance.id
  name               = "agent3"
  password           = "Password123!"
  routing_profile_id = aws_connect_routing_profile.main.routing_profile_id
  security_profile_ids = [
    data.aws_connect_security_profile.agent.security_profile_id
  ]

  identity_info {
    first_name = "Agent"
    last_name  = "Three"
    email      = "agent3@example.com"
  }

  phone_config {
    phone_type  = "SOFT_PHONE"
    auto_accept = true
  }

  tags = var.tags
}

# Agent 4 - Non-admin, main routing profile
resource "aws_connect_user" "agent4" {
  instance_id        = module.connect_instance.id
  name               = "agent4"
  password           = "Password123!"
  routing_profile_id = aws_connect_routing_profile.main.routing_profile_id
  security_profile_ids = [
    data.aws_connect_security_profile.agent.security_profile_id
  ]

  identity_info {
    first_name = "Agent"
    last_name  = "Four"
    email      = "agent4@example.com"
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
# DynamoDB for Hallucination Logs
# ---------------------------------------------------------------------------------------------------------------------
module "hallucination_logs_table" {
  source             = "../resources/dynamodb"
  name               = "${var.project_name}-hallucination-logs"
  hash_key           = "log_id"
  range_key          = "timestamp"
  ttl_enabled        = true
  ttl_attribute_name = "ttl"
  tags               = var.tags
  
  # Note: GSI not supported by module - can be added manually if needed for querying by hallucination_type
}

# ---------------------------------------------------------------------------------------------------------------------
# DynamoDB for Conversation History
# ---------------------------------------------------------------------------------------------------------------------
module "conversation_history_table" {
  source             = "../resources/dynamodb"
  name               = "${var.project_name}-conversation-history"
  hash_key           = "caller_id"           # Customer phone number
  range_key          = "timestamp"           # Conversation turn timestamp
  ttl_enabled        = true
  ttl_attribute_name = "ttl"                 # Auto-expire after 90 days
  tags               = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# DynamoDB for Callback Requests
# ---------------------------------------------------------------------------------------------------------------------
module "callback_table" {
  source             = "../resources/dynamodb"
  name               = "${var.project_name}-callbacks"
  hash_key           = "callback_id"
  range_key          = "requested_at"
  ttl_enabled        = true
  ttl_attribute_name = "ttl"
  tags               = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Callback Lambda Function
# ---------------------------------------------------------------------------------------------------------------------
data "archive_file" "callback_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/callback_handler"
  output_path = "${path.module}/lambda/callback_handler.zip"
}

# Callback dispatcher Lambda (claim/complete + optional outbound + task creation)
data "archive_file" "callback_dispatcher_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/callback_dispatcher"
  output_path = "${path.module}/lambda/callback_dispatcher.zip"
}

resource "aws_iam_role" "callback_lambda_role" {
  name = "${var.project_name}-callback-lambda-role"

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

resource "aws_iam_role_policy" "callback_lambda_policy" {
  name = "${var.project_name}-callback-lambda-policy"
  role = aws_iam_role.callback_lambda_role.id

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
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = module.callback_table.arn
      }
    ]
  })
}

module "callback_lambda" {
  source        = "../resources/lambda"
  filename      = data.archive_file.callback_zip.output_path
  function_name = "${var.project_name}-callback-handler"
  role_arn      = aws_iam_role.callback_lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 10

  environment_variables = {
    CALLBACK_TABLE_NAME = module.callback_table.name
    LOG_LEVEL           = "INFO"
  }

  tags = var.tags
}

# IAM for callback dispatcher
resource "aws_iam_role" "callback_dispatcher_role" {
  name = "${var.project_name}-callback-dispatcher-role"

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

resource "aws_iam_role_policy" "callback_dispatcher_policy" {
  name = "${var.project_name}-callback-dispatcher-policy"
  role = aws_iam_role.callback_dispatcher_role.id

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
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = module.callback_table.arn
      },
      {
        Action = [
          "connect:StartOutboundVoiceContact",
          "connect:StartTaskContact"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

module "callback_dispatcher" {
  source        = "../resources/lambda"
  filename      = data.archive_file.callback_dispatcher_zip.output_path
  function_name = "${var.project_name}-callback-dispatcher"
  role_arn      = aws_iam_role.callback_dispatcher_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 20

  environment_variables = {
    CALLBACK_TABLE_NAME         = module.callback_table.name
    INSTANCE_ID                 = module.connect_instance.id
    OUTBOUND_QUEUE_ID           = aws_connect_queue.queues["GeneralAgentQueue"].queue_id
    OUTBOUND_CONTACT_FLOW_ID    = aws_connect_contact_flow.bedrock_primary.contact_flow_id
    OUTBOUND_SOURCE_PHONE       = aws_connect_phone_number.outbound.phone_number
    TASK_CONTACT_FLOW_ID        = aws_connect_contact_flow.callback_task.contact_flow_id
    LOG_LEVEL                   = "INFO"
  }

  tags = var.tags
}

# Permission for Connect to invoke callback Lambda
resource "aws_lambda_permission" "connect_invoke_callback" {
  statement_id  = "AllowConnectInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.callback_lambda.function_name
  principal     = "connect.amazonaws.com"
  source_arn    = module.connect_instance.arn
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
# Lambda for Bedrock MCP Integration (Primary Intent Classification and Tool Calling)
# ---------------------------------------------------------------------------------------------------------------------
# Trigger to detect Lambda source code changes
data "local_file" "bedrock_lambda_source" {
  filename = "${path.module}/${var.bedrock_mcp_lambda.source_dir}/lambda_function.py"
}

# Trigger to detect dependency changes
data "local_file" "bedrock_lambda_requirements" {
  filename = "${path.module}/${var.bedrock_mcp_lambda.source_dir}/requirements.txt"
}

# Build the Lambda deployment package with dependencies (FastMCP 2.0)
resource "null_resource" "bedrock_mcp_build" {
  triggers = {
    src_hash = data.local_file.bedrock_lambda_source.content_md5
    req_hash = data.local_file.bedrock_lambda_requirements.content_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      BUILD_DIR="${path.module}/.lambda_build/bedrock_mcp"
      ZIP_PATH="$(pwd)/lambda/bedrock_mcp.zip"
      SRC_DIR="${path.module}/${var.bedrock_mcp_lambda.source_dir}"

      echo "📦 Preparing Lambda build directory: $BUILD_DIR"
      rm -rf "$BUILD_DIR" "$ZIP_PATH"
      mkdir -p "$BUILD_DIR"

      echo "📄 Copying source files..."
      rsync -a --exclude __pycache__/ "$SRC_DIR/" "$BUILD_DIR/"

      if [ -f "$SRC_DIR/requirements.txt" ]; then
        echo "📥 Installing Python dependencies into build dir..."
        python3 -m pip install --upgrade pip >/dev/null 2>&1 || true
        python3 -m pip install -r "$SRC_DIR/requirements.txt" -t "$BUILD_DIR" --no-cache-dir
      fi

      echo "🧩 Creating deployment zip: $ZIP_PATH"
      mkdir -p "$(dirname "$ZIP_PATH")"
      pushd "$BUILD_DIR" >/dev/null
      zip -r9 "$ZIP_PATH" .
      popd >/dev/null

      echo "✅ Build complete: $ZIP_PATH"
    EOT
  }
}

# Archive the built directory to produce the final artifact (kept for dependency wiring)
data "archive_file" "bedrock_mcp_zip" {
  type        = "zip"
  source_dir  = "${path.module}/.lambda_build/bedrock_mcp"
  output_path = "${path.module}/lambda/bedrock_mcp.zip"

  depends_on = [
    null_resource.bedrock_mcp_build,
    data.local_file.bedrock_lambda_source,
    data.local_file.bedrock_lambda_requirements
  ]
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
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-*",
          "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0",
          "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*"
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Effect = "Allow"
        Resource = [
          module.intent_table.arn,
          module.auth_state_table.arn,
          module.hallucination_logs_table.arn
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem"
        ]
        Effect = "Allow"
        Resource = [
          module.conversation_history_table.arn
        ]
      },
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
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

resource "aws_cloudwatch_log_group" "bedrock_mcp" {
  name              = "/aws/lambda/${var.project_name}-bedrock-mcp"
  retention_in_days = 30
  tags              = var.tags
}

module "bedrock_mcp_lambda" {
  source        = "../resources/lambda"
  filename      = data.archive_file.bedrock_mcp_zip.output_path
  function_name = "${var.project_name}-bedrock-mcp"
  role_arn      = aws_iam_role.lambda_role.arn
  handler       = var.bedrock_mcp_lambda.handler
  runtime       = var.bedrock_mcp_lambda.runtime
  timeout       = var.bedrock_mcp_lambda.timeout
  memory_size   = 1024
  architectures = ["arm64"]
  publish       = true

  # Use archive hash to trigger Lambda code updates deterministically
  source_code_hash = data.archive_file.bedrock_mcp_zip.output_base64sha256

  environment_variables = {
    # Bedrock Configuration - Use inference profile ARN for cross-region on-demand access
    BEDROCK_MODEL_ID                = "arn:aws:bedrock:us-east-1:395402194296:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0"
    BEDROCK_REGION                  = var.bedrock_region
    
    # Logging
    LOG_LEVEL                       = "INFO"
    
    # Hallucination Detection
    ENABLE_HALLUCINATION_DETECTION  = "true"
    HALLUCINATION_TABLE_NAME        = module.hallucination_logs_table.name
    
    # Conversation History
    CONVERSATION_HISTORY_TABLE_NAME = module.conversation_history_table.name
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.bedrock_mcp,
    data.archive_file.bedrock_mcp_zip,
    null_resource.bedrock_mcp_build
  ]
}

# Publish a new Lambda version whenever code changes
resource "null_resource" "bedrock_mcp_publish" {
  triggers = {
    source_code_hash = data.archive_file.bedrock_mcp_zip.output_base64sha256
    function_name    = module.bedrock_mcp_lambda.function_name
    region           = var.region
  }

  provisioner "local-exec" {
    command = "aws lambda publish-version --function-name ${self.triggers.function_name} --region ${self.triggers.region} --query 'Version' --output text > ${path.module}/.lambda_version"
  }

  depends_on = [module.bedrock_mcp_lambda]
}

# Read the published version
data "local_file" "lambda_version" {
  filename = "${path.module}/.lambda_version"
  
  depends_on = [null_resource.bedrock_mcp_publish]
}

# Alias and Provisioned Concurrency for Bedrock MCP Lambda
resource "aws_lambda_alias" "bedrock_mcp_live" {
  name             = "live"
  description      = "Live alias for provisioned concurrency"
  function_name    = module.bedrock_mcp_lambda.function_name
  function_version = trimspace(data.local_file.lambda_version.content)
  
  lifecycle {
    ignore_changes = [function_version]
  }

  depends_on = [null_resource.bedrock_mcp_publish]
}

# Update alias whenever version changes
resource "null_resource" "bedrock_mcp_update_alias" {
  triggers = {
    version       = trimspace(data.local_file.lambda_version.content)
    function_name = module.bedrock_mcp_lambda.function_name
    alias_name    = aws_lambda_alias.bedrock_mcp_live.name
    region        = var.region
  }

  provisioner "local-exec" {
    command = "aws lambda update-alias --function-name ${self.triggers.function_name} --name ${self.triggers.alias_name} --function-version ${self.triggers.version} --region ${self.triggers.region}"
  }

  depends_on = [
    aws_lambda_alias.bedrock_mcp_live,
    null_resource.bedrock_mcp_publish
  ]
}

resource "aws_lambda_provisioned_concurrency_config" "bedrock_mcp_pc" {
  function_name                     = module.bedrock_mcp_lambda.function_name
  qualifier                         = aws_lambda_alias.bedrock_mcp_live.name
  provisioned_concurrent_executions = 2

  depends_on = [
    aws_lambda_alias.bedrock_mcp_live,
    null_resource.bedrock_mcp_update_alias
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Amazon Lex Bot Configuration
# =====================================================================================================================
# This section creates a multi-locale Lex bot with intent support for both voice and chat channels.
#
# BOT STRUCTURE:
# - Bot: connect-comprehensive-bot
#   ├── Locale: en_GB (primary)
#   │   ├── Intent: ChatIntent (created by module, fulfillment enabled)
#   │   └── Intent: TransferToAgent (explicit, fulfillment disabled - Lambda returns this)
#   ├── Locale: en_US (secondary)
#   │   ├── Intent: ChatIntent (explicit, fulfillment enabled)
#   │   └── Intent: TransferToAgent (explicit, fulfillment disabled - Lambda returns this)
#   └── Bot Alias: prod (points to latest bot version)
#       └── Code Hook: Lambda fulfillment for bedrock-mcp
#
# DEPLOYMENT FLOW:
# 1. Create bot and locales (module handles en_GB + ChatIntent)
# 2. Create en_US locale explicitly
# 3. Create ChatIntent for en_US
# 4. Create TransferToAgent intents for both locales
# 5. Build bot locales (triggers AWS CLI build-bot-locale)
# 6. Create bot version (captures all intents at point in time)
# 7. Create bot alias pointing to version
# 8. Associate with Connect instance
#
# CONTACT FLOW:
# - Flow: BedrockPrimaryFlow (DEFAULT - deployed as the primary contact flow)
#   - Template: bedrock_primary_flow_fixed.json.tftpl
#   - Behavior:
#     * Routes inbound calls to Lex bot (en_GB locale)
#     * Lambda processes all utterances via Bedrock (Anthropic Claude)
#     * If Lambda returns TransferToAgent intent → route to agent queue
#     * Otherwise → continue conversation with bot
# =====================================================================================================================

# Using the module for the bot shell
module "lex_bot" {
  source                 = "../resources/lex"
  bot_name               = "${var.project_name}-bot"
  fulfillment_lambda_arn = aws_lambda_alias.bedrock_mcp_live.arn
  locale                 = var.locale
  voice_id               = var.voice_id
  tags                   = var.tags
}

# We need to define the Bot Locale, Intents, and Slots explicitly as the module is minimal
# Note: The module creates the locale "en_GB" and a FallbackIntent.
# We also create en_US locale to support Connect's default voice settings

# Create en_US locale in addition to en_GB
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id          = module.lex_bot.bot_id
  bot_version     = "DRAFT"
  locale_id       = "en_US"
  n_lu_intent_confidence_threshold = 0.40
  
  voice_settings {
    voice_id = "Joanna"
    engine   = "neural"
  }
}

# Create ChatIntent for en_US locale (required to build locale)
resource "aws_lexv2models_intent" "chat_en_us" {
  bot_id      = module.lex_bot.bot_id
  bot_version = "DRAFT"
  locale_id   = "en_US"
  name        = "ChatIntent"
  
  sample_utterance {
    utterance = "Hi"
  }
  sample_utterance {
    utterance = "Hello"
  }
  sample_utterance {
    utterance = "I need help"
  }

  fulfillment_code_hook {
    enabled = true
  }

  dialog_code_hook {
    enabled = true
  }

  depends_on = [aws_lexv2models_bot_locale.en_us]
}

# TransferToAgent intent for en_GB - used by Lambda to signal agent handover
resource "aws_lexv2models_intent" "transfer_to_agent_en_gb" {
  bot_id      = module.lex_bot.bot_id
  bot_version = "DRAFT"
  locale_id   = "en_GB"
  name        = "TransferToAgent"
  description = "Intent returned by Lambda to signal agent transfer is needed"

  fulfillment_code_hook {
    enabled = false
  }

  depends_on = [module.lex_bot]
}

# TransferToAgent intent for en_US - used by Lambda to signal agent handover
resource "aws_lexv2models_intent" "transfer_to_agent_en_us" {
  bot_id      = module.lex_bot.bot_id
  bot_version = "DRAFT"
  locale_id   = "en_US"
  name        = "TransferToAgent"
  description = "Intent returned by Lambda to signal agent transfer is needed"

  fulfillment_code_hook {
    enabled = false
  }

  depends_on = [aws_lexv2models_bot_locale.en_us]
}

# Update FallbackIntent for en_GB locale (auto-created by Lex)
# Using null_resource with AWS CLI because FallbackIntent is automatically created by Lex
# and we can't manage it directly with Terraform without import
resource "null_resource" "update_fallback_intent_en_gb" {
  triggers = {
    bot_id    = module.lex_bot.bot_id
    locale_id = var.locale
    region    = var.region
    # Force update when ChatIntent changes to ensure FallbackIntent is updated after locale build
    chat_intent_id = module.lex_bot.chat_intent_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "🔧 Updating FallbackIntent for en_GB locale..."
      
      # Wait for locale to be ready (it might still be creating)
      for i in {1..30}; do
        STATUS=$(aws lexv2-models describe-bot-locale \
          --bot-id ${self.triggers.bot_id} \
          --bot-version DRAFT \
          --locale-id ${self.triggers.locale_id} \
          --region ${self.triggers.region} \
          --query 'botLocaleStatus' \
          --output text 2>/dev/null || echo "NotReady")
        
        if [ "$STATUS" = "NotBuilt" ] || [ "$STATUS" = "ReadyExpressTesting" ] || [ "$STATUS" = "Built" ]; then
          break
        fi
        
        if [ $i -eq 30 ]; then
          echo "⚠️ Locale not ready after 30 attempts, proceeding anyway..."
          break
        fi
        
        sleep 2
      done
      
      # Get the FallbackIntent ID
      INTENT_ID=$(aws lexv2-models list-intents \
        --bot-id ${self.triggers.bot_id} \
        --bot-version DRAFT \
        --locale-id ${self.triggers.locale_id} \
        --region ${self.triggers.region} \
        --query "intentSummaries[?intentName=='FallbackIntent'].intentId" \
        --output text)
      
      if [ -z "$INTENT_ID" ]; then
        echo "⚠️ FallbackIntent not found yet for en_GB, it will be created when locale is built"
        exit 0
      fi
      
      echo "  Found FallbackIntent ID: $INTENT_ID"
      
      # Update the FallbackIntent to enable both hooks
      aws lexv2-models update-intent \
        --bot-id ${self.triggers.bot_id} \
        --bot-version DRAFT \
        --locale-id ${self.triggers.locale_id} \
        --intent-id "$INTENT_ID" \
        --intent-name "FallbackIntent" \
        --parent-intent-signature "AMAZON.FallbackIntent" \
        --fulfillment-code-hook enabled=true \
        --dialog-code-hook enabled=true \
        --region ${self.triggers.region}
      
      echo "✅ FallbackIntent for en_GB updated successfully"
    EOT
  }

  depends_on = [module.lex_bot.bot_locale_id]
}

# Update FallbackIntent for en_US locale (auto-created by Lex)
resource "null_resource" "update_fallback_intent_en_us" {
  triggers = {
    bot_id    = module.lex_bot.bot_id
    locale_id = "en_US"
    region    = var.region
    # Force update when ChatIntent changes to ensure FallbackIntent is updated after locale build
    chat_intent_id = aws_lexv2models_intent.chat_en_us.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "🔧 Updating FallbackIntent for en_US locale..."
      
      # Wait for locale to be ready
      for i in {1..30}; do
        STATUS=$(aws lexv2-models describe-bot-locale \
          --bot-id ${self.triggers.bot_id} \
          --bot-version DRAFT \
          --locale-id ${self.triggers.locale_id} \
          --region ${self.triggers.region} \
          --query 'botLocaleStatus' \
          --output text 2>/dev/null || echo "NotReady")
        
        if [ "$STATUS" = "NotBuilt" ] || [ "$STATUS" = "ReadyExpressTesting" ] || [ "$STATUS" = "Built" ]; then
          break
        fi
        
        if [ $i -eq 30 ]; then
          echo "⚠️ Locale not ready after 30 attempts, proceeding anyway..."
          break
        fi
        
        sleep 2
      done
      
      # Get the FallbackIntent ID
      INTENT_ID=$(aws lexv2-models list-intents \
        --bot-id ${self.triggers.bot_id} \
        --bot-version DRAFT \
        --locale-id ${self.triggers.locale_id} \
        --region ${self.triggers.region} \
        --query "intentSummaries[?intentName=='FallbackIntent'].intentId" \
        --output text)
      
      if [ -z "$INTENT_ID" ]; then
        echo "⚠️ FallbackIntent not found yet for en_US, it will be created when locale is built"
        exit 0
      fi
      
      echo "  Found FallbackIntent ID: $INTENT_ID"
      
      # Update the FallbackIntent to enable both hooks
      aws lexv2-models update-intent \
        --bot-id ${self.triggers.bot_id} \
        --bot-version DRAFT \
        --locale-id ${self.triggers.locale_id} \
        --intent-id "$INTENT_ID" \
        --intent-name "FallbackIntent" \
        --parent-intent-signature "AMAZON.FallbackIntent" \
        --fulfillment-code-hook enabled=true \
        --dialog-code-hook enabled=true \
        --region ${self.triggers.region}
      
      echo "✅ FallbackIntent for en_US updated successfully"
    EOT
  }

  depends_on = [aws_lexv2models_bot_locale.en_us]
}

# Intents are no longer needed - using FallbackIntent only (created by module)
# The Lex bot now uses a single FallbackIntent that passes all input to Bedrock via Lambda
# resource "aws_lexv2models_intent" "intents" {
#   for_each = var.lex_intents
#   ...
# }
# resource "aws_lexv2models_intent" "intents_en_us" {
#   for_each = var.lex_intents
#   ...
# }

# Permission for Lex to invoke Lambda
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.bedrock_mcp_live.arn
  principal     = "lexv2.amazonaws.com"
  source_arn    = "arn:aws:lex:${data.aws_caller_identity.current.id == data.aws_caller_identity.current.id ? "eu-west-2" : ""}:${data.aws_caller_identity.current.account_id}:bot-alias/${module.lex_bot.bot_id}/*"
}

# Build both bot locales before creating version
resource "null_resource" "build_bot_locales" {
  triggers = {
    bot_id = module.lex_bot.bot_id
    transfer_intent_gb = aws_lexv2models_intent.transfer_to_agent_en_gb.id
    transfer_intent_us = aws_lexv2models_intent.transfer_to_agent_en_us.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "🔨 Building bot locale: ${var.locale}..."
      aws lexv2-models build-bot-locale \
        --bot-id ${module.lex_bot.bot_id} \
        --bot-version DRAFT \
        --locale-id ${var.locale} \
        --region ${var.region}
      
      echo "🔨 Building bot locale: en_US..."
      aws lexv2-models build-bot-locale \
        --bot-id ${module.lex_bot.bot_id} \
        --bot-version DRAFT \
        --locale-id en_US \
        --region ${var.region}
      
      echo "⏳ Waiting for locales to build..."
      sleep 15
      
      # Wait and validate en_GB locale is built
      for i in {1..20}; do
        STATUS=$(aws lexv2-models describe-bot-locale \
          --bot-id ${module.lex_bot.bot_id} \
          --bot-version DRAFT \
          --locale-id ${var.locale} \
          --region ${var.region} \
          --query 'botLocaleStatus' \
          --output text)
        
        echo "  ${var.locale} status: $STATUS (attempt $i/20)"
        
        if [ "$STATUS" = "Built" ]; then
          echo "✅ ${var.locale} locale built successfully"
          break
        elif [ "$STATUS" = "Failed" ]; then
          echo "❌ ${var.locale} locale build failed"
          exit 1
        fi
        
        if [ $i -eq 20 ]; then
          echo "⚠️  Timeout waiting for ${var.locale} locale to build"
          exit 1
        fi
        
        sleep 5
      done
      
      # Wait and validate en_US locale is built
      for i in {1..20}; do
        STATUS=$(aws lexv2-models describe-bot-locale \
          --bot-id ${module.lex_bot.bot_id} \
          --bot-version DRAFT \
          --locale-id en_US \
          --region ${var.region} \
          --query 'botLocaleStatus' \
          --output text)
        
        echo "  en_US status: $STATUS (attempt $i/20)"
        
        if [ "$STATUS" = "Built" ]; then
          echo "✅ en_US locale built successfully"
          break
        elif [ "$STATUS" = "Failed" ]; then
          echo "❌ en_US locale build failed"
          exit 1
        fi
        
        if [ $i -eq 20 ]; then
          echo "⚠️  Timeout waiting for en_US locale to build"
          exit 1
        fi
        
        sleep 5
      done
      
      echo "✅ All bot locales built successfully"
    EOT
  }

  depends_on = [
    module.lex_bot,
    aws_lexv2models_bot_locale.en_us,
    aws_lexv2models_intent.chat_en_us,
    aws_lexv2models_intent.transfer_to_agent_en_gb,
    aws_lexv2models_intent.transfer_to_agent_en_us,
    null_resource.update_fallback_intent_en_gb,
    null_resource.update_fallback_intent_en_us
  ]
}

# Create Bot Version AFTER all intents are defined and locales are built
# This version includes all intents: ChatIntent and TransferToAgent for both locales
resource "aws_lexv2models_bot_version" "this" {
  bot_id      = module.lex_bot.bot_id
  description = "Version with ChatIntent and TransferToAgent intents for both locales - ${timestamp()}"
  locale_specification = {
    (var.locale) = {
      source_bot_version = "DRAFT"
    }
    "en_US" = {
      source_bot_version = "DRAFT"
    }
  }
  depends_on = [
    null_resource.build_bot_locales,
    aws_lexv2models_intent.chat_en_us,
    aws_lexv2models_intent.transfer_to_agent_en_gb,
    aws_lexv2models_intent.transfer_to_agent_en_us
  ]
  
  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for Lex Conversation Logs
resource "aws_cloudwatch_log_group" "lex_logs" {
  name              = "/aws/lex/${var.project_name}-bot"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_resource_policy" "lex_logs" {
  policy_name = "${var.project_name}-lex-logs-policy"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lex.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lex_logs.arn}:*"
      }
    ]
  })
}

# Create Bot Alias pointing to the version
resource "awscc_lex_bot_alias" "this" {
  bot_id      = module.lex_bot.bot_id
  bot_alias_name = "prod"
  bot_version = aws_lexv2models_bot_version.this.bot_version
  
  conversation_log_settings = {
    text_log_settings = [
      {
        destination = {
          cloudwatch = {
            cloudwatch_log_group_arn = aws_cloudwatch_log_group.lex_logs.arn
            log_prefix               = "lex-logs"
          }
        }
        enabled = true
      }
    ]
    audio_log_settings = [
      {
        destination = {
          s3_bucket = {
            s3_bucket_arn = module.connect_storage_bucket.arn
            log_prefix    = "lex-audio-logs"
          }
        }
        enabled = false
      }
    ]
  }

  bot_alias_locale_settings = [
    {
      locale_id = var.locale
      bot_alias_locale_setting = {
        enabled = true
        code_hook_specification = {
          lambda_code_hook = {
            lambda_arn = aws_lambda_alias.bedrock_mcp_live.arn
            code_hook_interface_version = "1.0"
          }
        }
      }
    },
    {
      locale_id = "en_US"
      bot_alias_locale_setting = {
        enabled = true
        code_hook_specification = {
          lambda_code_hook = {
            lambda_arn = aws_lambda_alias.bedrock_mcp_live.arn
            code_hook_interface_version = "1.0"
          }
        }
      }
    }
  ]
}

# Validate bot alias is properly configured with both locales
resource "null_resource" "validate_bot_alias" {
  triggers = {
    alias_arn = awscc_lex_bot_alias.this.arn
    bot_version = aws_lexv2models_bot_version.this.bot_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "🔍 Validating bot version ${aws_lexv2models_bot_version.this.bot_version}..."
      
      # Validate bot version is available
      VERSION_STATUS=$(aws lexv2-models describe-bot-version \
        --bot-id ${module.lex_bot.bot_id} \
        --bot-version ${aws_lexv2models_bot_version.this.bot_version} \
        --region ${var.region} \
        --query 'botStatus' \
        --output text)
      
      if [ "$VERSION_STATUS" != "Available" ]; then
        echo "❌ Bot version ${aws_lexv2models_bot_version.this.bot_version} status: $VERSION_STATUS (expected: Available)"
        exit 1
      fi
      
      echo "✅ Bot version ${aws_lexv2models_bot_version.this.bot_version} is Available"
      
      # Validate bot alias configuration
      echo "🔍 Validating bot alias configuration..."
      
      ALIAS_DATA=$(aws lexv2-models describe-bot-alias \
        --bot-id ${module.lex_bot.bot_id} \
        --bot-alias-id ${awscc_lex_bot_alias.this.bot_alias_id} \
        --region ${var.region})
      
      ALIAS_VERSION=$(echo "$ALIAS_DATA" | jq -r '.botVersion')
      ALIAS_STATUS=$(echo "$ALIAS_DATA" | jq -r '.botAliasStatus')
      
      if [ "$ALIAS_STATUS" != "Available" ]; then
        echo "❌ Bot alias status: $ALIAS_STATUS (expected: Available)"
        exit 1
      fi
      
      if [ "$ALIAS_VERSION" != "${aws_lexv2models_bot_version.this.bot_version}" ]; then
        echo "❌ Bot alias pointing to version $ALIAS_VERSION (expected: ${aws_lexv2models_bot_version.this.bot_version})"
        exit 1
      fi
      
      echo "✅ Bot alias is Available and pointing to version ${aws_lexv2models_bot_version.this.bot_version}"
      
      # Validate both locales are configured
      LOCALES=$(echo "$ALIAS_DATA" | jq -r '.botAliasLocaleSettings | keys[]' | sort | tr '\n' ',' | sed 's/,$//')
      
      if [[ ! "$LOCALES" =~ "en_GB" ]] || [[ ! "$LOCALES" =~ "en_US" ]]; then
        echo "❌ Bot alias missing required locales. Found: $LOCALES (expected: en_GB, en_US)"
        exit 1
      fi
      
      echo "✅ Bot alias configured with locales: $LOCALES"
      
      # Validate Lambda is configured for both locales
      for LOCALE in en_GB en_US; do
        LAMBDA_ARN=$(echo "$ALIAS_DATA" | jq -r ".botAliasLocaleSettings.\"$LOCALE\".codeHookSpecification.lambdaCodeHook.lambdaARN")
        ENABLED=$(echo "$ALIAS_DATA" | jq -r ".botAliasLocaleSettings.\"$LOCALE\".enabled")
        
        if [ "$ENABLED" != "true" ]; then
          echo "❌ Locale $LOCALE is not enabled"
          exit 1
        fi
        
        if [ "$LAMBDA_ARN" != "${aws_lambda_alias.bedrock_mcp_live.arn}" ]; then
          echo "❌ Locale $LOCALE Lambda ARN mismatch"
          echo "   Expected: ${aws_lambda_alias.bedrock_mcp_live.arn}"
          echo "   Found: $LAMBDA_ARN"
          exit 1
        fi
        
        echo "✅ Locale $LOCALE: enabled with Lambda integration"
      done
      
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "✅ Bot validation complete!"
      echo "   Bot ID: ${module.lex_bot.bot_id}"
      echo "   Bot Version: ${aws_lexv2models_bot_version.this.bot_version}"
      echo "   Bot Alias: ${awscc_lex_bot_alias.this.bot_alias_id}"
      echo "   Locales: en_GB, en_US (both enabled with Lambda)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    EOT
  }

  depends_on = [
    awscc_lex_bot_alias.this
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
# ---------------------------------------------------------------------------------------------------------------------
# Connect Contact Flow
# ---------------------------------------------------------------------------------------------------------------------
# This defines the IVR/Chat experience

# Main Lex Interaction Flow - Deprecated in favor of bedrock_primary_flow
# Commented out as main_flow.json.tftpl doesn't exist and is replaced by bedrock_primary_flow
# resource "aws_connect_contact_flow" "main_flow" {
#   instance_id = module.connect_instance.id
#   name        = "MainIVRFlow"
#   description = "Main flow with Lex integration and Agent Routing"
#   type        = "CONTACT_FLOW"
#   content = templatefile("${path.module}/contact_flows/bedrock_primary_flow.json.tftpl", {
#     lex_bot_alias_arn     = awscc_lex_bot_alias.this.arn
#     general_agent_queue_arn = aws_connect_queue.queues["GeneralAgentQueue"].arn
#   })
#   tags = var.tags
#   depends_on = [null_resource.lex_bot_association]
# }

# Voice IVR Flow with DTMF Menu
# Temporarily commented out - flow validation failing
# resource "aws_connect_contact_flow" "voice_ivr" {
#   instance_id = module.connect_instance.id
#   name        = "VoiceIVRFlow"
#   description = "DTMF menu for voice routing"
#   type        = "CONTACT_FLOW"
#   content = templatefile("${path.module}/contact_flows/voice_ivr_simple.json.tftpl", {
#     account_queue_arn        = aws_connect_queue.queues["AccountQueue"].arn
#     lending_queue_arn        = aws_connect_queue.queues["LendingQueue"].arn
#     general_queue_arn        = aws_connect_queue.queues["GeneralAgentQueue"].arn
#     lex_interaction_flow_id  = aws_connect_contact_flow.main_flow.id
#   })
#   tags = var.tags
# 
#   depends_on = [
#     aws_connect_queue.queues,
#     aws_connect_contact_flow.main_flow
#   ]
# }

# Voice Entry Flow with Hours Check
resource "aws_connect_contact_flow" "voice_entry" {
  instance_id = module.connect_instance.id
  name        = "VoiceEntryFlow"
  description = "Voice entry point"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/contact_flows/voice_entry_simple.json.tftpl", {
    hours_of_operation_id = data.aws_connect_hours_of_operation.default.hours_of_operation_id
    general_queue_arn     = aws_connect_queue.queues["GeneralAgentQueue"].arn
  })
  tags = var.tags

  depends_on = [
    data.aws_connect_hours_of_operation.default,
    aws_connect_queue.queues
  ]
}

# Chat Entry Flow
resource "aws_connect_contact_flow" "chat_entry" {
  instance_id = module.connect_instance.id
  name        = "ChatEntryFlow"
  description = "Chat channel entry point"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/contact_flows/chat_entry_simple.json.tftpl", {
    lex_bot_alias_arn     = awscc_lex_bot_alias.this.arn
    general_queue_arn     = aws_connect_queue.queues["GeneralAgentQueue"].arn
  })
  tags = var.tags

  depends_on = [
    null_resource.lex_bot_association,
    aws_connect_queue.queues
  ]
}

# ===== PRIMARY CONTACT FLOW - DEFAULT FOR PHONE NUMBER =====
# Bedrock Primary Flow - Main contact flow used for all inbound calls
# This is the DEFAULT FLOW associated with DID and toll-free numbers
# Template: bedrock_primary_flow_fixed.json.tftpl
#
# FLOW LOGIC:
# 1. Accept inbound call
# 2. Greet customer: "Hello! Welcome to our banking service..."
# 3. Connect to Lex bot (en_GB locale) with Lambda fulfillment
# 4. For each customer input:
#    - Lex invokes Lambda (bedrock-mcp)
#    - Lambda sends to Bedrock for AI response
#    - Lambda returns either:
#      a) Response text + ChatIntent → continue conversation
#      b) TransferToAgent intent → transfer to agent queue
# 5. Agent queue manages customer while waiting
# =============================================================
resource "aws_connect_contact_flow" "bedrock_primary" {
  instance_id = module.connect_instance.id
  name        = "BedrockPrimaryFlow"
  description = "Bedrock-primary architecture with multi-turn conversation and intelligent agent transfer - PRIMARY FLOW FOR PHONE NUMBERS"
  type        = "CONTACT_FLOW"
  content = templatefile("${path.module}/contact_flows/bedrock_primary_flow.json.tftpl", {
    lex_bot_alias_arn = awscc_lex_bot_alias.this.arn
    queue_arn         = aws_connect_queue.queues["GeneralAgentQueue"].arn
  })
  tags = var.tags

  depends_on = [
    awscc_lex_bot_alias.this,
    aws_connect_queue.queues
  ]
}

# Customer Queue Flow - Plays while customer waits with position updates and callback option
resource "aws_connect_contact_flow" "customer_queue" {
  instance_id = module.connect_instance.id
  name        = "CustomerQueueFlow"
  description = "Simple queue flow with hold messages"
  type        = "CUSTOMER_QUEUE"
  content = templatefile("${path.module}/contact_flows/customer_queue_flow_minimal.json.tftpl", {})
  tags = var.tags

  depends_on = []
}

# Task flow to surface claimed callbacks as Connect tasks
resource "aws_connect_contact_flow" "callback_task" {
  instance_id = module.connect_instance.id
  name        = "CallbackTaskFlow"
  description = "Task flow for claimed callbacks"
  type        = "CONTACT_FLOW"
  content     = templatefile("${path.module}/contact_flows/callback_task_flow.json.tftpl", {})
  tags        = var.tags
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
    command = "aws connect disassociate-bot --instance-id ${self.triggers.instance_id} --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} --region ${self.triggers.region} || true"
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


# ---------------------------------------------------------------------------------------------------------------------
# SNS Topic for CloudWatch Alarms
# ---------------------------------------------------------------------------------------------------------------------
module "alarm_sns_topic" {
  source     = "../resources/sns"
  name       = "${var.project_name}-alarms"
  kms_key_id = module.kms_key.key_id
  tags       = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudWatch Alarms for Hallucination Detection
# ---------------------------------------------------------------------------------------------------------------------
# High severity alarm: Hallucination detection rate > 10% over 5 minutes
resource "aws_cloudwatch_metric_alarm" "hallucination_rate_high" {
  alarm_name          = "${var.project_name}-hallucination-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HallucinationDetectionRate"
  namespace           = "Connect/BedrockMCP"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 10.0
  alarm_description   = "Hallucination detection rate exceeded 10% over 5 minutes"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# Medium severity alarm: Hallucination detection rate > 5% over 15 minutes
resource "aws_cloudwatch_metric_alarm" "hallucination_rate_medium" {
  alarm_name          = "${var.project_name}-hallucination-rate-medium"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HallucinationDetectionRate"
  namespace           = "Connect/BedrockMCP"
  period              = 900 # 15 minutes
  statistic           = "Average"
  threshold           = 5.0
  alarm_description   = "Hallucination detection rate exceeded 5% over 15 minutes"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudWatch Alarms for Error Rates
# ---------------------------------------------------------------------------------------------------------------------
# Lambda error rate alarm: > 5% over 5 minutes
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.project_name}-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5.0
  alarm_description   = "Lambda error rate exceeded 5% over 5 minutes"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300 # 5 minutes
      stat        = "Sum"
      dimensions = {
        FunctionName = module.bedrock_mcp_lambda.function_name
      }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300 # 5 minutes
      stat        = "Sum"
      dimensions = {
        FunctionName = module.bedrock_mcp_lambda.function_name
      }
    }
  }

  tags = var.tags
}

# Bedrock API errors alarm: > 10 errors per hour
resource "aws_cloudwatch_metric_alarm" "bedrock_api_errors" {
  alarm_name          = "${var.project_name}-bedrock-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BedrockAPIErrors"
  namespace           = "Connect/BedrockMCP"
  period              = 3600 # 1 hour
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Bedrock API errors exceeded 10 per hour"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# Validation timeout alarm: > 5 timeouts per hour
resource "aws_cloudwatch_metric_alarm" "validation_timeouts" {
  alarm_name          = "${var.project_name}-validation-timeouts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ValidationTimeouts"
  namespace           = "Connect/BedrockMCP"
  period              = 3600 # 1 hour
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Validation timeouts exceeded 5 per hour"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudWatch Alarms for Queue Management
# ---------------------------------------------------------------------------------------------------------------------
# Queue size alarm: > 10 contacts in queue over 5 minutes
resource "aws_cloudwatch_metric_alarm" "queue_size" {
  alarm_name          = "${var.project_name}-queue-size-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "QueueSize"
  namespace           = "AWS/Connect"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Queue size exceeded 10 contacts over 5 minutes"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = module.connect_instance.id
    MetricGroup = "Queue"
    QueueName   = "GeneralAgentQueue"
  }

  tags = var.tags
}

# Average wait time alarm: > 5 minutes
resource "aws_cloudwatch_metric_alarm" "queue_wait_time" {
  alarm_name          = "${var.project_name}-queue-wait-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "LongestQueueWaitTime"
  namespace           = "AWS/Connect"
  period              = 300 # 5 minutes
  statistic           = "Maximum"
  threshold           = 300 # 5 minutes in seconds
  alarm_description   = "Queue wait time exceeded 5 minutes"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = module.connect_instance.id
    MetricGroup = "Queue"
    QueueName   = "GeneralAgentQueue"
  }

  tags = var.tags
}

# Queue abandonment rate alarm: > 20%
resource "aws_cloudwatch_metric_alarm" "queue_abandonment_rate" {
  alarm_name          = "${var.project_name}-queue-abandonment-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 20.0
  alarm_description   = "Queue abandonment rate exceeded 20%"
  alarm_actions       = [module.alarm_sns_topic.topic_arn]
  ok_actions          = [module.alarm_sns_topic.topic_arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "abandonment_rate"
    expression  = "(abandoned / (abandoned + handled)) * 100"
    label       = "Abandonment Rate"
    return_data = true
  }

  metric_query {
    id = "abandoned"
    metric {
      metric_name = "ContactsAbandoned"
      namespace   = "AWS/Connect"
      period      = 300 # 5 minutes
      stat        = "Sum"
      dimensions = {
        InstanceId  = module.connect_instance.id
        MetricGroup = "Queue"
        QueueName   = "GeneralAgentQueue"
      }
    }
  }

  metric_query {
    id = "handled"
    metric {
      metric_name = "ContactsHandled"
      namespace   = "AWS/Connect"
      period      = 300 # 5 minutes
      stat        = "Sum"
      dimensions = {
        InstanceId  = module.connect_instance.id
        MetricGroup = "Queue"
        QueueName   = "GeneralAgentQueue"
      }
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CloudWatch Dashboard for Monitoring
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      # Hallucination Metrics Section
      {
        type = "metric"
        properties = {
          metrics = [
            ["Connect/BedrockMCP", "HallucinationDetectionRate", { stat = "Average", label = "Detection Rate (%)" }],
            [".", "ValidationSuccessRate", { stat = "Average", label = "Validation Success Rate (%)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Hallucination Detection Metrics"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["Connect/BedrockMCP", "ValidationLatency", { stat = "Average", label = "Avg Latency (ms)" }],
            ["...", { stat = "Maximum", label = "Max Latency (ms)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Validation Latency"
          period  = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },
      # Conversation Metrics Section
      {
        type = "metric"
        properties = {
          metrics = [
            ["Connect/BedrockMCP", "ConversationDuration", { stat = "Average", label = "Avg Duration (s)" }],
            [".", "ConversationTurns", { stat = "Average", label = "Avg Turns" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Conversation Metrics"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 0
        y      = 6
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["Connect/BedrockMCP", "ToolInvocations", { stat = "Sum", label = "Tool Calls" }],
            [".", "HandoverRate", { stat = "Average", label = "Handover Rate (%)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Tool Usage & Handover Rate"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 12
        y      = 6
      },
      # Queue Metrics Section
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Connect", "QueueSize", "InstanceId", module.connect_instance.id, "MetricGroup", "Queue", "QueueName", "GeneralAgentQueue", { stat = "Average", label = "Queue Size" }],
            [".", "LongestQueueWaitTime", ".", ".", ".", ".", ".", ".", { stat = "Maximum", label = "Max Wait Time (s)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Queue Metrics"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 0
        y      = 12
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Connect", "ContactsHandled", "InstanceId", module.connect_instance.id, "MetricGroup", "Queue", "QueueName", "GeneralAgentQueue", { stat = "Sum", label = "Handled" }],
            [".", "ContactsAbandoned", ".", ".", ".", ".", ".", ".", { stat = "Sum", label = "Abandoned" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Queue Contact Handling"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 12
        y      = 12
      },
      # Error Metrics Section
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", module.bedrock_mcp_lambda.function_name, { stat = "Sum", label = "Lambda Errors" }],
            ["Connect/BedrockMCP", "BedrockAPIErrors", { stat = "Sum", label = "Bedrock API Errors" }],
            [".", "ValidationTimeouts", { stat = "Sum", label = "Validation Timeouts" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Error Rates"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 0
        y      = 18
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", module.bedrock_mcp_lambda.function_name, { stat = "Average", label = "Avg Duration (ms)" }],
            ["AWS/Lambda", "Invocations", "FunctionName", module.bedrock_mcp_lambda.function_name, { stat = "Sum", label = "Invocations" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Lambda Performance"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 12
        y      = 18
      }
    ]
  })
}
