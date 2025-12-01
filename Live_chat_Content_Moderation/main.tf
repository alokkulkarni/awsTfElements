module "logging" {
  source = "./modules/logging"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  tags         = var.tags
}

module "networking" {
  source = "./modules/networking"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  project_name         = var.project_name
  logs_bucket_arn      = module.logging.logs_bucket_arn
  tags                 = var.tags
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  tags         = var.tags
}

module "data" {
  source = "./modules/data"

  project_name = var.project_name
  tags         = var.tags
}

module "ai" {
  source = "./modules/ai"

  project_name = var.project_name
  tags         = var.tags
}

module "frontend" {
  source = "./modules/frontend"

  project_name   = var.project_name
  environment    = var.environment
  waf_acl_arn    = module.security.web_acl_arn
  logs_bucket_id = module.logging.logs_bucket_id
  tags           = var.tags
}

module "backend" {
  source = "./modules/backend"

  project_name = var.project_name
  dynamodb_tables = {
    hallucinations = {
      name = module.data.hallucinations_table_name
      arn  = module.data.hallucinations_table_arn
    }
    approved_messages = {
      name = module.data.approved_messages_table_name
      arn  = module.data.approved_messages_table_arn
    }
    unapproved_messages = {
      name = module.data.unapproved_messages_table_name
      arn  = module.data.unapproved_messages_table_arn
    }
    prompt_store = {
      name = module.data.prompt_store_table_name
      arn  = module.data.prompt_store_table_arn
    }
  }
  guardrail_id      = module.ai.guardrail_arn
  guardrail_version = module.ai.guardrail_version
  tags              = var.tags
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = module.logging.logs_bucket_id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = module.logging.kms_key_arn
  tags                          = var.tags
}
