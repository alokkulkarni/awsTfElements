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

variable "agent_name" {
  description = "Name for the Bedrock agent"
  type        = string
}

variable "agent_description" {
  description = "Description for the Bedrock agent"
  type        = string
}

variable "agent_role_arn" {
  description = "ARN of the IAM role for the Bedrock agent"
  type        = string
}

variable "foundation_model" {
  description = "Bedrock foundation model ID"
  type        = string
}

variable "agent_instruction" {
  description = "Instructions for the Bedrock agent"
  type        = string
}

variable "guardrail_name" {
  description = "Name for the Bedrock guardrail"
  type        = string
}

variable "guardrail_description" {
  description = "Description for the Bedrock guardrail"
  type        = string
}

variable "blocked_input_message" {
  description = "Message to display when input is blocked"
  type        = string
}

variable "blocked_output_message" {
  description = "Message to display when output is blocked"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}
