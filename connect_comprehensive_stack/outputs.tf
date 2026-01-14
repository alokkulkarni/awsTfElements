output "connect_instance_id" {
  description = "The ID of the Connect Instance"
  value       = module.connect_instance.id
}

output "connect_instance_arn" {
  description = "The ARN of the Connect Instance"
  value       = module.connect_instance.arn
}

output "lex_bot_id" {
  description = "The ID of the Lex Bot"
  value       = module.lex_bot.bot_id
}

output "specialized_bots" {
    description = "Details of the specialized bots"
    value = {
        banking_arn = awscc_lex_bot_alias.banking.arn
        sales_arn   = awscc_lex_bot_alias.sales.arn
    }
}

output "lex_bot_name" {
  description = "The name of the Lex Bot"
  value       = module.lex_bot.bot_name
}

output "lex_bot_alias_id" {
  description = "The ID of the main Lex Bot alias"
  value       = awscc_lex_bot_alias.this.bot_alias_id
}

output "lex_bot_alias_arn" {
  description = "The ARN of the main Lex Bot alias"
  value       = awscc_lex_bot_alias.this.arn
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for storage"
  value       = module.connect_storage_bucket.id
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table for new intents"
  value       = module.intent_table.name
}

output "ccp_url" {
  description = "The URL of the custom CCP"
  value       = "https://${aws_cloudfront_distribution.ccp_site.domain_name}"
}

output "connect_instance_alias" {
  description = "The alias of the Connect Instance"
  value       = var.connect_instance_alias
}

output "connect_instance_access_url" {
  description = "The access URL for the Connect Instance"
  value       = "https://${var.connect_instance_alias}.my.connect.aws"
}

output "did_phone_number" {
  description = "The claimed DID phone number"
  value       = aws_connect_phone_number.outbound.phone_number
}

output "toll_free_phone_number" {
  description = "The claimed Toll-Free phone number"
  value       = aws_connect_phone_number.toll_free.phone_number
}

output "hallucination_logs_table_name" {
  description = "The name of the DynamoDB table for hallucination logs"
  value       = module.hallucination_logs_table.name
}

output "bedrock_primary_flow_id" {
  description = "The ID of the Bedrock Primary contact flow with AI-first routing"
  value       = aws_connect_contact_flow.bedrock_primary.contact_flow_id
}
