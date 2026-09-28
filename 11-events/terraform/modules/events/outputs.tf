output "queue_url" {
  description = "URL of the main queue. Set it as QUEUE_URL on the worker."
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "ARN of the main queue."
  value       = aws_sqs_queue.main.arn
}

output "dlq_url" {
  description = "URL of the dead-letter queue."
  value       = aws_sqs_queue.dlq.url
}

output "worker_role_arn" {
  description = "Annotate this onto the worker service account."
  value       = aws_iam_role.worker.arn
}
