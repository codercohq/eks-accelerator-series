output "role_arn" {
  description = "Annotate this onto the operator's controller service account."
  value       = module.external_secrets.role_arn
}
