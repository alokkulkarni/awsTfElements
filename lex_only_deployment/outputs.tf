output "main_bot_id" {
  description = "ID of the main gateway bot"
  value       = aws_lexv2models_bot.main.id
}

output "main_bot_alias_id" {
  description = "ID of the main bot alias"
  value       = awscc_lex_bot_alias.main.bot_alias_id
}

output "banking_bot_id" {
  description = "ID of the banking bot"
  value       = aws_lexv2models_bot.banking.id
}

output "banking_bot_alias_id" {
  description = "ID of the banking bot alias"
  value       = awscc_lex_bot_alias.banking.bot_alias_id
}

output "sales_bot_id" {
  description = "ID of the sales bot"
  value       = aws_lexv2models_bot.sales.id
}

output "sales_bot_alias_id" {
  description = "ID of the sales bot alias"
  value       = awscc_lex_bot_alias.sales.bot_alias_id
}

output "bedrock_mcp_lambda_arn" {
  description = "ARN of the Bedrock MCP Lambda function"
  value       = aws_lambda_function.bedrock_mcp.arn
}

output "bedrock_mcp_lambda_alias_arn" {
  description = "ARN of the Bedrock MCP Lambda alias"
  value       = aws_lambda_alias.bedrock_mcp_live.arn
}

output "banking_lambda_arn" {
  description = "ARN of the Banking Lambda function"
  value       = aws_lambda_function.banking.arn
}

output "banking_lambda_alias_arn" {
  description = "ARN of the Banking Lambda alias"
  value       = aws_lambda_alias.banking_live.arn
}

output "sales_lambda_arn" {
  description = "ARN of the Sales Lambda function"
  value       = aws_lambda_function.sales.arn
}

output "sales_lambda_alias_arn" {
  description = "ARN of the Sales Lambda alias"
  value       = aws_lambda_alias.sales_live.arn
}
