variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "lambda_functions" {
  description = "Map of Lambda functions to create"
  type = map(object({
    description      = string
    handler          = string
    runtime          = optional(string)
    timeout          = optional(number)
    memory_size      = optional(number)
    environment_vars = optional(map(string), {})
  }))
}

variable "default_runtime" {
  description = "Default Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "default_timeout" {
  description = "Default Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "default_memory_size" {
  description = "Default Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}
