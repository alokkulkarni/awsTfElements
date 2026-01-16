# ============================================================================
# Contact Center in a Box - Main Configuration
# Modular AWS Connect contact center with Lex, Lambda, and Bedrock
# ============================================================================

# Get current AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Local Variables
# ============================================================================
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      Region      = local.region
      ManagedBy   = "Terraform"
    }
  )
}

# ============================================================================
# Module: IAM Roles and Policies
# ============================================================================
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  region       = local.region
  account_id   = local.account_id
  tags         = local.common_tags
}

# ============================================================================
# Module: Lambda Functions
# ============================================================================
module "lambda" {
  count  = var.deploy_lambda_functions ? 1 : 0
  source = "./modules/lambda"

  project_name = var.project_name
  environment  = var.environment
  region       = local.region
  tags         = local.common_tags

  lambda_role_arn  = module.iam.lambda_role_arn
  lambda_functions = var.lambda_functions

  default_runtime     = var.lambda_runtime
  default_timeout     = var.lambda_timeout
  default_memory_size = var.lambda_memory_size

  depends_on = [module.iam]
}

# ============================================================================
# Module: Lex Bots
# ============================================================================
module "lex" {
  count  = var.deploy_lex_bots ? 1 : 0
  source = "./modules/lex"

  project_name = var.project_name
  environment  = var.environment
  region       = local.region
  tags         = local.common_tags

  lex_role_arn = module.iam.lex_role_arn
  lex_bots     = var.lex_bots

  lambda_functions = var.deploy_lambda_functions ? {
    for k, v in module.lambda[0].lambda_functions : k => {
      arn           = v.arn
      function_name = v.function_name
    }
  } : {}

  depends_on = [module.iam, module.lambda]
}

# ============================================================================
# Module: Bedrock Agent
# ============================================================================
module "bedrock" {
  count  = var.deploy_bedrock_agent ? 1 : 0
  source = "./modules/bedrock"

  project_name = var.project_name
  environment  = var.environment
  region       = local.region
  tags         = local.common_tags

  agent_name        = var.bedrock_agent_name
  agent_description = var.bedrock_agent_description
  agent_role_arn    = module.iam.bedrock_agent_role_arn
  foundation_model  = var.bedrock_foundation_model
  agent_instruction = var.bedrock_agent_instruction

  guardrail_name         = var.bedrock_guardrail_name
  guardrail_description  = var.bedrock_guardrail_description
  blocked_input_message  = var.bedrock_guardrail_blocked_input_message
  blocked_output_message = var.bedrock_guardrail_blocked_output_message

  depends_on = [module.iam]
}

# ============================================================================
# Module: AWS Connect Instance
# ============================================================================
module "connect" {
  count  = var.deploy_connect_instance ? 1 : 0
  source = "./modules/connect"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags

  instance_alias            = var.connect_instance_alias
  inbound_calls_enabled     = var.connect_inbound_calls_enabled
  outbound_calls_enabled    = var.connect_outbound_calls_enabled
  auto_resolve_best_voices  = var.connect_auto_resolve_best_voices
  contact_flow_logs_enabled = var.connect_contact_flow_logs_enabled
  contact_lens_enabled      = var.connect_contact_lens_enabled

  queues        = var.queues
  connect_users = var.connect_users

  claim_phone_number        = true
  phone_number_country_code = var.phone_number_country_code
  phone_number_type         = var.phone_number_type
  phone_number_description  = var.phone_number_description

  depends_on = [module.iam]
}

# ============================================================================
# Module: Contact Flows
# ============================================================================
module "contact_flows" {
  count  = var.deploy_connect_instance ? 1 : 0
  source = "./modules/contact_flows"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags

  connect_instance_id = module.connect[0].instance_id
  deploy_flows        = var.deploy_contact_flows
  contact_flows       = var.contact_flows

  depends_on = [module.connect]
}

# ============================================================================
# Module: Integrations (Bot and Lambda Associations)
# ============================================================================
module "integration" {
  count  = var.deploy_integrations && var.deploy_connect_instance && var.deploy_lex_bots ? 1 : 0
  source = "./modules/integration"

  connect_instance_id = module.connect[0].instance_id

  # Pass bot versions (using prod versions for Connect associations)
  bot_versions = module.lex[0].bot_versions.prod

  lambda_functions = var.deploy_lambda_functions ? {
    for k, v in module.lambda[0].lambda_functions : k => {
      arn           = v.arn
      function_name = v.function_name
    }
  } : {}

  bot_dependencies = [module.lex[0].bots]

  depends_on = [module.connect, module.lex, module.lambda]
}

# ============================================================================
# Module: CloudTrail for Auditing and Compliance
# ============================================================================
module "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  source = "./modules/cloudtrail"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags

  log_retention_days = var.cloudwatch_log_retention_days

  depends_on = [module.connect]
}
