resource "aws_lambda_function" "this" {
  # Use S3 for large packages (> 50MB), otherwise use filename
  filename           = var.s3_bucket == null ? var.filename : null
  s3_bucket          = var.s3_bucket
  s3_key             = var.s3_key
  s3_object_version  = var.s3_object_version
  
  function_name = var.function_name
  role          = var.role_arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size
  architectures = var.architectures
  publish       = var.publish

  # For S3 deployments, don't set source_code_hash - AWS computes it automatically
  # For file deployments, compute hash from file
  source_code_hash = var.source_code_hash != null ? var.source_code_hash : (var.filename != null && var.s3_bucket == null ? filebase64sha256(var.filename) : null)

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = var.environment_variables
  }

  tags = var.tags
}
