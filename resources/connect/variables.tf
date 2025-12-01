variable "instance_alias" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
