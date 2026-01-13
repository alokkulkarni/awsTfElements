data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# DYNAMODB TABLE
# =============================================================================

resource "aws_dynamodb_table" "conversation_history" {
  name           = "${var.project_name}-conversation-history"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "session_id"
  range_key      = "timestamp"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = var.tags
}

# =============================================================================
# IAM ROLES FOR LEX, LAMBDA, AND BEDROCK
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role for Lambda Functions
# -----------------------------------------------------------------------------
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

# Lambda Basic Execution + Bedrock + CloudWatch
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
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:BatchWriteItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.conversation_history.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Roles for Lex Bots
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lex_main_role" {
  name = "${var.project_name}-main-lex-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lexv2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lex_main_policy" {
  name = "${var.project_name}-main-lex-policy"
  role = aws_iam_role.lex_main_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "polly:SynthesizeSpeech"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "${aws_lambda_function.bedrock_mcp.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role" "lex_banking_role" {
  name = "${var.project_name}-banking-lex-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lexv2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lex_banking_policy" {
  name = "${var.project_name}-banking-lex-policy"
  role = aws_iam_role.lex_banking_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "polly:SynthesizeSpeech"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "${aws_lambda_function.banking.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role" "lex_sales_role" {
  name = "${var.project_name}-sales-lex-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lexv2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lex_sales_policy" {
  name = "${var.project_name}-sales-lex-policy"
  role = aws_iam_role.lex_sales_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "polly:SynthesizeSpeech"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "${aws_lambda_function.sales.arn}:*"
      }
    ]
  })
}

# =============================================================================
# CLOUDWATCH LOG GROUPS
# =============================================================================

resource "aws_cloudwatch_log_group" "bedrock_mcp" {
  name              = "/aws/lambda/${var.project_name}-bedrock-mcp"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "banking_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-banking"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "sales_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-sales"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "banking_lex_logs" {
  name              = "/aws/lex/${var.project_name}-banking-bot"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "sales_lex_logs" {
  name              = "/aws/lex/${var.project_name}-sales-bot"
  retention_in_days = 30
  tags              = var.tags
}

# =============================================================================
# LAMBDA FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# Bedrock MCP Lambda (Main Gateway)
# -----------------------------------------------------------------------------
# Build script for Bedrock MCP Lambda
resource "null_resource" "bedrock_mcp_build" {
  triggers = {
    src_hash = sha256(join("", [for f in fileset("${path.module}/../connect_comprehensive_stack/lambda/bedrock_mcp", "*.py") : filesha256("${path.module}/../connect_comprehensive_stack/lambda/bedrock_mcp/${f}")]))
    req_hash = filesha256("${path.module}/../connect_comprehensive_stack/lambda/bedrock_mcp/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PROJECT_DIR="$(pwd)"
      BUILD_DIR="$PROJECT_DIR/.lambda_build/bedrock_mcp"
      ZIP_FILE="$PROJECT_DIR/lambda/bedrock_mcp.zip"
      SRC_DIR="$PROJECT_DIR/../connect_comprehensive_stack/lambda/bedrock_mcp"

      echo "📦 Building Bedrock MCP Lambda..."
      rm -rf "$BUILD_DIR" "$ZIP_FILE"
      mkdir -p "$BUILD_DIR"
      mkdir -p "$PROJECT_DIR/lambda"

      echo "📄 Copying source files..."
      rsync -a --exclude __pycache__/ "$SRC_DIR/" "$BUILD_DIR/"

      if [ -f "$SRC_DIR/requirements.txt" ]; then
        echo "📥 Installing dependencies..."
        python3 -m pip install -r "$SRC_DIR/requirements.txt" -t "$BUILD_DIR" --no-cache-dir
      fi

      echo "🧩 Creating deployment package..."
      cd "$BUILD_DIR"
      zip -r9 "$ZIP_FILE" .

      echo "✅ Build complete: $ZIP_FILE"
    EOT
  }
}

data "archive_file" "bedrock_mcp_zip" {
  type        = "zip"
  source_dir  = "${path.module}/.lambda_build/bedrock_mcp"
  output_path = "${path.module}/lambda/bedrock_mcp.zip"

  depends_on = [null_resource.bedrock_mcp_build]
}

resource "aws_lambda_function" "bedrock_mcp" {
  filename         = data.archive_file.bedrock_mcp_zip.output_path
  function_name    = "${var.project_name}-bedrock-mcp"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 1024
  architectures    = ["arm64"]
  publish          = true
  source_code_hash = data.archive_file.bedrock_mcp_zip.output_base64sha256

  environment {
    variables = {
      BEDROCK_MODEL_ID              = var.bedrock_model_id
      BEDROCK_REGION                = var.bedrock_region
      LOG_LEVEL                     = "INFO"
      CONVERSATION_HISTORY_TABLE_NAME = aws_dynamodb_table.conversation_history.name
    }
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.bedrock_mcp,
    data.archive_file.bedrock_mcp_zip
  ]
}

resource "aws_lambda_alias" "bedrock_mcp_live" {
  name             = "live"
  description      = "Live alias for Bedrock MCP"
  function_name    = aws_lambda_function.bedrock_mcp.function_name
  function_version = aws_lambda_function.bedrock_mcp.version
}

# Lambda permission for Lex to invoke
resource "aws_lambda_permission" "lex_invoke_bedrock_mcp" {
  statement_id  = "AllowLexInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bedrock_mcp.function_name
  principal     = "lexv2.amazonaws.com"
  qualifier     = aws_lambda_alias.bedrock_mcp_live.name
}

# -----------------------------------------------------------------------------
# Banking Lambda
# -----------------------------------------------------------------------------
data "archive_file" "banking_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../connect_comprehensive_stack/lambda/banking"
  output_path = "${path.module}/lambda/banking.zip"
}

resource "aws_lambda_function" "banking" {
  filename         = data.archive_file.banking_zip.output_path
  function_name    = "${var.project_name}-banking"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = data.archive_file.banking_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.banking_lambda_logs]
}

resource "aws_lambda_alias" "banking_live" {
  name             = "live"
  description      = "Live alias for Banking"
  function_name    = aws_lambda_function.banking.function_name
  function_version = aws_lambda_function.banking.version
}

resource "aws_lambda_permission" "lex_invoke_banking" {
  statement_id  = "AllowLexInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.banking.function_name
  principal     = "lexv2.amazonaws.com"
  qualifier     = aws_lambda_alias.banking_live.name
}

# -----------------------------------------------------------------------------
# Sales Lambda
# -----------------------------------------------------------------------------
data "archive_file" "sales_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../connect_comprehensive_stack/lambda/sales"
  output_path = "${path.module}/lambda/sales.zip"
}

