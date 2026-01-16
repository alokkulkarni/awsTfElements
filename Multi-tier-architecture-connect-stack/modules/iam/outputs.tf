output "connect_role_arn" {
  description = "ARN of the Connect IAM role"
  value       = aws_iam_role.connect.arn
}

output "connect_role_name" {
  description = "Name of the Connect IAM role"
  value       = aws_iam_role.connect.name
}

output "lex_role_arn" {
  description = "ARN of the Lex IAM role"
  value       = aws_iam_role.lex.arn
}

output "lex_role_name" {
  description = "Name of the Lex IAM role"
  value       = aws_iam_role.lex.name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda IAM role"
  value       = aws_iam_role.lambda.name
}

output "bedrock_agent_role_arn" {
  description = "ARN of the Bedrock agent IAM role"
  value       = aws_iam_role.bedrock_agent.arn
}

output "bedrock_agent_role_name" {
  description = "Name of the Bedrock agent IAM role"
  value       = aws_iam_role.bedrock_agent.name
}

output "bedrock_kb_role_arn" {
  description = "ARN of the Bedrock knowledge base IAM role"
  value       = aws_iam_role.bedrock_kb.arn
}

output "bedrock_kb_role_name" {
  description = "Name of the Bedrock knowledge base IAM role"
  value       = aws_iam_role.bedrock_kb.name
}
