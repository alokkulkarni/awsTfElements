output "bot_id" {
  value = aws_lexv2models_bot.this.id
}

output "bot_alias_id" {
  value = awscc_lex_bot_alias.this.bot_alias_id
}

output "bot_alias_arn" {
  value = awscc_lex_bot_alias.this.arn
}
