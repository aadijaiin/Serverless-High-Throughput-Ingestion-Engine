output "queue_id" {
  description = "ID of the SQS buffer queue"
  value       = aws_sqs_queue.buffer.id
}

output "queue_url" {
  description = "URL of the SQS buffer queue"
  value       = aws_sqs_queue.buffer.url
}

output "queue_arn" {
  description = "ARN of the SQS buffer queue"
  value       = aws_sqs_queue.buffer.arn
}

output "queue_name" {
  description = "Name of the SQS buffer queue"
  value       = aws_sqs_queue.buffer.name
}

output "dlq_id" {
  description = "ID of the SQS Dead-Letter Queue"
  value       = aws_sqs_queue.dlq.id
}

output "dlq_url" {
  description = "URL of the SQS Dead-Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN of the SQS Dead-Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}
