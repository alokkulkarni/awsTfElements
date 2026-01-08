variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "destination_bucket_arn" {
  description = "The ARN of the S3 bucket where logs will be stored"
  type        = string
}

variable "destination_prefix" {
  description = "Prefix for log files in S3"
  type        = string
  default     = "logs/"
}

variable "kms_key_arn" {
    description = "KMS key ARN for S3 encryption (optional)"
    type = string
    default = null
}

variable "enable_processing" {
    description = "Enable Lambda processing for records"
    type = bool
    default = false
}

variable "processing_lambda_arn" {
    description = "Lambda ARN for record processing"
    type = string
    default = ""
}

variable "kinesis_source_arn" {
  description = "The ARN of the source Kinesis Data Stream (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
