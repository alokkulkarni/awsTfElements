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
  value = awscc_lex_bot_alias.this.arn
}

output "bot_alias_id" {
  value = awscc_lex_bot_alias.this.bot_alias_id
}
