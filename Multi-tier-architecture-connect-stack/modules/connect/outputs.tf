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
      id       = v.user_id
      arn      = v.arn
      username = v.name
      email    = v.identity_info[0].email
      password = random_password.user_passwords[k].result
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
    admin                = data.aws_connect_security_profile.admin.security_profile_id
    agent                = data.aws_connect_security_profile.agent.security_profile_id
    call_center_manager  = aws_connect_security_profile.call_center_manager.security_profile_id
    security_profile     = aws_connect_security_profile.security_profile.security_profile_id
  }
}
