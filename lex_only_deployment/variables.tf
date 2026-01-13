variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "lex-only"
}

variable "locale" {
  description = "Locale for the bot (e.g., en_US, en_GB)"
  type        = string
  default     = "en_GB"
}

variable "voice_id" {
  description = "Voice ID for the bot (e.g., Danielle, Amy, Joanna)"
  type        = string
  default     = "Amy"
}

variable "bedrock_region" {
  description = "AWS Region for Bedrock"
  type        = string
  default     = "us-east-1"
}

variable "connect_instance_id" {
  description = "Amazon Connect Instance ID (optional - required to associate bots with Connect)"
  type        = string
  default     = ""
}

variable "bedrock_model_id" {
  description = "Bedrock Model ID for Claude"
  type        = string
  default     = "arn:aws:bedrock:us-east-1:395402194296:inference-profile/us.anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project   = "LexOnly"
    ManagedBy = "Terraform"
  }
}

variable "specialized_intents" {
  description = "Map of specialized intents for Banking Bot"
  type = map(object({
    description = string
    utterances  = list(string)
  }))
  default = {
    "CheckBalance" = {
      description = "Check account balance"
      utterances  = ["Check my balance", "How much money do I have", "What is my balance"]
    }
    "GetStatement" = {
      description = "Generate and send account statement"
      utterances  = ["Get my statement", "Send me a statement", "I need my latest statement"]
    }
    "CancelDirectDebit" = {
      description = "Cancel a direct debit"
      utterances  = ["Cancel direct debit", "Stop a direct debit", "Remove direct debit"]
    }
    "CancelStandingOrder" = {
      description = "Cancel a standing order"
      utterances  = ["Cancel standing order", "Stop standing order", "Remove standing instruction"]
    }
  }
}
