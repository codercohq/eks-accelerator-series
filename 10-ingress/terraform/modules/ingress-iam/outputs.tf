output "cert_manager_role_arn" {
  description = "Annotate this onto the cert-manager service account."
  value       = aws_iam_role.cert_manager.arn
}

output "external_dns_role_arn" {
  description = "Set this as the serviceAccount role-arn in externaldns-values.yaml."
  value       = aws_iam_role.external_dns.arn
}
