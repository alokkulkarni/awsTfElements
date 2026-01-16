output "instance_id" {
  description = "ID of the Connect instance"
  value       = aws_connect_instance.main.id
}

output "instance_arn" {
  description = "ARN of the Connect instance"
  value       = aws_connect_instance.main.arn
}

output "instance_alias" {
  description = "Alias of the Connect instance"
  value       = aws_connect_instance.main.instance_alias
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Connect storage"
  value       = aws_s3_bucket.connect_storage.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Connect storage"
  value       = aws_s3_bucket.connect_storage.arn
}

output "queues" {
  description = "Map of created queues"
  value = {
    for k, v in aws_connect_queue.queues : k => {
      id          = v.queue_id
      arn         = v.arn
      name        = v.name
      description = v.description
    }
  }
}

output "queue_ids" {
  description = "Map of queue names to IDs"
  value = {
    for k, v in aws_connect_queue.queues : k => v.queue_id
  }
}

output "routing_profile_id" {
  description = "ID of the basic routing profile"
  value       = aws_connect_routing_profile.basic.routing_profile_id
}

output "routing_profile_arn" {
  description = "ARN of the basic routing profile"
  value       = aws_connect_routing_profile.basic.arn
}

output "users" {
  description = "Map of created users with credentials"
  value = {
    for k, v in aws_connect_user.users : k => {
      id               = v.user_id
      arn              = v.arn
      username         = v.name
      email            = v.identity_info[0].email
      password         = random_password.user_passwords[k].result
      security_profile = var.connect_users[k].security_profile
    }
  }
  sensitive = true
}

output "user_credentials" {
  description = "User credentials for initial login (SENSITIVE)"
  value = {
    for k, v in aws_connect_user.users : k => {
      username = v.name
      password = random_password.user_passwords[k].result
      email    = v.identity_info[0].email
      role     = var.connect_users[k].security_profile
    }
  }
  sensitive = true
}

output "phone_number" {
  description = "Claimed phone number details"
  value = var.claim_phone_number && length(aws_connect_phone_number.main) > 0 ? {
    id           = aws_connect_phone_number.main[0].id
    arn          = aws_connect_phone_number.main[0].arn
    phone_number = aws_connect_phone_number.main[0].phone_number
  } : null
}

output "hours_of_operation_id" {
  description = "ID of the hours of operation"
  value       = aws_connect_hours_of_operation.main.hours_of_operation_id
}

output "security_profiles" {
  description = "Map of security profile IDs"
  value = {
    admin               = data.aws_connect_security_profile.admin.security_profile_id
    agent               = data.aws_connect_security_profile.agent.security_profile_id
    call_center_manager = data.aws_connect_security_profile.call_center_manager.security_profile_id
    security_profile    = aws_connect_security_profile.security_profile.security_profile_id
  }
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Connect logs"
  value = {
    name = aws_cloudwatch_log_group.connect_logs.name
    arn  = aws_cloudwatch_log_group.connect_logs.arn
  }
}

output "kms_key" {
  description = "KMS key for encryption"
  value = {
    id  = aws_kms_key.connect_encryption.id
    arn = aws_kms_key.connect_encryption.arn
  }
}

output "transcript_encryption_key" {
  description = "KMS key for transcript encryption"
  value = {
    id  = aws_kms_key.transcript_encryption.id
    arn = aws_kms_key.transcript_encryption.arn
  }
  sensitive = true
}

output "original_transcripts_bucket" {
  description = "S3 bucket for original transcripts (secure, PII included)"
  value = {
    name = aws_s3_bucket.original_transcripts.bucket
    arn  = aws_s3_bucket.original_transcripts.arn
  }
  sensitive = true
}

output "redacted_transcripts_bucket" {
  description = "S3 bucket for PII-redacted transcripts (analytics-ready)"
  value = {
    name = aws_s3_bucket.redacted_transcripts.bucket
    arn  = aws_s3_bucket.redacted_transcripts.arn
  }
}

output "transcript_storage_summary" {
  description = "Summary of transcript storage configuration"
  value = {
    original_bucket = {
      name       = aws_s3_bucket.original_transcripts.bucket
      encryption = "KMS with dedicated transcript key"
      access     = "Restricted - Connect service only"
      data_class = "Confidential - Contains PII"
      retention  = "7 years (2555 days)"
      lifecycle  = "30d STANDARD_IA → 90d GLACIER → 365d DEEP_ARCHIVE"
    }
    redacted_bucket = {
      name       = aws_s3_bucket.redacted_transcripts.bucket
      encryption = "AES256"
      access     = "General - For analytics and data lake"
      data_class = "Public - PII Redacted"
      retention  = "7 years (2555 days)"
      lifecycle  = "30d STANDARD_IA → 90d GLACIER"
    }
    pii_redaction = {
      status = "Manual configuration required in Console"
      entities = [
        "NAME", "ADDRESS", "EMAIL", "PHONE", "SSN",
        "CREDIT_DEBIT_NUMBER", "CREDIT_DEBIT_CVV", "CREDIT_DEBIT_EXPIRY"
      ]
    }
    manual_steps = [
      "1. Go to Amazon Connect Console > Instance > Data storage > Contact Lens",
      "2. Enable Real-time contact analysis",
      "3. Configure Original bucket: ${aws_s3_bucket.original_transcripts.bucket}",
      "4. Configure Redacted bucket: ${aws_s3_bucket.redacted_transcripts.bucket}",
      "5. Enable PII redaction for listed entity types",
      "6. Set prefixes: RealTimeAnalysis/Original and RealTimeAnalysis/Redacted"
    ]
  }
}

output "storage_config" {
  description = "Connect storage configuration summary"
  value = {
    call_recordings            = "Enabled - S3: ${aws_s3_bucket.connect_storage.bucket}/CallRecordings"
    chat_transcripts           = "Enabled - S3: ${aws_s3_bucket.redacted_transcripts.bucket}/ChatTranscripts (PII Redacted)"
    contact_trace_records      = "Configure manually in Console (not supported by Terraform)"
    real_time_contact_analysis = "Configure manually in Console (not supported by Terraform)"
    scheduled_reports          = "Enabled - S3: ${aws_s3_bucket.connect_storage.bucket}/ScheduledReports"
    media_streams              = "Enabled - Kinesis Video Streams with KMS encryption"
    attachments                = "Enabled - S3: ${aws_s3_bucket.connect_storage.bucket}/Attachments"
    contact_lens_enabled       = aws_connect_instance.main.contact_lens_enabled
    contact_flow_logs_enabled  = aws_connect_instance.main.contact_flow_logs_enabled
  }
}
