variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "prod"
}

variable "instance_count" {
  type        = number
  description = "Number of distributed EC2 load testing nodes (6 to 7 t3.small instances)"
  default     = 6
}

variable "instance_type" {
  type        = string
  description = "EC2 instance size for load generator nodes"
  default     = "t3.small"
}

variable "ami_id" {
  type        = string
  description = "Optional custom AMI ID"
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where load nodes should reside"
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs across multiple AZs for load node placement"
  default     = []
}

variable "vote_endpoint" {
  type        = string
  description = "API Gateway POST /vote endpoint URL for load testing"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
