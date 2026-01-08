variable "name" {
  description = "Name of the Kinesis Stream"
  type        = string
}

variable "shard_count" {
  description = "Number of shards"
  type        = number
  default     = 1
}

variable "retention_period" {
  description = "Length of time data records are accessible after they are added to the stream"
  type        = number
  default     = 24
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