resource "aws_lambda_function" "sales" {
  filename         = data.archive_file.sales_zip.output_path
  function_name    = "${var.project_name}-sales"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = data.archive_file.sales_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.sales_lambda_logs]
}

resource "aws_lambda_alias" "sales_live" {
  name             = "live"
  description      = "Live alias for Sales"
  function_name    = aws_lambda_function.sales.function_name
  function_version = aws_lambda_function.sales.version
}

resource "aws_lambda_permission" "lex_invoke_sales" {
  statement_id  = "AllowLexInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sales.function_name
  principal     = "lexv2.amazonaws.com"
  qualifier     = aws_lambda_alias.sales_live.name
}

# =============================================================================
# LEX BOTS
# =============================================================================

# -----------------------------------------------------------------------------
# Main Gateway Bot (with Bedrock)
# -----------------------------------------------------------------------------
resource "aws_lexv2models_bot" "main" {
  name     = "${var.project_name}-bot"
  role_arn = aws_iam_role.lex_main_role.arn
  
  data_privacy {
    child_directed = false
  }
  
  idle_session_ttl_in_seconds = 300
  tags                        = var.tags
}

resource "aws_lexv2models_bot_locale" "main_en_gb" {
  bot_id                           = aws_lexv2models_bot.main.id
  bot_version                      = "DRAFT"
  locale_id                        = var.locale
  n_lu_intent_confidence_threshold = 0.40

  voice_settings {
    voice_id = var.voice_id
    engine   = "neural"
  }
}

resource "aws_lexv2models_intent" "main_chat" {
  bot_id      = aws_lexv2models_bot.main.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.main_en_gb.locale_id
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
  sample_utterance {
    utterance = "I want to"
  }
  sample_utterance {
    utterance = "Can you help me"
  }
  sample_utterance {
    utterance = "I would like to"
  }
  sample_utterance {
    utterance = "Help me with"
  }
  sample_utterance {
    utterance = "I need to"
  }

  fulfillment_code_hook {
    enabled = true
  }

  dialog_code_hook {
    enabled = true
  }
}

resource "aws_lexv2models_intent" "main_transfer" {
  bot_id      = aws_lexv2models_bot.main.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.main_en_gb.locale_id
  name        = "TransferToAgent"

  fulfillment_code_hook {
    enabled = false
  }

  depends_on = [aws_lexv2models_intent.main_chat]
}

