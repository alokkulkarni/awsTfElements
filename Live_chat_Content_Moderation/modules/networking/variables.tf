variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "logs_bucket_arn" {
  description = "ARN of the centralized logs bucket"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
