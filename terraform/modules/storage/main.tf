# Storage Module: Amazon DynamoDB Table (On-Demand Mode)

resource "aws_dynamodb_table" "votes" {
  name         = var.table_name != "" ? var.table_name : "${var.environment}-resilient-votes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "team_id"

  attribute {
    name = "team_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = merge(var.tags, {
    Name = var.table_name != "" ? var.table_name : "${var.environment}-resilient-votes"
    Tier = "Storage"
  })
}
