variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "aws-tf-elements"
}

variable "environment" {
  description = "The environment (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Project     = "aws-tf-elements"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
