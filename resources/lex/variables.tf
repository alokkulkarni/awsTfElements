variable "bot_name" {
  type = string
}

variable "fulfillment_lambda_arn" {
  type = string
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
