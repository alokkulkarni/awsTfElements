variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "scope" {
  type = string
}

variable "log_destination_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
