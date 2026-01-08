resource "aws_kinesis_stream" "this" {
  name             = var.name
  shard_count      = var.shard_count
  retention_period = var.retention_period

  tags = var.tags
}

output "arn" {
  value = aws_kinesis_stream.this.arn
}

output "name" {
    value = aws_kinesis_stream.this.name
}

output "id" {
    value = aws_kinesis_stream.this.id
}
