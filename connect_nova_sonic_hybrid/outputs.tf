output "voice_lambda_arn" {
  description = "ARN of the Voice Orchestrator Lambda"
  value       = aws_lambda_function.voice_orchestrator.arn
}

output "lex_bot_alias_arn" {
  description = "ARN of the Lex Bot Alias"
  value       = awscc_lex_bot_alias.prod.arn
}

output "lex_bot_name" {
  description = "Name of the Lex Bot"
  value       = aws_lexv2models_bot.chat_bot.name
}

output "queue_arns" {
  description = "Map of Queue Names to ARNs"
  value       = { for k, v in aws_connect_queue.queues : k => v.arn }
}
