variable "aws_region" {
  type        = string
  description = "Target AWS Region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment identifier"
  default     = "prod"
}

variable "table_name" {
  type        = string
  description = "Override table name for DynamoDB"
  default     = "resilient_votes"
}

variable "sqs_batch_size" {
  type        = number
  description = "Event source mapping batch size (10 - 100)"
  default     = 100
}

variable "sqs_batching_window_seconds" {
  type        = number
  description = "Maximum batching window in seconds before invoking aggregator"
  default     = 5
}

variable "load_generator_count" {
  type        = number
  description = "Number of EC2 instances in the distributed load generator fleet"
  default     = 6
}

variable "tags" {
  type        = map(string)
  description = "Global tags applied to all provisioned resources"
  default = {
    Project     = "ResilientVote"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
