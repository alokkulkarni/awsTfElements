variable "project_name" {
  description = "Project name to be used for naming resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID where ECS tasks will run"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the ECS tasks"
  type        = list(string)
}

variable "container_image" {
  description = "Docker image for the speech gateway"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Memory for the task"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 1
}

variable "target_group_arn" {
  description = "ARN of the NLB target group"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "task_role_policy_json" {
  description = "JSON policy for the ECS Task Role (permissions for the app)"
  type        = string
  default     = ""
}
