variable "bot_name" {
  type = string
}

variable "fulfillment_lambda_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
