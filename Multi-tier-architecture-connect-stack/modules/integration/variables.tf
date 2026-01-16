variable "connect_instance_id" {
  description = "Connect instance ID"
  type        = string
}

variable "bot_versions" {
  description = "Map of bot versions (prod and test) to associate with Connect"
  type = map(object({
    bot_id      = string
    bot_version = string
  }))
  default = {}
}

variable "lambda_functions" {
  description = "Map of Lambda functions to associate with Connect"
  type = map(object({
    arn           = string
    function_name = string
  }))
}

variable "bot_dependencies" {
  description = "Dependencies to wait for before creating bot associations"
  type        = any
  default     = []
}
