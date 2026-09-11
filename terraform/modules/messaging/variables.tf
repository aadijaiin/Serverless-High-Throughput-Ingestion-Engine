variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "prod"
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "Visibility timeout for the SQS buffer"
  default     = 60
}

variable "message_retention_seconds" {
  type        = number
  description = "Buffer message retention period in seconds"
  default     = 86400
}

variable "dlq_message_retention_seconds" {
  type        = number
  description = "DLQ retention period in seconds"
  default     = 1209600
}

variable "receive_wait_time_seconds" {
  type        = number
  description = "SQS long polling wait time in seconds"
  default     = 20
}

variable "max_receive_count" {
  type        = number
  description = "Number of times a message is delivered before redriving to DLQ"
  default     = 5
}

variable "kms_master_key_id" {
  type        = string
  description = "KMS key ID or alias for encryption"
  default     = "alias/aws/sqs"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
