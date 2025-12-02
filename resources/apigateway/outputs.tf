output "id" {
  value = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "api_execution_arn" {
  value = aws_apigatewayv2_api.this.execution_arn
}
