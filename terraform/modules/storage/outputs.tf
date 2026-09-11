output "table_name" {
  description = "Name of the DynamoDB votes table"
  value       = aws_dynamodb_table.votes.name
}

output "table_arn" {
  description = "ARN of the DynamoDB votes table"
  value       = aws_dynamodb_table.votes.arn
}

output "table_id" {
  description = "ID of the DynamoDB votes table"
  value       = aws_dynamodb_table.votes.id
}
