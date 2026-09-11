variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "prod"
}

variable "table_name" {
  type        = string
  description = "Name of the DynamoDB table"
  default     = ""
}

variable "enable_point_in_time_recovery" {
  type        = bool
  description = "Whether to enable continuous backups via PITR"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "Custom KMS key ARN for DynamoDB encryption"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
