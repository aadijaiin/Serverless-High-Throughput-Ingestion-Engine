variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "prod"
}

variable "lambda_runtime" {
  type        = string
  description = "Runtime for Lambda functions"
  default     = "python3.11"
}

variable "aggregator_source_dir" {
  type        = string
  description = "Filesystem path to aggregator source directory"
}

variable "results_source_dir" {
  type        = string
  description = "Filesystem path to results source directory"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB table"
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the DynamoDB table"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS buffer queue"
}

variable "sqs_batch_size" {
  type        = number
  description = "Maximum batch size for SQS event source mapping"
  default     = 100
}

variable "sqs_batching_window_seconds" {
  type        = number
  description = "Maximum window in seconds before invoking Lambda"
  default     = 5
}

variable "aggregator_timeout" {
  type        = number
  description = "Aggregator Lambda timeout in seconds"
  default     = 15
}

variable "aggregator_memory_size" {
  type        = number
  description = "Aggregator Lambda memory in MB"
  default     = 256
}

variable "results_timeout" {
  type        = number
  description = "Results Lambda timeout in seconds"
  default     = 10
}

variable "results_memory_size" {
  type        = number
  description = "Results Lambda memory in MB"
  default     = 256
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch logs retention period in days"
  default     = 14
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
