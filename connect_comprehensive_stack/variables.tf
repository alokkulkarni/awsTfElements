variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project = "ConnectComprehensive"
    ManagedBy = "Terraform"
  }
}
