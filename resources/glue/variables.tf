variable "database_name" {
  description = "Name of the Glue Catalog Database"
  type        = string
}

variable "tables" {
  description = "List of table definitions"
  type = list(object({
    name = string
    location = string
    columns = list(object({
        name = string
        type = string
    }))
  }))
  default = []
}
