output "role_arn" {
  description = "ARN of the operator's IAM role. Annotate it onto the controller service account (Helm: serviceAccount.annotations)."
  value       = aws_iam_role.this.arn
}
