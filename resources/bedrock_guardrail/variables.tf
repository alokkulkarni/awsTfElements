variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = "Bedrock Guardrail"
}

variable "blocked_input_messaging" {
  type    = string
  default = "I cannot process this input due to safety guidelines."
}

variable "blocked_outputs_messaging" {
  type    = string
  default = "I cannot generate this response due to safety guidelines."
}

variable "tags" {
  type    = map(string)
  default = {}
}
