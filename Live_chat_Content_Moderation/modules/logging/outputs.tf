output "logs_bucket_id" {
  value = module.s3_logs.id
}

output "logs_bucket_arn" {
  value = module.s3_logs.arn
}

output "kms_key_arn" {
  value = module.kms.arn
}

