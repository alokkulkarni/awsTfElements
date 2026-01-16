# ============================================================================
# AWS Connect Instance Module
# Creates Connect instance with queues, routing profiles, users, and phone numbers
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# S3 Bucket for Connect Storage (General)
# ============================================================================
resource "aws_s3_bucket" "connect_storage" {
  bucket        = "${var.project_name}-${var.environment}-connect-storage-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = var.tags
}

# S3 Bucket for Original Transcripts (Secure - Restricted Access)
# ============================================================================
resource "aws_s3_bucket" "original_transcripts" {
  bucket        = "${var.project_name}-${var.environment}-original-transcripts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-original-transcripts"
      DataClass   = "Confidential"
      Compliance  = "PII-Protected"
      Description = "Original transcripts with PII - Restricted Access Only"
    }
  )
}

# S3 Bucket for PII-Redacted Transcripts (General Access)
# ============================================================================
resource "aws_s3_bucket" "redacted_transcripts" {
  bucket        = "${var.project_name}-${var.environment}-redacted-transcripts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redacted-transcripts"
      DataClass   = "Public"
      Description = "PII-redacted transcripts for analytics and data lake"
    }
  )
}

resource "aws_s3_bucket_versioning" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "original_transcripts" {
  bucket = aws_s3_bucket.original_transcripts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "redacted_transcripts" {
  bucket = aws_s3_bucket.redacted_transcripts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# KMS encryption for original transcripts (enhanced security)
resource "aws_s3_bucket_server_side_encryption_configuration" "original_transcripts" {
  bucket = aws_s3_bucket.original_transcripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.transcript_encryption.arn
    }
    bucket_key_enabled = true
  }
}

# Standard encryption for redacted transcripts
resource "aws_s3_bucket_server_side_encryption_configuration" "redacted_transcripts" {
  bucket = aws_s3_bucket.redacted_transcripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "original_transcripts" {
  bucket = aws_s3_bucket.original_transcripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "redacted_transcripts" {
  bucket = aws_s3_bucket.redacted_transcripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Policy - Archive old data to Glacier for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id

  rule {
    id     = "archive-old-recordings"
    status = "Enabled"

    filter {
      prefix = "CallRecordings/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years retention for compliance
    }
  }

  rule {
    id     = "archive-contact-trace-records"
    status = "Enabled"

    filter {
      prefix = "ContactTraceRecords/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }

  rule {
    id     = "delete-old-analysis-segments"
    status = "Enabled"

    filter {
      prefix = "Analysis/"
    }

    expiration {
      days = 365 # Keep analysis data for 1 year
    }
  }
}

# Lifecycle for Original Transcripts (7-year compliance retention)
resource "aws_s3_bucket_lifecycle_configuration" "original_transcripts" {
  bucket = aws_s3_bucket.original_transcripts.id

  rule {
    id     = "original-transcripts-retention"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 years for compliance
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Lifecycle for Redacted Transcripts (cost-optimized, analytics-ready)
resource "aws_s3_bucket_lifecycle_configuration" "redacted_transcripts" {
  bucket = aws_s3_bucket.redacted_transcripts.id

  rule {
    id     = "redacted-transcripts-optimization"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years retention
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# KMS Key for general Connect encryption
resource "aws_kms_key" "connect_encryption" {
  description             = "KMS key for ${var.project_name}-${var.environment} Connect encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-connect-kms"
    }
  )
}

resource "aws_kms_alias" "connect_encryption" {
  name          = "alias/${var.project_name}-${var.environment}-connect"
  target_key_id = aws_kms_key.connect_encryption.key_id
}

# KMS Key for Original Transcript Encryption (Enhanced Security)
resource "aws_kms_key" "transcript_encryption" {
  description             = "KMS key for ${var.project_name}-${var.environment} original transcript encryption"
  deletion_window_in_days = 30 # Longer window for transcript protection
  enable_key_rotation     = true

  # Strict key policy for transcript access
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Connect Service"
        Effect = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-transcript-kms"
      Purpose     = "Original Transcript Encryption"
      Compliance  = "PII-Protected"
      Description = "KMS key for encrypting original transcripts with PII"
    }
  )
}

resource "aws_kms_alias" "transcript_encryption" {
  name          = "alias/${var.project_name}-${var.environment}-transcripts"
  target_key_id = aws_kms_key.transcript_encryption.key_id
}

# ============================================================================
# AWS Connect Instance
# ============================================================================
resource "aws_connect_instance" "main" {
  identity_management_type = "CONNECT_MANAGED"
  inbound_calls_enabled    = var.inbound_calls_enabled
  outbound_calls_enabled   = var.outbound_calls_enabled
  instance_alias           = var.instance_alias

  auto_resolve_best_voices_enabled = var.auto_resolve_best_voices
  contact_flow_logs_enabled        = var.contact_flow_logs_enabled
  contact_lens_enabled             = var.contact_lens_enabled
  early_media_enabled              = true
  multi_party_conference_enabled   = true

  tags = var.tags
}

# ============================================================================
# Connect Instance Storage Config
# ============================================================================
resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.bucket
      bucket_prefix = "CallRecordings"
    }
  }
}

# Chat Transcripts - Store in redacted bucket (PII will be redacted)
resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.redacted_transcripts.bucket
      bucket_prefix = "ChatTranscripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = aws_kms_key.transcript_encryption.arn
      }
    }
  }
}

