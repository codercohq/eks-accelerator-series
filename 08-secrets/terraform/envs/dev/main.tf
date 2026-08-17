provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "eks-accel"
      Env     = "dev"
      Module  = "external-secrets"
    }
  }
}

# The operator's IAM role. OIDC provider comes from EP6, issuer URL from EP4.
module "external_secrets" {
  source = "../../modules/external-secrets"

  cluster_name      = var.cluster_name
  region            = var.region
  oidc_issuer_url   = var.oidc_issuer_url
  oidc_provider_arn = var.oidc_provider_arn
}
