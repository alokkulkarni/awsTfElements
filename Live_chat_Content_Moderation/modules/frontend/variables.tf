variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "waf_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with CloudFront"
  type        = string
}

variable "logs_bucket_id" {
  description = "ID of the centralized logs bucket"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
