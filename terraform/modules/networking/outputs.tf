output "api_id" {
  description = "ID of the API Gateway HTTP API"
  value       = aws_apigatewayv2_api.http_api.id
}

output "api_endpoint" {
  description = "Base URL of the API Gateway HTTP API"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "execution_arn" {
  description = "Execution ARN of the API Gateway HTTP API"
  value       = aws_apigatewayv2_api.http_api.execution_arn
}

output "vote_endpoint" {
  description = "Direct URL for POST /vote endpoint"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/vote"
}

output "results_endpoint" {
  description = "Direct URL for GET /results endpoint"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/results"
}
