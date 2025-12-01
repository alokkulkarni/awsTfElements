variable "name" {
  type = string
}

variable "authentication_type" {
  type = string
}

variable "xray_enabled" {
  type    = bool
  default = true
}

variable "log_cloudwatch_logs_role_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
