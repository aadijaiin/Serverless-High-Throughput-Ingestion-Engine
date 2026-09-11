variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "prod"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS buffer queue"
}

variable "sqs_queue_url" {
  type        = string
  description = "URL of the SQS buffer queue"
}

variable "results_lambda_name" {
  type        = string
  description = "Function name of the results Lambda"
}

variable "results_lambda_invoke_arn" {
  type        = string
  description = "Invocation ARN of the results Lambda"
}

variable "log_retention_days" {
  type        = number
  description = "Retention period for API Gateway access logs"
  default     = 14
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
