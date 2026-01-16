# ============================================================================
# Lambda Functions Module
# This module creates Lambda functions with compilation and deployment
# ============================================================================

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# ============================================================================
# Lambda Functions
# ============================================================================
resource "aws_lambda_function" "domain_functions" {
  for_each = var.lambda_functions
  
  function_name = "${var.project_name}-${var.environment}-${each.key}-fulfillment"
  description   = each.value.description
  role          = var.lambda_role_arn
  handler       = each.value.handler
  runtime       = each.value.runtime != null ? each.value.runtime : var.default_runtime
  timeout       = each.value.timeout != null ? each.value.timeout : var.default_timeout
  memory_size   = each.value.memory_size != null ? each.value.memory_size : var.default_memory_size
  
  filename         = data.archive_file.lambda_zip[each.key].output_path
  source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256
  
  environment {
    variables = merge(
      {
        ENVIRONMENT   = var.environment
        PROJECT_NAME  = var.project_name
        DOMAIN        = each.key
        LOG_LEVEL     = "INFO"
      },
      each.value.environment_vars
    )
  }
  
  tags = merge(
    var.tags,
    {
      Domain = each.key
    }
  )
}

# ============================================================================
# Lambda Function Archives (Compile/Package Lambda Code)
# ============================================================================
data "archive_file" "lambda_zip" {
  for_each = var.lambda_functions
  
  type        = "zip"
  source_dir  = "${path.module}/src/${each.key}"
  output_path = "${path.module}/dist/${each.key}.zip"
  
  depends_on = [local_file.lambda_code]
}

# ============================================================================
# Lambda Source Code Files
# ============================================================================
resource "local_file" "lambda_code" {
  for_each = var.lambda_functions
  
  filename = "${path.module}/src/${each.key}/index.py"
  content  = templatefile("${path.module}/templates/${each.key}_handler.tpl", {
    domain       = each.key
    project_name = var.project_name
    environment  = var.environment
  })
}

# ============================================================================
# Lambda Aliases
# ============================================================================
resource "aws_lambda_alias" "prod" {
  for_each = var.lambda_functions
  
  name             = "prod"
  description      = "Production alias"
  function_name    = aws_lambda_function.domain_functions[each.key].function_name
  function_version = "$LATEST"
}

resource "aws_lambda_alias" "test" {
  for_each = var.lambda_functions
  
  name             = "test"
  description      = "Test alias"
  function_name    = aws_lambda_function.domain_functions[each.key].function_name
  function_version = "$LATEST"
}

# ============================================================================
# Lambda Permissions for Lex
# ============================================================================
resource "aws_lambda_permission" "lex_invoke" {
  for_each = var.lambda_functions
  
  statement_id  = "AllowExecutionFromLex"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.domain_functions[each.key].function_name
  principal     = "lexv2.amazonaws.com"
  source_arn    = "arn:aws:lex:${var.region}:${data.aws_caller_identity.current.account_id}:bot-alias/*"
}

# ============================================================================
# Lambda Permissions for Connect
# ============================================================================
resource "aws_lambda_permission" "connect_invoke" {
  for_each = var.lambda_functions
  
  statement_id  = "AllowExecutionFromConnect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.domain_functions[each.key].function_name
  principal     = "connect.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = var.lambda_functions
  
  name              = "/aws/lambda/${aws_lambda_function.domain_functions[each.key].function_name}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}
