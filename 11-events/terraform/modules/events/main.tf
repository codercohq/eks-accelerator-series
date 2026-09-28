###############################################################################
# The event bus. A main SQS queue, a dead-letter queue behind it, an IRSA role
# for the worker scoped to just this queue, and a CloudWatch alarm that fires
# when messages land in the DLQ.
###############################################################################

locals {
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
}

# The dead-letter queue. Messages the worker cannot handle end up here instead
# of blocking the main queue.
resource "aws_sqs_queue" "dlq" {
  name = "${var.queue_name}-dlq"
  tags = var.tags
}

# The main queue. Its redrive policy points at the DLQ, so a message that has
# been received more than max_receive_count times moves there on its own.
resource "aws_sqs_queue" "main" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = var.tags
}

# --- the worker's IRSA role -------------------------------------------------

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.worker_namespace}:${var.worker_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Only what a consumer needs, and only on this one queue. No sqs:* anywhere.
data "aws_iam_policy_document" "consume" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.main.arn]
  }
}

resource "aws_iam_role" "worker" {
  name               = "${var.cluster_name}-worker"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "consume" {
  name   = "consume-order-events"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.consume.json
}

# --- DLQ alarm --------------------------------------------------------------

# Nobody watches a DLQ until something is in it, so raise an alarm the moment it
# holds a message.
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.queue_name}-dlq-not-empty"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.dlq_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
  tags          = var.tags
}
