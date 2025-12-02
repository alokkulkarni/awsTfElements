variable "name" {
  type = string
}

variable "hash_key" {
  type = string
}

variable "range_key" {
  description = "The attribute to use as the range (sort) key"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
