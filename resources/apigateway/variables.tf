variable "name" {
  type = string
}

variable "protocol_type" {
  type = string
}

variable "stage_name" {
  type = string
}

variable "auto_deploy" {
  type    = bool
  default = true
}

variable "log_destination_arn" {
  type = string
}

variable "log_format" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
