output "api_endpoint" {
  description = "API Gateway HTTP API Root Endpoint"
  value       = module.networking.api_endpoint
}

output "vote_url" {
  description = "Direct Ingestion Endpoint for POST /vote"
  value       = module.networking.vote_endpoint
}

output "results_url" {
  description = "Scoreboard Query Endpoint for GET /results"
  value       = module.networking.results_endpoint
}

output "sqs_queue_url" {
  description = "URL of the SQS Buffer Queue"
  value       = module.messaging.queue_url
}

output "sqs_dlq_url" {
  description = "URL of the SQS Dead-Letter Queue"
  value       = module.messaging.dlq_url
}

output "dynamodb_table_name" {
  description = "DynamoDB On-Demand Votes Table"
  value       = module.storage.table_name
}

output "load_generator_instances" {
  description = "IDs of the Distributed Load Testing EC2 instances"
  value       = module.load_generator.instance_ids
}
