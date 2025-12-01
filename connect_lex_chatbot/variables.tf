variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "aws-tf-elements-connect"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}
