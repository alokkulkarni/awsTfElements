variable "project_name" {
  type = string
}

variable "origin_domain_name" {
  type = string
}

variable "origin_id" {
  type = string
}

variable "logging_bucket_domain_name" {
  type = string
}

variable "web_acl_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