# Note: CONTACT_TRACE_RECORDS storage type is not supported via Terraform
# CTRs are automatically stored when enabled in the console
# Or can be configured via AWS CLI/Console

# Note: REAL_TIME_CONTACT_ANALYSIS_SEGMENTS storage must be configured via Console
# After deployment, configure in AWS Console:
# 1. Go to Amazon Connect Console > Your Instance > Data storage > Contact Lens
# 2. Enable "Real-time contact analysis"
# 3. Set Original Transcripts bucket: ${var.project_name}-${var.environment}-original-transcripts-${data.aws_caller_identity.current.account_id}
# 4. Set Redacted Transcripts bucket: ${var.project_name}-${var.environment}-redacted-transcripts-${data.aws_caller_identity.current.account_id}
# 5. Enable PII redaction with following entity types:
#    - NAME, ADDRESS, EMAIL, PHONE, SSN, CREDIT_DEBIT_NUMBER, CREDIT_DEBIT_CVV, CREDIT_DEBIT_EXPIRY
# 6. Set prefix: "RealTimeAnalysis/Original" and "RealTimeAnalysis/Redacted"

# Scheduled Reports - Contact Lens scheduled reports and metrics
resource "aws_connect_instance_storage_config" "scheduled_reports" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "SCHEDULED_REPORTS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.bucket
      bucket_prefix = "ScheduledReports"
    }
  }
}

# Media Streams - Voice recordings for post-call analytics
resource "aws_connect_instance_storage_config" "media_streams" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "MEDIA_STREAMS"

  storage_config {
    storage_type = "KINESIS_VIDEO_STREAM"
    kinesis_video_stream_config {
      prefix                 = "MediaStreams"
      retention_period_hours = 24

      encryption_config {
        encryption_type = "KMS"
        key_id          = aws_kms_key.connect_encryption.arn
      }
    }
  }
}

# Attachments - For file uploads in chat
resource "aws_connect_instance_storage_config" "attachments" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "ATTACHMENTS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.bucket
      bucket_prefix = "Attachments"
    }
  }
}

# ============================================================================
# Connect Queues
# ============================================================================
resource "aws_connect_queue" "queues" {
  for_each = var.queues

  instance_id           = aws_connect_instance.main.id
  name                  = each.key
  description           = each.value.description
  hours_of_operation_id = aws_connect_hours_of_operation.main.hours_of_operation_id
  max_contacts          = each.value.max_contacts

  tags = merge(
    var.tags,
    {
      QueueName = each.key
    }
  )
}

# ============================================================================
# Hours of Operation (24/7)
# ============================================================================
resource "aws_connect_hours_of_operation" "main" {
  instance_id = aws_connect_instance.main.id
  name        = "24x7"
  description = "24 hours a day, 7 days a week"
  time_zone   = "UTC"

  config {
    day = "MONDAY"
    start_time {
      hours   = 0
      minutes = 0
    }
    end_time {
      hours   = 23
      minutes = 59
    }
  }

  config {
    day = "TUESDAY"
    start_time {
      hours   = 0
      minutes = 0
    }
    end_time {
      hours   = 23
      minutes = 59
    }
  }

  config {
    day = "WEDNESDAY"
    start_time {
      hours   = 0
      minutes = 0
    }
    end_time {
      hours   = 23
      minutes = 59
    }
  }

  config {
    day = "THURSDAY"
    start_time {
      hours   = 0
      minutes = 0
    }
    end_time {
      hours   = 23
      minutes = 59
    }
  }

  config {
    day = "FRIDAY"
    start_time {
      hours   = 0
      minutes = 0
    }
    end_time {
      hours   = 23
      minutes = 59
    }
  }

  config {
    day = "SATURDAY"
    start_time {
      hours   = 0
      minutes = 0
    }
    end_time {
      hours   = 23
      minutes = 59
    }
  }

  config {
    day = "SUNDAY"
    start_time {
      hours   = 0
      minutes = 0
    }
    end_time {
      hours   = 23
      minutes = 59
    }
  }

  tags = var.tags
}

