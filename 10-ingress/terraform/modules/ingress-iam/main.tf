###############################################################################
# Two IRSA roles for the front door. cert-manager needs to write Route 53
# records to answer the ACME DNS-01 challenge. ExternalDNS needs to write Route
# 53 records to publish hostnames. Both are scoped to the one hosted zone, and
# both reuse the OIDC provider from EP6.
###############################################################################

locals {
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
  zone_arn  = "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
}

# --- cert-manager role ------------------------------------------------------

data "aws_iam_policy_document" "cert_manager_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.cert_manager_namespace}:${var.cert_manager_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cert_manager_route53" {
  # answer the DNS-01 challenge: write TXT records into the zone
  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [local.zone_arn]
  }
  # cert-manager looks the zone up by name first
  statement {
    effect    = "Allow"
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "cert_manager" {
  name               = "${var.cluster_name}-cert-manager"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "cert_manager" {
  name   = "route53-dns01"
  role   = aws_iam_role.cert_manager.id
  policy = data.aws_iam_policy_document.cert_manager_route53.json
}

# --- ExternalDNS role -------------------------------------------------------

data "aws_iam_policy_document" "external_dns_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.external_dns_namespace}:${var.external_dns_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "external_dns_route53" {
  # publish and update records in the zone
  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [local.zone_arn]
  }
  # list zones and records so it can reconcile
  statement {
    effect    = "Allow"
    actions   = ["route53:ListResourceRecordSets", "route53:ListHostedZones"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "external_dns" {
  name   = "route53-sync"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.external_dns_route53.json
}
