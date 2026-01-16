# ============================================================================
# General Configuration
# ============================================================================
variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# AWS Connect Instance Configuration
# ============================================================================
variable "connect_instance_alias" {
  description = "Globally unique alias for Connect instance"
  type        = string
}

variable "connect_inbound_calls_enabled" {
  description = "Enable inbound calls for Connect instance"
  type        = bool
  default     = true
}

variable "connect_outbound_calls_enabled" {
  description = "Enable outbound calls for Connect instance"
  type        = bool
  default     = true
}

variable "connect_auto_resolve_best_voices" {
  description = "Auto resolve best voices for Connect"
  type        = bool
  default     = true
}

variable "connect_contact_flow_logs_enabled" {
  description = "Enable contact flow logs"
  type        = bool
  default     = true
}

variable "connect_contact_lens_enabled" {
  description = "Enable Contact Lens"
  type        = bool
  default     = true
}

# ============================================================================
# Phone Number Configuration
# ============================================================================
variable "phone_number_country_code" {
  description = "Country code for phone number (e.g., GB, US)"
  type        = string
  default     = "GB"
}

variable "phone_number_type" {
  description = "Phone number type (DID or TOLL_FREE)"
  type        = string
  default     = "DID"
}

variable "phone_number_description" {
  description = "Description for claimed phone number"
  type        = string
  default     = "Main contact center number"
}

# ============================================================================
# Queue Configuration
# ============================================================================
variable "queues" {
  description = "Map of queues to create with their descriptions"
  type = map(object({
    description          = string
    max_contacts         = number
    default_outbound_qid = optional(string)
  }))
  default = {
    general = {
      description          = "General inquiries queue"
      max_contacts         = 10
      default_outbound_qid = null
    }
    banking = {
      description          = "Banking services queue"
      max_contacts         = 10
      default_outbound_qid = null
    }
    product = {
      description          = "Product information queue"
      max_contacts         = 10
      default_outbound_qid = null
    }
    sales = {
      description          = "Sales inquiries queue"
      max_contacts         = 10
      default_outbound_qid = null
    }
    callback = {
      description          = "Callback queue"
      max_contacts         = 5
      default_outbound_qid = null
    }
  }
}

# ============================================================================
# User Role Configuration
# ============================================================================
variable "connect_users" {
  description = "Map of Connect users to create with their roles"
  type = map(object({
    email            = string
    first_name       = string
    last_name        = string
    security_profile = string
    routing_profile  = optional(string, "Basic Routing Profile")
  }))
  default = {}
}

# ============================================================================
# Lex Bot Configuration
# ============================================================================
variable "lex_bots" {
  description = "Map of Lex bots to create"
  type = map(object({
    description      = string
    bot_type         = string # concierge or domain
    idle_session_ttl = number
    locale           = string
    voice_id         = string
  }))
  default = {}
}

variable "lex_bot_aliases" {
  description = "List of bot aliases to create (prod, test)"
  type        = list(string)
  default     = ["prod", "test"]
}

# ============================================================================
# Lambda Configuration
# ============================================================================
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "lambda_functions" {
  description = "Map of Lambda functions to create for each domain"
  type = map(object({
    description      = string
    handler          = string
    runtime          = optional(string)
    timeout          = optional(number)
    memory_size      = optional(number)
    environment_vars = optional(map(string), {})
  }))
  default = {}
}

# ============================================================================
# Bedrock Agent Configuration
# ============================================================================
variable "bedrock_agent_name" {
  description = "Name for the Bedrock agent"
  type        = string
  default     = "banking-assistant-agent"
}

variable "bedrock_agent_description" {
  description = "Description for the Bedrock agent"
  type        = string
  default     = "Banking assistant for intent classification and product information"
}

variable "bedrock_foundation_model" {
  description = "Bedrock foundation model ID"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "bedrock_agent_instruction" {
  description = "Instructions for the Bedrock agent"
  type        = string
  default     = <<-EOT
    You are a banking assistant responsible for:
    1. Classifying customer queries into appropriate categories (banking, product, sales, general)
    2. Providing information about account opening processes
    3. Helping customers find branch locations
    4. Answering general banking product questions
    5. Identifying when queries need specialist attention
    
    Always be professional, accurate, and helpful. If unsure about classification, route to general queue.
  EOT
}

variable "bedrock_guardrail_name" {
  description = "Name for the Bedrock guardrail"
  type        = string
  default     = "banking-guardrail"
}

variable "bedrock_guardrail_description" {
  description = "Description for the Bedrock guardrail"
  type        = string
  default     = "Guardrails for banking assistant agent"
}

variable "bedrock_guardrail_blocked_input_message" {
  description = "Message to display when input is blocked"
  type        = string
  default     = "I apologize, but I cannot process that request. Please rephrase or contact our support team."
}

variable "bedrock_guardrail_blocked_output_message" {
  description = "Message to display when output is blocked"
  type        = string
  default     = "I apologize, but I cannot provide that information. Please contact our support team for assistance."
}

# ============================================================================
# Contact Flow Configuration (for future implementation)
# ============================================================================
variable "deploy_contact_flows" {
  description = "Deploy contact flows (set to false until flows are designed in console)"
  type        = bool
  default     = false
}

variable "contact_flows" {
  description = "Map of contact flows to deploy"
  type = map(object({
    description = string
    type        = string
    filename    = string
  }))
  default = {
    main = {
      description = "Main contact flow"
      type        = "CONTACT_FLOW"
      filename    = "flows/main_flow.json"
    }
    customer_queue = {
      description = "Customer queue flow"
      type        = "CUSTOMER_QUEUE"
      filename    = "flows/customer_queue_flow.json"
    }
    callback = {
      description = "Callback flow"
      type        = "CONTACT_FLOW"
      filename    = "flows/callback_flow.json"
    }
  }
}

# ============================================================================
# Module Deployment Control
# ============================================================================
variable "deploy_connect_instance" {
  description = "Deploy Connect instance module"
  type        = bool
  default     = true
}

variable "deploy_lex_bots" {
  description = "Deploy Lex bots module"
  type        = bool
  default     = true
}

variable "deploy_lambda_functions" {
  description = "Deploy Lambda functions module"
  type        = bool
  default     = true
}

variable "deploy_bedrock_agent" {
  description = "Deploy Bedrock agent module"
  type        = bool
  default     = true
}

variable "deploy_integrations" {
  description = "Deploy integration module (bot registration, etc.)"
  type        = bool
  default     = true
}

# ============================================================================
# Logging and Auditing Configuration
# ============================================================================
variable "enable_cloudtrail" {
  description = "Enable CloudTrail for auditing and compliance"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days for all services"
  type        = number
  default     = 90
}
