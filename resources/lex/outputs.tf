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
