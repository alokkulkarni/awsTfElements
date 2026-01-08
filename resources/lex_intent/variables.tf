variable "bot_id" {
  description = "The ID of the bot"
  type        = string
}

variable "bot_version" {
  description = "The version of the bot"
  type        = string
  default     = "DRAFT"
}

variable "locale_id" {
  description = "The identifier of the language and locale"
  type        = string
}

variable "name" {
  description = "The name of the intent"
  type        = string
}

variable "description" {
  description = "The description of the intent"
  type        = string
  default     = null
}

variable "sample_utterances" {
  description = "List of sample utterances"
  type        = list(string)
  default     = []
}

variable "fulfillment_enabled" {
  description = "Whether fulfillment is enabled for this intent"
  type        = bool
  default     = true
}
