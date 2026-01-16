variable "connect_instance_id" {
  description = "Connect instance ID"
  type        = string
}

variable "bot_aliases" {
  description = "Map of bot aliases to associate with Connect"
  type = map(object({
    bot_id       = string
    bot_alias_id = string
    bot_name     = string
  }))
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
