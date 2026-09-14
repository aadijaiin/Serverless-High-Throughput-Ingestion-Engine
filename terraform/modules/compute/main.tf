# Compute Module: Lambda Functions & SQS Event Source Mapping

data "archive_file" "aggregator_zip" {
  type        = "zip"
  source_dir  = var.aggregator_source_dir
  output_path = "${path.module}/builds/aggregator.zip"
}

data "archive_file" "results_zip" {
  type        = "zip"
  source_dir  = var.results_source_dir
  output_path = "${path.module}/builds/results.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aggregator" {
  name               = "${var.environment}-voting-aggregator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "aggregator_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [var.sqs_queue_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
    resources = [var.dynamodb_table_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.aggregator.arn}:*"]
  }
}

resource "aws_iam_role_policy" "aggregator" {
  name   = "${var.environment}-aggregator-policy"
  role   = aws_iam_role.aggregator.id
  policy = data.aws_iam_policy_document.aggregator_policy.json
}

resource "aws_iam_role" "results" {
  name               = "${var.environment}-voting-results-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "results_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:GetItem"
    ]
    resources = [var.dynamodb_table_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.results.arn}:*"]
  }
}

resource "aws_iam_role_policy" "results" {
  name   = "${var.environment}-results-policy"
  role   = aws_iam_role.results.id
  policy = data.aws_iam_policy_document.results_policy.json
}

resource "aws_cloudwatch_log_group" "aggregator" {
  name              = "/aws/lambda/${var.environment}-voting-aggregator"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "results" {
  name              = "/aws/lambda/${var.environment}-voting-results"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "aggregator" {
  function_name = "${var.environment}-voting-aggregator"
  role          = aws_iam_role.aggregator.arn
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.aggregator_timeout
  memory_size   = var.aggregator_memory_size

  filename         = data.archive_file.aggregator_zip.output_path
  source_code_hash = data.archive_file.aggregator_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      LOG_LEVEL  = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.aggregator]
  tags       = merge(var.tags, { Tier = "Compute" })
}

resource "aws_lambda_function" "results" {
  function_name = "${var.environment}-voting-results"
  role          = aws_iam_role.results.arn
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.results_timeout
  memory_size   = var.results_memory_size

  filename         = data.archive_file.results_zip.output_path
  source_code_hash = data.archive_file.results_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      LOG_LEVEL  = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.results]
  tags       = merge(var.tags, { Tier = "Compute" })
}

resource "aws_lambda_event_source_mapping" "sqs_to_aggregator" {
  event_source_arn                   = var.sqs_queue_arn
  function_name                      = aws_lambda_function.aggregator.arn
  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_batching_window_seconds
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true
}
