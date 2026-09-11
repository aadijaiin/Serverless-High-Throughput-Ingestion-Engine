output "aggregator_lambda_arn" {
  description = "ARN of the aggregator Lambda function"
  value       = aws_lambda_function.aggregator.arn
}

output "aggregator_lambda_name" {
  description = "Name of the aggregator Lambda function"
  value       = aws_lambda_function.aggregator.function_name
}

output "results_lambda_arn" {
  description = "ARN of the results Lambda function"
  value       = aws_lambda_function.results.arn
}

output "results_lambda_name" {
  description = "Name of the results Lambda function"
  value       = aws_lambda_function.results.function_name
}

output "results_lambda_invoke_arn" {
  description = "Invocation ARN of the results Lambda function"
  value       = aws_lambda_function.results.invoke_arn
}
