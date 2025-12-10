resource "aws_lambda_function" "this" {
  filename      = var.filename
  function_name = var.function_name
  role          = var.role_arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = var.environment_variables
  }

  tags = var.tags
}