# ============================================================================
# Get Default Security Profiles
# ============================================================================
data "aws_connect_security_profile" "admin" {
  instance_id = aws_connect_instance.main.id
  name        = "Admin"
}

data "aws_connect_security_profile" "agent" {
  instance_id = aws_connect_instance.main.id
  name        = "Agent"
}

# Use existing CallCenterManager security profile
data "aws_connect_security_profile" "call_center_manager" {
  instance_id = aws_connect_instance.main.id
  name        = "CallCenterManager"
}

# ============================================================================
# Custom Security Profiles
# ============================================================================
resource "aws_connect_security_profile" "security_profile" {
  instance_id = aws_connect_instance.main.id
  name        = "SecurityProfile"
  description = "Security officer with audit and monitoring permissions"

  permissions = [
    "AccessMetrics"
  ]

  tags = var.tags
}

# ============================================================================
# Routing Profiles
# ============================================================================
resource "aws_connect_routing_profile" "basic" {
  instance_id               = aws_connect_instance.main.id
  name                      = "Custom Basic Routing Profile"
  description               = "Custom basic routing profile for agents"
  default_outbound_queue_id = aws_connect_queue.queues["general"].queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 2
  }

  dynamic "queue_configs" {
    for_each = var.queues
    content {
      channel  = "VOICE"
      delay    = 0
      priority = queue_configs.key == "general" ? 1 : (queue_configs.key == "callback" ? 3 : 2)
      queue_id = aws_connect_queue.queues[queue_configs.key].queue_id
    }
  }

  dynamic "queue_configs" {
    for_each = var.queues
    content {
      channel  = "CHAT"
      delay    = 0
      priority = queue_configs.key == "general" ? 1 : (queue_configs.key == "callback" ? 3 : 2)
      queue_id = aws_connect_queue.queues[queue_configs.key].queue_id
    }
  }

  tags = var.tags
}

# ============================================================================
# Random Passwords for Users
# ============================================================================
resource "random_password" "user_passwords" {
  for_each = var.connect_users

  length           = 16
  special          = true
  override_special = "!@#$%&*()-_=+[]{}<>:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# ============================================================================
# Connect Users
# ============================================================================
resource "aws_connect_user" "users" {
  for_each = var.connect_users

  instance_id = aws_connect_instance.main.id
  name        = each.key

  password = random_password.user_passwords[each.key].result

  identity_info {
    email      = each.value.email
    first_name = each.value.first_name
    last_name  = each.value.last_name
  }

  phone_config {
    phone_type                    = "SOFT_PHONE"
    auto_accept                   = true
    after_contact_work_time_limit = 60
  }

  security_profile_ids = [
    each.value.security_profile == "Admin" ? data.aws_connect_security_profile.admin.security_profile_id :
    each.value.security_profile == "Agent" ? data.aws_connect_security_profile.agent.security_profile_id :
    each.value.security_profile == "CallCenterManager" ? data.aws_connect_security_profile.call_center_manager.security_profile_id :
    each.value.security_profile == "SecurityProfile" ? aws_connect_security_profile.security_profile.security_profile_id :
    data.aws_connect_security_profile.agent.security_profile_id
  ]

  routing_profile_id = aws_connect_routing_profile.basic.routing_profile_id

  tags = merge(
    var.tags,
    {
      Role = each.value.security_profile
    }
  )
}

# ============================================================================
# Phone Number Claim
# ============================================================================
resource "aws_connect_phone_number" "main" {
  count = var.claim_phone_number ? 1 : 0

  country_code = var.phone_number_country_code
  type         = var.phone_number_type
  target_arn   = aws_connect_instance.main.arn
  description  = var.phone_number_description

  tags = var.tags
}

# ============================================================================
# CloudWatch Log Group for Connect
# ============================================================================
resource "aws_cloudwatch_log_group" "connect_logs" {
  name              = "/aws/connect/${aws_connect_instance.main.id}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
