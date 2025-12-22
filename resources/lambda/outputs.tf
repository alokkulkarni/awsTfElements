output "arn" {
  value = aws_lambda_function.this.arn
}

output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}

output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "version" {
  description = "Published version of the Lambda function when publish=true"
  value       = aws_lambda_function.this.version
}
