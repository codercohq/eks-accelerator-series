provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "eks-accel"
      Env     = "dev"
      Module  = "ingress-iam"
    }
  }
}

# The cert-manager and ExternalDNS IRSA roles. OIDC provider from EP6, issuer
# URL from EP4, hosted zone is your domain's Route 53 zone.
module "ingress_iam" {
  source = "../../modules/ingress-iam"

  cluster_name      = var.cluster_name
  oidc_issuer_url   = var.oidc_issuer_url
  oidc_provider_arn = var.oidc_provider_arn
  hosted_zone_id    = var.hosted_zone_id
}
