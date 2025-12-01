variable "bucket_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_versioning" {
  type    = bool
  default = false
}

variable "logging_target_bucket" {
  type    = string
  default = null
}

variable "logging_target_prefix" {
  type    = string
  default = null
}

variable "enable_ownership_controls" {
  type    = bool
  default = false
}

variable "enable_acl" {
  type    = bool
  default = false
}

variable "acl" {
  type    = string
  default = "private"
}

variable "enable_lifecycle" {
  type    = bool
  default = false
}

variable "enable_logging" {
  type    = bool
  default = false
}
