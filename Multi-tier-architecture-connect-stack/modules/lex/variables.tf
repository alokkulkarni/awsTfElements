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

variable "lex_role_arn" {
  description = "ARN of the Lex IAM role"
  type        = string
}

variable "lex_bots" {
  description = "Map of Lex bots to create"
  type = map(object({
    description      = string
    bot_type         = string
    idle_session_ttl = number
    locale           = string
    voice_id         = string
  }))
}

variable "lambda_functions" {
  description = "Map of Lambda functions for bot fulfillment"
  type = map(object({
    arn           = string
    function_name = string
  }))
}
