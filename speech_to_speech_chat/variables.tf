variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "aws-tf-elements"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "container_image" {
  description = "Docker image for the speech gateway"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:latest" # Placeholder
}
