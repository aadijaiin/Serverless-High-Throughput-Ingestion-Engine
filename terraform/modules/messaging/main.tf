# Messaging Module: SQS Standard Buffer Queue and Dead-Letter Queue (DLQ)

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.environment}-voting-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds

  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.tags, {
    Name = "${var.environment}-voting-dlq"
    Tier = "Messaging"
  })
}

resource "aws_sqs_queue" "buffer" {
  name                       = "${var.environment}-voting-buffer"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.tags, {
    Name = "${var.environment}-voting-buffer"
    Tier = "Messaging"
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq_allow" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.buffer.arn]
  })
}
