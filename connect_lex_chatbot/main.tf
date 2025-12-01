locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stack       = "Connect-Lex-Chatbot"
  }
}

# --- Bedrock Guardrail (Content Moderation) ---
module "guardrail" {
  source = "../resources/bedrock_guardrail"

  name        = "${var.project_name}-guardrail"
  description = "Guardrail for Connect Chatbot"
  tags        = local.tags
}

# --- Lambda (Fulfillment Bridge) ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/index.mjs"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-fulfillment-role"

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
  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-fulfillment-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "bedrock:InvokeModel",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "fulfillment" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-fulfillment"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30

  environment {
    variables = {
      GUARDRAIL_ID      = module.guardrail.guardrail_id
      GUARDRAIL_VERSION = module.guardrail.guardrail_version
    }
  }

  tags = local.tags
}

# --- Amazon Lex (Conversational AI) ---
module "lex" {
  source = "../resources/lex"

  bot_name               = "${var.project_name}-bot"
  fulfillment_lambda_arn = aws_lambda_function.fulfillment.arn
  tags                   = local.tags
}

resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fulfillment.function_name
  principal     = "lex.amazonaws.com"
  source_arn    = module.lex.bot_alias_arn
}

# --- Amazon Connect (Telephony & Chat) ---
module "connect" {
  source = "../resources/connect"

  instance_alias = "${var.project_name}-instance"
  tags           = local.tags
}

# Note: Associating Lex with Connect usually requires the Connect Instance to be Active
# and is often done via CLI or Console as Terraform support can be tricky with timing.
# However, we can try to add the association resource if available or leave it as a manual step.
resource "aws_connect_bot_association" "this" {
  instance_id = module.connect.id
  lex_bot {
    lex_region = var.aws_region
    name       = module.lex.bot_alias_arn 
  }
}
