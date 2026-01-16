output "lambda_functions" {
  description = "Map of Lambda function details"
  value = {
    for k, v in aws_lambda_function.domain_functions : k => {
      arn           = v.arn
      function_name = v.function_name
      invoke_arn    = v.invoke_arn
      version       = v.version
    }
  }
}

output "lambda_function_arns" {
  description = "List of Lambda function ARNs"
  value       = [for f in aws_lambda_function.domain_functions : f.arn]
}

output "lambda_prod_aliases" {
  description = "Map of production Lambda aliases"
  value = {
    for k, v in aws_lambda_alias.prod : k => {
      arn          = v.arn
      function_name = v.function_name
      name         = v.name
      version      = v.function_version
    }
  }
}

output "lambda_test_aliases" {
  description = "Map of test Lambda aliases"
  value = {
    for k, v in aws_lambda_alias.test : k => {
      arn          = v.arn
      function_name = v.function_name
      name         = v.name
      version      = v.function_version
    }
  }
}
