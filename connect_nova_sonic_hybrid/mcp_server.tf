# -------------------------------------------------------------------------
# Mock MCP Server (Backend API)
# -------------------------------------------------------------------------

# IAM Role for MCP Lambda (Zero Trust - No Public Access)
resource "aws_iam_role" "lambda_mcp_role" {
  name = "${var.project_name}-mcp-role"

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

resource "aws_iam_role_policy" "lambda_mcp_policy" {
  name = "${var.project_name}-mcp-policy"
  role = aws_iam_role.lambda_mcp_role.id

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
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_mcp_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_mcp"
  output_path = "${path.module}/lambda_mcp.zip"
}

resource "aws_lambda_function" "mcp_server" {
  filename         = data.archive_file.lambda_mcp_zip.output_path
  function_name    = "${var.project_name}-mcp-server"
  role             = aws_iam_role.lambda_mcp_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_mcp_zip.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 10

  environment {
    variables = {
      ENV    = "prod"
      LOCALE = var.locale
    }
  }
}

# CloudWatch Log Group for MCP
resource "aws_cloudwatch_log_group" "lambda_mcp_logs" {
  name              = "/aws/lambda/${var.project_name}-mcp-server"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.log_key.arn
}