# Add routing intents that Lambda can return (no sample utterances needed)
resource "aws_lexv2models_intent" "main_routing_intents" {
  for_each = toset([
    "CheckBalance",
    "TransferMoney", 
    "GetStatement",
    "CancelDirectDebit",
    "CancelStandingOrder",
    "ProductInfo",
    "Pricing"
  ])

  bot_id      = aws_lexv2models_bot.main.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.main_en_gb.locale_id
  name        = each.key

  # Add minimal sample utterance to ensure intent is included in bot versions
  sample_utterance {
    utterance = each.key
  }

  fulfillment_code_hook {
    enabled = false
  }

  depends_on = [aws_lexv2models_intent.main_transfer]
}

resource "aws_lexv2models_bot_version" "main" {
  bot_id = aws_lexv2models_bot.main.id
  
  locale_specification = {
    (var.locale) = {
      source_bot_version = "DRAFT"
    }
  }

  depends_on = [
    aws_lexv2models_intent.main_chat,
    aws_lexv2models_intent.main_transfer,
    aws_lexv2models_intent.main_routing_intents
  ]
}

resource "awscc_lex_bot_alias" "main" {
  bot_id         = aws_lexv2models_bot.main.id
  bot_alias_name = "prod"
  bot_version    = aws_lexv2models_bot_version.main.bot_version

  bot_alias_locale_settings = [{
    locale_id = var.locale
    bot_alias_locale_setting = {
      enabled = true
      code_hook_specification = {
        lambda_code_hook = {
          lambda_arn                  = aws_lambda_alias.bedrock_mcp_live.arn
          code_hook_interface_version = "1.0"
        }
      }
    }
  }]
}

# -----------------------------------------------------------------------------
# Banking Bot
# -----------------------------------------------------------------------------
resource "aws_lexv2models_bot" "banking" {
  name     = "${var.project_name}-banking-bot"
  role_arn = aws_iam_role.lex_banking_role.arn
  
  data_privacy {
    child_directed = false
  }
  
  idle_session_ttl_in_seconds = 300
  tags                        = var.tags
}

resource "aws_lexv2models_bot_locale" "banking_en_gb" {
  bot_id                           = aws_lexv2models_bot.banking.id
  bot_version                      = "DRAFT"
  locale_id                        = var.locale
  n_lu_intent_confidence_threshold = 0.40

  voice_settings {
    voice_id = var.voice_id
    engine   = "neural"
  }
}

# Dynamic Banking Intents
resource "aws_lexv2models_intent" "banking_intents" {
  for_each = var.specialized_intents

  bot_id      = aws_lexv2models_bot.banking.id
  bot_version = "DRAFT"
  locale_id   = var.locale
  name        = each.key
  description = each.value.description

  dynamic "sample_utterance" {
    for_each = each.value.utterances
    content {
      utterance = sample_utterance.value
    }
  }

  fulfillment_code_hook {
    enabled = true
  }

  depends_on = [aws_lexv2models_bot_locale.banking_en_gb]
}

resource "aws_lexv2models_intent" "banking_transfer" {
  bot_id      = aws_lexv2models_bot.banking.id
  bot_version = "DRAFT"
  locale_id   = var.locale
  name        = "TransferMoney"

  sample_utterance {
    utterance = "Transfer money"
  }
  sample_utterance {
    utterance = "Send funds"
  }

  fulfillment_code_hook {
    enabled = true
  }

  depends_on = [aws_lexv2models_bot_locale.banking_en_gb]
}

resource "aws_lexv2models_bot_version" "banking" {
  bot_id = aws_lexv2models_bot.banking.id
  
  locale_specification = {
    (var.locale) = {
      source_bot_version = "DRAFT"
    }
  }

  depends_on = [
    aws_lexv2models_intent.banking_intents,
    aws_lexv2models_intent.banking_transfer
  ]
}

resource "awscc_lex_bot_alias" "banking" {
  bot_id         = aws_lexv2models_bot.banking.id
  bot_alias_name = "prod"
  bot_version    = aws_lexv2models_bot_version.banking.bot_version

  bot_alias_locale_settings = [{
    locale_id = var.locale
    bot_alias_locale_setting = {
      enabled = true
      code_hook_specification = {
        lambda_code_hook = {
          lambda_arn                  = aws_lambda_alias.banking_live.arn
          code_hook_interface_version = "1.0"
        }
      }
    }
  }]

  conversation_log_settings = {
    text_log_settings = [{
      enabled = true
      destination = {
        cloudwatch = {
          cloudwatch_log_group_arn = aws_cloudwatch_log_group.banking_lex_logs.arn
          log_prefix                = "lex-logs"
        }
      }
    }]
  }
}

