variable "instance_alias" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "contact_flow_logs_enabled" {
  type    = bool
  default = true
}

variable "contact_lens_enabled" {
  type    = bool
  default = true
}
