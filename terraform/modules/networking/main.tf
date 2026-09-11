# Networking Module: API Gateway HTTP API with Direct SQS & Lambda Proxy Integrations

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.environment}-voting-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Requested-With"]
    max_age       = 3600
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-voting-api"
    Tier = "Networking"
  })
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/apigateway/${var.environment}-voting-api"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      latency        = "$context.responseLatency"
    })
  }

  tags = var.tags
}

data "aws_iam_policy_document" "api_gateway_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_gateway_sqs" {
  name               = "${var.environment}-apigateway-sqs-role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "api_gateway_sqs_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [var.sqs_queue_arn]
  }
}

resource "aws_iam_role_policy" "api_gateway_sqs" {
  name   = "${var.environment}-apigateway-sqs-policy"
  role   = aws_iam_role.api_gateway_sqs.id
  policy = data.aws_iam_policy_document.api_gateway_sqs_policy.json
}

# Direct Computeless SQS Integration
resource "aws_apigatewayv2_integration" "sqs_vote" {
  api_id              = aws_apigatewayv2_api.http_api.id
  credentials_arn     = aws_iam_role.api_gateway_sqs.arn
  integration_type    = "AWS_PROXY"
  integration_subtype = "SQS-SendMessage"

  request_parameters = {
    QueueUrl    = var.sqs_queue_url
    MessageBody = "$request.body"
  }
}

resource "aws_apigatewayv2_route" "vote" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /vote"
  target    = "integrations/${aws_apigatewayv2_integration.sqs_vote.id}"
}

resource "aws_apigatewayv2_integration" "results" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.results_lambda_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "results" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /results"
  target    = "integrations/${aws_apigatewayv2_integration.results.id}"
}

resource "aws_lambda_permission" "api_gateway_results" {
  statement_id  = "AllowAPIGatewayInvokeResults"
  action        = "lambda:InvokeFunction"
  function_name = var.results_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
