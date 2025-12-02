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
    Project = "ConnectComprehensive"
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

variable "lex_intents" {
  description = "Map of Lex intents to create"
  type = map(object({
    description = string
    utterances  = list(string)
    fulfillment_enabled = bool
  }))
  default = {
    "TransferToAgent" = {
      description = "Transfer to a human agent"
      utterances  = ["I want to speak to a human", "Agent please"]
      fulfillment_enabled = false
    }
    "CheckBalance" = {
      description = "Check account balance"
      utterances  = ["check balance", "what is my balance", "how much money do I have"]
      fulfillment_enabled = true
    }
    "LoanInquiry" = {
      description = "Inquire about loans"
      utterances  = ["apply for loan", "loan status", "business loan options"]
      fulfillment_enabled = true
    }
    "OnboardingStatus" = {
      description = "Check onboarding application status"
      utterances  = ["application status", "onboarding help", "status of my application"]
      fulfillment_enabled = true
    }
  }
}

variable "lex_fallback_lambda" {
  description = "Configuration for the Lex Fallback Lambda"
  type = object({
    source_dir  = string
    handler     = string
    runtime     = string
    timeout     = number
  })
  default = {
    source_dir  = "lambda/lex_fallback"
    handler     = "lex_handler.lambda_handler"
    runtime     = "python3.11"
    timeout     = 30
  }
}

variable "enable_voice_id" {
  description = "Enable Voice ID biometric validation in the Lambda fulfillment"
  type        = bool
  default     = false
}

variable "enable_pin_validation" {
  description = "Enable PIN-based validation in the Lambda fulfillment"
  type        = bool
  default     = false
}

variable "enable_companion_auth" {
  description = "Enable Companion App Authentication"
  type        = bool
  default     = true
}

variable "mock_data" {
  description = "JSON string containing mock customer data for the Lambda"
  type        = string
  default     = "{\" +15550100\": {\"name\": \"John Doe\", \"pin\": \"1234\", \"balance\": \"$15,450.00\"}, \"+447700900000\": {\"name\": \"Jane Smith\", \"pin\": \"5678\", \"balance\": \"£2,300.00\"}}"
}

variable "contact_flow_template_path" {
  description = "Path to the Contact Flow template file"
  type        = string
  default     = "contact_flows/main_flow.json.tftpl"
}
