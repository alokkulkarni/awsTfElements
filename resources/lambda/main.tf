resource "aws_lambda_function" "this" {
  filename      = var.filename
  function_name = var.function_name
  role          = var.role_arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size
  architectures = var.architectures
  publish       = var.publish

  # Ensure code updates are detected when the artifact content changes
  source_code_hash = var.source_code_hash != null ? var.source_code_hash : filebase64sha256(var.filename)

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = var.environment_variables
  }

  tags = var.tags
}
