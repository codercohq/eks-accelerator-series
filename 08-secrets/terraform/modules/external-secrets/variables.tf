variable "cluster_name" {
  description = "Cluster name, used to name the role."
  type        = string
}

variable "oidc_issuer_url" {
  description = "The cluster OIDC issuer URL, from EP4."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider created in EP6. Reused here, one per cluster."
  type        = string
}

variable "namespace" {
  description = "Namespace the External Secrets Operator runs in."
  type        = string
  default     = "external-secrets"
}

variable "service_account" {
  description = "The operator's controller service account, the one the role trusts."
  type        = string
  default     = "external-secrets"
}

variable "region" {
  description = "Region the secrets live in, used to build the secret ARN."
  type        = string
}

variable "secret_prefix" {
  description = "Secrets Manager name prefix the role may read. Least privilege: only these."
  type        = string
  default     = "eks-accel/dev/"
}

variable "tags" {
  description = "Tags to apply to the role."
  type        = map(string)
  default     = {}
}
