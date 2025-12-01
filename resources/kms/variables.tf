variable "description" {
  type = string
}

variable "policy" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
