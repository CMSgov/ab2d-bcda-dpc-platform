data "aws_caller_identity" "current" {}

resource "aws_kms_key" "queue" {
  description         = "For ${var.name} queue"
  enable_key_rotation = true
}

data "aws_iam_policy_document" "kms_for_queue" {
  statement {
    sid = "Enable IAM User Permissions"

    actions = ["kms:*"]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  dynamic "statement" {
    for_each = var.sns_topic_arn != "None" ? [1] : []
    content {
      sid = "Allow SNS topic to send message to encrypted SQS queue"

      actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]

      principals {
        type        = "Service"
        identifiers = ["sns.amazonaws.com"]
      }

      resources = [aws_kms_key.queue.arn]

      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [var.sns_topic_arn]
      }
    }
  }
}

resource "aws_kms_key_policy" "queue" {
  key_id = aws_kms_key.queue.id
  policy = data.aws_iam_policy_document.kms_for_queue.json
}

resource "aws_kms_alias" "queue" {
  name          = "alias/${var.name}-queue"
  target_key_id = aws_kms_key.queue.key_id
}

resource "aws_sqs_queue" "dead_letter" {
  name              = "${var.name}-dead-letter"
  kms_master_key_id = aws_kms_alias.queue.name
}

resource "aws_sqs_queue" "this" {
  name              = var.name
  kms_master_key_id = aws_kms_alias.queue.name

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "this" {
  queue_url = aws_sqs_queue.dead_letter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

data "aws_iam_policy_document" "sns_send_message" {
  count = var.sns_topic_arn != "None" ? 1 : 0

  statement {
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [aws_sqs_queue.this.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.sns_topic_arn]
    }
  }
}

resource "aws_sqs_queue_policy" "sns_send_message" {
  count = var.sns_topic_arn != "None" ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.sns_send_message[0].json
}

resource "aws_sns_topic_subscription" "this" {
  count = var.sns_topic_arn != "None" ? 1 : 0

  endpoint  = aws_sqs_queue.this.arn
  protocol  = "sqs"
  topic_arn = var.sns_topic_arn
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn = aws_sqs_queue.this.arn
  function_name    = var.function_name
}
