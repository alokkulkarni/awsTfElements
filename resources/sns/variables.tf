variable "name" {
  description = "Name of the SNS topic"
  type        = string
}

variable "kms_key_id" {
  description = "KMS Key ID for encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "subscriptions" {
  description = "Map of subscriptions"
  type = map(object({
    protocol = string
    endpoint = string
  }))
  default = {}
}
