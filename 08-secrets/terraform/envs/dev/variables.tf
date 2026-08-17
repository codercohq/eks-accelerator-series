variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-2"
}

variable "cluster_name" {
  description = "Cluster name, from EP4."
  type        = string
  default     = "eks-accel-dev"
}

variable "oidc_issuer_url" {
  description = "Cluster OIDC issuer URL. From EP4: terraform output oidc_issuer_url."
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN. From EP6: terraform output oidc_provider_arn."
  type        = string
}
