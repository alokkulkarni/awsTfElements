variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "connect-nova-sonic-hybrid"
}

variable "connect_queues" {
  description = "Map of queues to create in Amazon Connect. Key is the queue name, value is the configuration."
  type = map(object({
    description = string
  }))
  default = {
    "Sales" = {
      description = "Sales Department Queue"
    }
    "Support" = {
      description = "Customer Support Queue"
    }
    "Billing" = {
      description = "Billing & Payments Queue"
    }
  }
}

variable "contact_flow_template_file" {
  description = "Path to the Contact Flow JSON template file"
  type        = string
  default     = "contact_flows/nova_sonic_ivr.json.tftpl"
}

variable "environment" {
  description = "Deployment Environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
