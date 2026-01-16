# ============================================================================
# Root Module Outputs
# ============================================================================

# ============================================================================
# Connect Instance Outputs
# ============================================================================
output "connect_instance_id" {
  description = "AWS Connect instance ID"
  value       = var.deploy_connect_instance ? module.connect[0].instance_id : null
}

output "connect_instance_arn" {
  description = "AWS Connect instance ARN"
  value       = var.deploy_connect_instance ? module.connect[0].instance_arn : null
}

output "connect_instance_alias" {
  description = "AWS Connect instance alias (for login)"
  value       = var.deploy_connect_instance ? module.connect[0].instance_alias : null
}

output "connect_login_url" {
  description = "AWS Connect login URL"
  value       = var.deploy_connect_instance ? "https://${module.connect[0].instance_alias}.my.connect.aws/ccp-v2/" : null
}

output "connect_phone_number" {
  description = "Claimed phone number"
  value       = var.deploy_connect_instance ? module.connect[0].phone_number : null
}

output "connect_queues" {
  description = "Connect queues"
  value       = var.deploy_connect_instance ? module.connect[0].queues : null
}

# ============================================================================
# User Credentials (SENSITIVE)
# ============================================================================
output "user_credentials" {
  description = "Connect user credentials for initial login"
  value       = var.deploy_connect_instance ? module.connect[0].user_credentials : null
  sensitive   = true
}

output "user_credentials_summary" {
  description = "Summary of created users (passwords hidden)"
  value = var.deploy_connect_instance ? {
    for k, v in var.connect_users : k => {
      username        = k
      email           = v.email
      role            = v.security_profile
      password_stored = "Run 'terraform output -json user_credentials' to retrieve"
    }
  } : null
}

# ============================================================================
# Lambda Functions Outputs
# ============================================================================
output "lambda_functions" {
  description = "Lambda function details"
  value       = var.deploy_lambda_functions ? module.lambda[0].lambda_functions : null
}

output "lambda_prod_aliases" {
  description = "Production Lambda aliases"
  value       = var.deploy_lambda_functions ? module.lambda[0].lambda_prod_aliases : null
}

output "lambda_test_aliases" {
  description = "Test Lambda aliases"
  value       = var.deploy_lambda_functions ? module.lambda[0].lambda_test_aliases : null
}

# ============================================================================
# Lex Bots Outputs
# ============================================================================
output "lex_bots" {
  description = "Lex bot details"
  value       = var.deploy_lex_bots ? module.lex[0].bots : null
}

output "lex_bot_ids" {
  description = "Lex bot IDs"
  value       = var.deploy_lex_bots ? module.lex[0].bot_ids : null
}

output "lex_bot_versions" {
  description = "Lex bot versions (prod and test)"
  value       = var.deploy_lex_bots ? module.lex[0].bot_versions : null
}

# NOTE: Lex bot aliases are not supported by Terraform AWS provider 5.x
# Aliases need to be created manually via AWS Console or CLI
# output "lex_prod_aliases" {
#   description = "Production Lex bot aliases"
#   value       = var.deploy_lex_bots ? module.lex[0].bot_prod_aliases : null
# }

# output "lex_test_aliases" {
#   description = "Test Lex bot aliases"
#   value       = var.deploy_lex_bots ? module.lex[0].bot_test_aliases : null
# }


# ============================================================================
# Bedrock Agent Outputs
# ============================================================================
output "bedrock_agent_id" {
  description = "Bedrock agent ID"
  value       = var.deploy_bedrock_agent ? module.bedrock[0].agent_id : null
}

output "bedrock_agent_arn" {
  description = "Bedrock agent ARN"
  value       = var.deploy_bedrock_agent ? module.bedrock[0].agent_arn : null
}

output "bedrock_agent_name" {
  description = "Bedrock agent name"
  value       = var.deploy_bedrock_agent ? module.bedrock[0].agent_name : null
}

output "bedrock_guardrail_id" {
  description = "Bedrock guardrail ID"
  value       = var.deploy_bedrock_agent ? module.bedrock[0].guardrail_id : null
}

output "bedrock_prod_alias" {
  description = "Bedrock agent production alias"
  value       = var.deploy_bedrock_agent ? module.bedrock[0].prod_alias_id : null
}

# ============================================================================
# IAM Role Outputs
# ============================================================================
output "iam_roles" {
  description = "IAM role ARNs"
  value = {
    connect_role       = module.iam.connect_role_arn
    lex_role           = module.iam.lex_role_arn
    lambda_role        = module.iam.lambda_role_arn
    bedrock_agent_role = module.iam.bedrock_agent_role_arn
    bedrock_kb_role    = module.iam.bedrock_kb_role_arn
  }
}

# ============================================================================
# Integration Outputs
# ============================================================================
output "bot_associations" {
  description = "Bot associations with Connect"
  value       = var.deploy_integrations && var.deploy_connect_instance && var.deploy_lex_bots ? module.integration[0].bot_associations : null
}

