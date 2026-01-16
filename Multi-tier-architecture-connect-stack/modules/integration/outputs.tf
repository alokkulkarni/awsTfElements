output "bot_associations" {
  description = "Bot associations with Connect (created via AWS CLI)"
  value = {
    for k, v in null_resource.bot_associations : k => {
      bot_id        = v.triggers.bot_id
      bot_name      = v.triggers.bot_name
      bot_alias_arn = v.triggers.bot_alias_arn
      instance_id   = v.triggers.instance_id
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

output "bot_association_count" {
  description = "Number of bots associated with Connect"
  value       = length(null_resource.bot_associations)
}
