provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "eks-accel"
      Env     = "dev"
      Module  = "events"
    }
  }
}

# The queue, the DLQ, the worker role and the DLQ alarm. OIDC provider from EP6,
# issuer URL from EP4.
module "events" {
  source = "../../modules/events"

  cluster_name      = var.cluster_name
  oidc_issuer_url   = var.oidc_issuer_url
  oidc_provider_arn = var.oidc_provider_arn
}
