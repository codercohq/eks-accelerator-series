###############################################################################
# The External Secrets Operator's IAM role, wired with IRSA. The OIDC provider
# already exists from EP6, so we reuse it here rather than making another.
# Trusted by exactly the operator's controller service account, and allowed to
# read only the eks-accel/dev/ secrets. Nothing else, nowhere else.
###############################################################################

data "aws_caller_identity" "current" {}

locals {
  # The issuer without the scheme, used as the trust condition key prefix.
  oidc_host = replace(var.oidc_issuer_url, "https://", "")

  # Secrets Manager appends a random 6-char suffix to every ARN, so the
  # trailing * matches eks-accel/dev/postgres-AbCdEf and friends.
  secret_arn = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.secret_prefix}*"
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Only the operator's service account may assume this role.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    # The token must be meant for STS.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Read-only, and only on the eks-accel/dev/ secrets. GetSecretValue fetches the
# value, DescribeSecret lets the operator see the current version to sync.
data "aws_iam_policy_document" "read_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [local.secret_arn]
  }
}

resource "aws_iam_role_policy" "read_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.read_secrets.json
}
