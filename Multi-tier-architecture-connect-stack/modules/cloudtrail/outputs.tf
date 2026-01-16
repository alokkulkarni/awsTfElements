output "cloudtrail_id" {
  description = "CloudTrail ID"
  value       = aws_cloudtrail.main.id
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_bucket" {
  description = "CloudTrail S3 bucket name"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch log group name"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}
