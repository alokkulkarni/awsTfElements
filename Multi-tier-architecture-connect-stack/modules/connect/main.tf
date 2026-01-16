# ============================================================================
# AWS Connect Instance Module
# Creates Connect instance with queues, routing profiles, users, and phone numbers
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# S3 Bucket for Connect Storage
# ============================================================================
resource "aws_s3_bucket" "connect_storage" {
  bucket = "${var.project_name}-${var.environment}-connect-storage-${data.aws_caller_identity.current.account_id}"
  
  tags = var.tags
}

resource "aws_s3_bucket_versioning" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id
  
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

resource "aws_s3_bucket_public_access_block" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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

resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CHAT_TRANSCRIPTS"
  
  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.bucket
      bucket_prefix = "ChatTranscripts"
    }
  }
}

resource "aws_connect_instance_storage_config" "contact_trace_records" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CONTACT_TRACE_RECORDS"
  
  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.bucket
      bucket_prefix = "ContactTraceRecords"
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

# ============================================================================
# Custom Security Profiles
# ============================================================================
resource "aws_connect_security_profile" "call_center_manager" {
  instance_id = aws_connect_instance.main.id
  name        = "CallCenterManager"
  description = "Call Center Manager with elevated permissions"
  
  permissions = [
    "AccessMetrics",
    "DescribeQueue",
    "DescribeRoutingProfile",
    "DescribeUser",
    "ListQueues",
    "ListRoutingProfiles",
    "ListUsers",
    "BasicAgentAccess",
    "ViewContactTraceRecords"
  ]
  
  tags = var.tags
}

resource "aws_connect_security_profile" "security_profile" {
  instance_id = aws_connect_instance.main.id
  name        = "SecurityProfile"
  description = "Security officer with audit and monitoring permissions"
  
  permissions = [
    "AccessMetrics",
    "ViewContactTraceRecords",
    "ListSecurityProfiles",
    "DescribeUser",
    "ListUsers"
  ]
  
  tags = var.tags
}

# ============================================================================
# Routing Profiles
# ============================================================================
resource "aws_connect_routing_profile" "basic" {
  instance_id               = aws_connect_instance.main.id
  name                      = "Basic Routing Profile"
  description               = "Basic routing profile for agents"
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
  
  length  = 16
  special = true
  override_special = "!@#$%&*()-_=+[]{}<>:?"
  min_lower   = 2
  min_upper   = 2
  min_numeric = 2
  min_special = 2
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
    each.value.security_profile == "CallCenterManager" ? aws_connect_security_profile.call_center_manager.security_profile_id :
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
