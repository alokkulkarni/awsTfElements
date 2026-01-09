output "bot_id" {
  value = aws_lexv2models_bot.this.id
}



output "bot_name" {
  value = aws_lexv2models_bot.this.name
}

output "bot_arn" {
  value = aws_lexv2models_bot.this.arn
}

output "locale_id" {
  value = aws_lexv2models_bot_locale.this.locale_id
}

output "bot_locale_id" {
  value = aws_lexv2models_bot_locale.this.id
}

output "chat_intent_id" {
  value = length(aws_lexv2models_intent.chat) > 0 ? aws_lexv2models_intent.chat[0].id : null
}

output "bot_alias_arn" {
  value = var.create_alias ? awscc_lex_bot_alias.this[0].arn : null
}

output "bot_alias_id" {
  value = var.create_alias ? awscc_lex_bot_alias.this[0].bot_alias_id : null
}
