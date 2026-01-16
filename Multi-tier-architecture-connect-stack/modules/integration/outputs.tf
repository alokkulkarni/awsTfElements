output "bot_associations" {
  description = "Map of bot associations"
  value = {
    for k, v in aws_connect_bot_association.bots : k => {
      id = v.id
    }
  }
}

output "lambda_associations" {
  description = "Map of Lambda function associations"
  value = {
    for k, v in aws_connect_lambda_function_association.functions : k => {
      id           = v.id
      function_arn = v.function_arn
    }
  }
}
