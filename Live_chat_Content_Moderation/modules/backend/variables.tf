variable "project_name" {
  type = string
}

variable "dynamodb_tables" {
  description = "Map of DynamoDB tables to access. Key is the logical name (e.g. 'hallucinations'), value is object with name and arn."
  type = map(object({
    name = string
    arn  = string
  }))
  default = {}
}

variable "guardrail_id" {
  description = "The ID/ARN of the Bedrock Guardrail"
  type        = string
  default     = ""
}

variable "guardrail_version" {
  description = "The version of the Bedrock Guardrail"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
