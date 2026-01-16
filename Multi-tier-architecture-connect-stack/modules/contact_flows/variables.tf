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

variable "connect_instance_id" {
  description = "Connect instance ID"
  type        = string
}

variable "deploy_flows" {
  description = "Whether to deploy contact flows"
  type        = bool
  default     = false
}

variable "contact_flows" {
  description = "Map of contact flows to create"
  type = map(object({
    description = string
    type        = string
    filename    = string
  }))
  default = {}
}
