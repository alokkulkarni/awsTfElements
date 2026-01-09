variable "bot_name" {
  type = string
}

variable "fulfillment_lambda_arn" {
  type = string
}

variable "enable_chat_intent" {
    description = "Whether to create the default ChatIntent"
    type        = bool
    default     = true
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
  type    = map(string)
  default = {}
}

variable "conversation_log_group_arn" {
  description = "Optional ARN of the CloudWatch Log Group for conversation logs"
  type        = string
  default     = null
}

