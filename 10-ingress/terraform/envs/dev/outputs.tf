output "cert_manager_role_arn" {
  description = "Annotate onto the cert-manager service account."
  value       = module.ingress_iam.cert_manager_role_arn
}

output "external_dns_role_arn" {
  description = "Put into externaldns-values.yaml as the serviceAccount role-arn."
  value       = module.ingress_iam.external_dns_role_arn
}
