variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "instance_alias" {
  description = "Globally unique alias for Connect instance"
  type        = string
}

variable "inbound_calls_enabled" {
  description = "Enable inbound calls"
  type        = bool
  default     = true
}

variable "outbound_calls_enabled" {
  description = "Enable outbound calls"
  type        = bool
  default     = true
}

variable "auto_resolve_best_voices" {
  description = "Auto resolve best voices"
  type        = bool
  default     = true
}

variable "contact_flow_logs_enabled" {
  description = "Enable contact flow logs"
  type        = bool
  default     = true
}

variable "contact_lens_enabled" {
  description = "Enable Contact Lens"
  type        = bool
  default     = true
}

variable "queues" {
  description = "Map of queues to create"
  type = map(object({
    description          = string
    max_contacts         = number
    default_outbound_qid = optional(string)
  }))
}

variable "connect_users" {
  description = "Map of Connect users to create"
  type = map(object({
    email            = string
    first_name       = string
    last_name        = string
    security_profile = string
    routing_profile  = optional(string, "Basic Routing Profile")
  }))
}

variable "claim_phone_number" {
  description = "Whether to claim a phone number"
  type        = bool
  default     = true
}

variable "phone_number_country_code" {
  description = "Country code for phone number"
  type        = string
  default     = "GB"
}

variable "phone_number_type" {
  description = "Phone number type"
  type        = string
  default     = "DID"
}

variable "phone_number_description" {
  description = "Description for phone number"
  type        = string
  default     = "Main contact center number"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}
