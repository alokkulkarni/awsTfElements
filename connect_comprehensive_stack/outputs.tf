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

output "lex_bot_name" {
  description = "The name of the Lex Bot"
  value       = module.lex_bot.bot_name
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for storage"
  value       = module.connect_storage_bucket.id
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table for new intents"
  value       = module.intent_table.name
}
