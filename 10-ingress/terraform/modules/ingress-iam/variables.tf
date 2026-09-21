variable "cluster_name" {
  description = "Cluster name, used to name the roles."
  type        = string
}

variable "oidc_issuer_url" {
  description = "The cluster OIDC issuer URL, from EP4."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider from EP6. One per cluster, reused here."
  type        = string
}

variable "hosted_zone_id" {
  description = "The Route 53 hosted zone ID both roles are scoped to."
  type        = string
}

variable "cert_manager_namespace" {
  description = "Namespace cert-manager runs in."
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_service_account" {
  description = "cert-manager's service account, trusted by its role."
  type        = string
  default     = "cert-manager"
}

variable "external_dns_namespace" {
  description = "Namespace ExternalDNS runs in."
  type        = string
  default     = "external-dns"
}

variable "external_dns_service_account" {
  description = "ExternalDNS's service account, trusted by its role."
  type        = string
  default     = "external-dns"
}

variable "tags" {
  description = "Tags to apply to the roles."
  type        = map(string)
  default     = {}
}