# -----------------------------------------------------------------------------
# Sales Bot
# -----------------------------------------------------------------------------
resource "aws_lexv2models_bot" "sales" {
  name     = "${var.project_name}-sales-bot"
  role_arn = aws_iam_role.lex_sales_role.arn
  
  data_privacy {
    child_directed = false
  }
  
  idle_session_ttl_in_seconds = 300
  tags                        = var.tags
}

resource "aws_lexv2models_bot_locale" "sales_en_gb" {
  bot_id                           = aws_lexv2models_bot.sales.id
  bot_version                      = "DRAFT"
  locale_id                        = var.locale
  n_lu_intent_confidence_threshold = 0.40

  voice_settings {
    voice_id = var.voice_id
    engine   = "neural"
  }
}

resource "aws_lexv2models_intent" "sales_product" {
  bot_id      = aws_lexv2models_bot.sales.id
  bot_version = "DRAFT"
  locale_id   = var.locale
  name        = "ProductInfo"

  sample_utterance {
    utterance = "What products do you have"
  }
  sample_utterance {
    utterance = "Tell me about credit cards"
  }
  sample_utterance {
    utterance = "Product information"
  }

  fulfillment_code_hook {
    enabled = true
  }

  depends_on = [aws_lexv2models_bot_locale.sales_en_gb]
}

resource "aws_lexv2models_bot_version" "sales" {
  bot_id = aws_lexv2models_bot.sales.id
  
  locale_specification = {
    (var.locale) = {
      source_bot_version = "DRAFT"
    }
  }

  depends_on = [aws_lexv2models_intent.sales_product]
}

resource "awscc_lex_bot_alias" "sales" {
  bot_id         = aws_lexv2models_bot.sales.id
  bot_alias_name = "prod"
  bot_version    = aws_lexv2models_bot_version.sales.bot_version

  bot_alias_locale_settings = [{
    locale_id = var.locale
    bot_alias_locale_setting = {
      enabled = true
      code_hook_specification = {
        lambda_code_hook = {
          lambda_arn                  = aws_lambda_alias.sales_live.arn
          code_hook_interface_version = "1.0"
        }
      }
    }
  }]

  conversation_log_settings = {
    text_log_settings = [{
      enabled = true
      destination = {
        cloudwatch = {
          cloudwatch_log_group_arn = aws_cloudwatch_log_group.sales_lex_logs.arn
          log_prefix                = "lex-logs"
        }
      }
    }]
  }
}

# ============================================================================
# CONNECT INSTANCE BOT ASSOCIATIONS
# ============================================================================
# Associate bots with Amazon Connect instance so they appear in contact flows
# Only runs if connect_instance_id is provided

# Associate Main Bot
resource "null_resource" "main_bot_association" {
  count = var.connect_instance_id != "" ? 1 : 0
  
  triggers = {
    instance_id   = var.connect_instance_id
    bot_alias_arn = awscc_lex_bot_alias.main.arn
    region        = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws connect associate-bot \
        --instance-id ${self.triggers.instance_id} \
        --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} \
        --region ${self.triggers.region}
      
      echo "✅ Main bot ${self.triggers.bot_alias_arn} associated with Connect instance"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws connect disassociate-bot --instance-id ${self.triggers.instance_id} --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} --region ${self.triggers.region} || true"
  }

  depends_on = [awscc_lex_bot_alias.main]
}

# Associate Banking Bot
resource "null_resource" "banking_bot_association" {
  count = var.connect_instance_id != "" ? 1 : 0
  
  triggers = {
    instance_id   = var.connect_instance_id
    bot_alias_arn = awscc_lex_bot_alias.banking.arn
    region        = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws connect associate-bot \
        --instance-id ${self.triggers.instance_id} \
        --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} \
        --region ${self.triggers.region}
      
      echo "✅ Banking bot ${self.triggers.bot_alias_arn} associated with Connect instance"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws connect disassociate-bot --instance-id ${self.triggers.instance_id} --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} --region ${self.triggers.region} || true"
  }

  depends_on = [awscc_lex_bot_alias.banking]
}

# Associate Sales Bot
resource "null_resource" "sales_bot_association" {
  count = var.connect_instance_id != "" ? 1 : 0
  
  triggers = {
    instance_id   = var.connect_instance_id
    bot_alias_arn = awscc_lex_bot_alias.sales.arn
    region        = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws connect associate-bot \
        --instance-id ${self.triggers.instance_id} \
        --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} \
        --region ${self.triggers.region}
      
      echo "✅ Sales bot ${self.triggers.bot_alias_arn} associated with Connect instance"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws connect disassociate-bot --instance-id ${self.triggers.instance_id} --lex-v2-bot AliasArn=${self.triggers.bot_alias_arn} --region ${self.triggers.region} || true"
  }

  depends_on = [awscc_lex_bot_alias.sales]
}