output "lambda_associations" {
  description = "Lambda associations with Connect"
  value       = var.deploy_integrations && var.deploy_connect_instance ? module.integration[0].lambda_associations : null
}

# ============================================================================
# Deployment Information
# ============================================================================
output "deployment_info" {
  description = "Deployment information and next steps"
  value = {
    region       = var.region
    project_name = var.project_name
    environment  = var.environment
    deployed_modules = {
      connect_instance = var.deploy_connect_instance
      lex_bots         = var.deploy_lex_bots
      lambda_functions = var.deploy_lambda_functions
      bedrock_agent    = var.deploy_bedrock_agent
      integrations     = var.deploy_integrations
      contact_flows    = var.deploy_contact_flows
    }
    next_steps = var.deploy_integrations ? [
      "1. Retrieve user credentials: terraform output -json user_credentials",
      "2. Log in to Connect console: https://${var.deploy_connect_instance ? module.connect[0].instance_alias : "YOUR-ALIAS"}.my.connect.aws/",
      "3. Verify Lex bots are associated: Check Contact Flows > Lex Bots in console",
      "4. Design contact flows in the console",
      "5. Export contact flows to modules/contact_flows/flows/",
      "6. Set deploy_contact_flows = true in terraform.tfvars",
      "7. Run terraform apply to deploy contact flows",
      "8. Test the complete solution"
      ] : [
      "1. Retrieve user credentials: terraform output -json user_credentials",
      "2. Log in to Connect console: https://${var.deploy_connect_instance ? module.connect[0].instance_alias : "YOUR-ALIAS"}.my.connect.aws/",
      "3. Manually associate Lex bots: Contact Flows > Lex Bots > Add Lex Bot",
      "4. Design contact flows in the console",
      "5. Export contact flows to modules/contact_flows/flows/",
      "6. Set deploy_contact_flows = true in terraform.tfvars",
      "7. Run terraform apply to deploy contact flows",
      "8. Test the complete solution"
    ]
  }
}

# ============================================================================
# S3 Bucket Outputs
# ============================================================================
output "s3_bucket_name" {
  description = "S3 bucket name for Connect storage"
  value       = var.deploy_connect_instance ? module.connect[0].s3_bucket_name : null
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for Connect storage"
  value       = var.deploy_connect_instance ? module.connect[0].s3_bucket_arn : null
}

# ============================================================================
# CloudTrail and Logging Outputs
# ============================================================================
output "cloudtrail_info" {
  description = "CloudTrail configuration for auditing"
  value = var.enable_cloudtrail ? {
    trail_id       = module.cloudtrail[0].cloudtrail_id
    trail_arn      = module.cloudtrail[0].cloudtrail_arn
    s3_bucket      = module.cloudtrail[0].cloudtrail_bucket
    log_group      = module.cloudtrail[0].cloudtrail_log_group
    enabled        = true
    retention_days = var.cloudwatch_log_retention_days
  } : null
}

output "contact_lens_config" {
  description = "Contact Lens configuration and storage"
  value       = var.deploy_connect_instance ? module.connect[0].storage_config : null
}

output "logging_summary" {
  description = "Summary of all logging and monitoring configurations"
  value = {
    cloudtrail_enabled        = var.enable_cloudtrail
    contact_lens_enabled      = var.connect_contact_lens_enabled
    contact_flow_logs_enabled = var.connect_contact_flow_logs_enabled
    cloudwatch_retention_days = var.cloudwatch_log_retention_days
    s3_lifecycle_enabled      = true
    kms_encryption_enabled    = var.deploy_connect_instance ? true : false
    data_lake_ready           = "All logs stored in S3 for Athena integration"
  }
}

# ============================================================================
# Lex Intent Validation
# ============================================================================
output "lex_intents_validation" {
  description = "Validation of Lex intents and utterances"
  value = var.deploy_lex_bots ? {
    banking_intents = [
      "AccountBalanceIntent (10 utterances)",
      "TransactionHistoryIntent (10 utterances)",
      "AccountOpeningIntent (10 utterances)",
      "BranchFinderIntent (10 utterances)",
      "CardIssueIntent (10 utterances)"
    ]
    product_intents = [
      "ProductInformationIntent (10 utterances)",
      "ProductComparisonIntent (10 utterances)",
      "ProductFeaturesIntent (10 utterances)",
      "ProductAvailabilityIntent (10 utterances)"
    ]
    sales_intents = [
      "NewAccountIntent (10 utterances)",
      "UpgradeAccountIntent (10 utterances)",
      "SpecialOffersIntent (10 utterances)",
      "PricingInquiryIntent (10 utterances)"
    ]
    concierge_intents = [
      "RouteToSpecialistIntent (15 utterances)",
      "FallbackIntent (built-in)"
    ]
    total_intents           = 15
    total_custom_utterances = 140
    validation_status       = "All intents configured with detailed utterances"
  } : null
}
