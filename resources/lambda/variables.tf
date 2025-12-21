variable "filename" {
  type = string
}

variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "handler" {
  type = string
}

variable "runtime" {
  type = string
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "timeout" {
  type    = number
  default = 3
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the Lambda deployment package"
  type        = string
  default     = null
}
