variable "name" {
  type = string
}

variable "fifo_queue" {
  type    = bool
  default = false
}

variable "content_based_deduplication" {
  type    = bool
  default = false
}

variable "redrive_policy" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
