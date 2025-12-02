output "id" {
  value = aws_connect_instance.this.id
}

output "arn" {
  value = aws_connect_instance.this.arn
}

output "hours_of_operation_id" {
  value = data.aws_connect_hours_of_operation.default.hours_of_operation_id
}
