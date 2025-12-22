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

variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime."
  type        = number
  default     = 256
}

variable "architectures" {
  description = "Instruction set architecture for your Lambda function. One of [\"x86_64\", \"arm64\"]."
  type        = list(string)
  default     = ["x86_64"]
}

variable "publish" {
  description = "Whether to publish creation/change as new Function Version. Required for aliases/provisioned concurrency."
  type        = bool
  default     = true
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
