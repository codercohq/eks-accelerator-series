variable "cluster_name" {
  description = "Cluster name, used to name the worker role."
  type        = string
}

variable "queue_name" {
  description = "Name of the main event queue."
  type        = string
  default     = "order-events"
}

variable "oidc_issuer_url" {
  description = "The cluster OIDC issuer URL, from EP4."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider from EP6. One per cluster, reused here."
  type        = string
}

variable "worker_namespace" {
  description = "Namespace the worker runs in."
  type        = string
  default     = "default"
}

variable "worker_service_account" {
  description = "The worker's service account, trusted by its role."
  type        = string
  default     = "worker"
}

variable "max_receive_count" {
  description = "How many times a message is delivered before it moves to the DLQ."
  type        = number
  default     = 5
}

variable "visibility_timeout" {
  description = "Seconds a received message is hidden while the worker handles it."
  type        = number
  default     = 30
}

variable "dlq_alarm_threshold" {
  description = "Raise the alarm once the DLQ holds this many messages."
  type        = number
  default     = 1
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic the DLQ alarm notifies. Empty means no action."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the resources."
  type        = map(string)
  default     = {}
}
