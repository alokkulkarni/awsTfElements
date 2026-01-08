variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "connect-comprehensive"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "connect_instance_alias" {
  description = "Alias for the Connect Instance"
  type        = string
  default     = "my-connect-instance-demo-123" # Needs to be globally unique
}

variable "locale" {
  description = "Locale for the bot (e.g., en_US, en_GB)"
  type        = string
  default     = "en_GB"
}

variable "voice_id" {
  description = "Voice ID for the bot (e.g., Danielle, Amy)"
  type        = string
  default     = "Amy"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project   = "ConnectComprehensive"
    ManagedBy = "Terraform"
  }
}

variable "queues" {
  description = "Map of queues to create"
  type = map(object({
    description = string
  }))
  default = {
    "GeneralAgentQueue" = { description = "Queue for general agents" }
    "AccountQueue"      = { description = "Queue for account services" }
    "LendingQueue"      = { description = "Queue for lending services" }
    "OnboardingQueue"   = { description = "Queue for onboarding services" }
  }
}

# Lex intents are no longer needed - using FallbackIntent only for Bedrock-primary architecture
# The Lex bot now uses a single FallbackIntent that passes all input to Bedrock via Lambda
# variable "lex_intents" {
#   description = "Map of Lex intents to create"
#   type = map(object({
#     description         = string
#     utterances          = list(string)
#     fulfillment_enabled = bool
#   }))
#   default = {}
# }

variable "bedrock_mcp_lambda" {
  description = "Configuration for the Bedrock MCP Lambda (Primary Intent Classification)"
  type = object({
    source_dir = string
    handler    = string
    runtime    = string
    timeout    = number
  })
  default = {
    source_dir = "lambda/bedrock_mcp"
    handler    = "lambda_function.lambda_handler"
    runtime    = "python3.11"
    timeout    = 60
  }
}

variable "bedrock_region" {
  description = "AWS region to call Bedrock runtime in (must support selected model)"
  type        = string
  default     = "us-east-1"
}

variable "specialized_intents" {
  description = "Configuration for specialized deterministic intents (hybrid architecture)"
  type = map(object({
    description = string
    utterances  = list(string)
    lambda = object({
      source_dir = string
      handler    = string
      runtime    = string
    })
  }))
  default = {}
}

# Deprecated variables removed - no longer needed in Bedrock-primary architecture
# - lex_fallback_lambda (replaced by bedrock_mcp_lambda)
# - enable_voice_id (not used in new architecture)
# - enable_pin_validation (not used in new architecture)
# - enable_companion_auth (not used in new architecture)
# - mock_data (not used in new architecture)
# - contact_flow_template_path (using bedrock_primary_flow.json.tftpl)

# ---------------------------------------------------------------------------------------------------------------------
# Data Lake Configuration
# ---------------------------------------------------------------------------------------------------------------------

variable "datalake_config" {
  description = "Configuration for the Data Lake (Kinesis streams, prefixes)"
  type = object({
    ctr_stream_shard_count          = number
    ctr_stream_retention_period     = number
    agent_events_stream_shard_count = number
    agent_events_stream_retention_period = number
    ctr_prefix                      = string
    agent_events_prefix             = string
  })
  default = {
    ctr_stream_shard_count          = 1
    ctr_stream_retention_period     = 24
    agent_events_stream_shard_count = 1
    agent_events_stream_retention_period = 24
    ctr_prefix                      = "ctr/"
    agent_events_prefix             = "agent-events/"
  }
}

variable "glue_catalog_database_name" {
    description = "Name of the Glue Catalog Database (defaults to project_name_datalake)"
    type        = string
    default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# Agent & Routing Configuration
# ---------------------------------------------------------------------------------------------------------------------

variable "routing_profiles" {
  description = "Map of routing profiles to create"
  type = map(object({
    description               = string
    default_outbound_queue_key = string # Key from var.queues
    media_concurrencies = list(object({
      channel     = string
      concurrency = number
    }))
    queue_configs = list(object({
      channel      = string
      delay        = number
      priority     = number
      queue_key    = string # Key from var.queues
    }))
  }))
  default = {}
}

variable "agents" {
  description = "Map of agents to create"
  type = map(object({
    first_name          = string
    last_name           = string
    email               = string
    password            = string
    routing_profile_key = string # Key from var.routing_profiles or "basic"
    security_profile_names = list(string) # e.g. ["Agent", "Admin"]
  }))
  default = {}
}
