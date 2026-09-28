output "queue_url" {
  description = "Set as QUEUE_URL on the worker."
  value       = module.events.queue_url
}

output "dlq_url" {
  description = "The dead-letter queue URL."
  value       = module.events.dlq_url
}

output "worker_role_arn" {
  description = "Annotate onto the worker service account."
  value       = module.events.worker_role_arn
}
