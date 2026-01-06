output "delivery_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.log_stream.arn
}

output "delivery_stream_name" {
  value = aws_kinesis_firehose_delivery_stream.log_stream.name
}

output "cloudwatch_to_firehose_role_arn" {
    value = aws_iam_role.cloudwatch_to_firehose.arn
}
