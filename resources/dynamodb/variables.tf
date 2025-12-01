variable "name" {
  type = string
}

variable "hash_key" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
