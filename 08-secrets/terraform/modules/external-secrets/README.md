# Module: external-secrets

The IAM side of the External Secrets Operator. One role, trusted by the operator's controller service account through the cluster OIDC provider, allowed to read only the `eks-accel/dev/` secrets in Secrets Manager.

## What it makes

- An IAM role, `<cluster>-external-secrets`, with an IRSA trust policy scoped to one service account.
- A read-only inline policy for `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret`, limited to the `eks-accel/dev/` name prefix.

## What it reuses

The OIDC provider from EP6. There is one per cluster, so this module takes its ARN as an input rather than making a second one.

## Wiring it up

Take `role_arn` from the output and annotate it onto the operator's controller service account, so the pod assumes the role:

```
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: <role_arn>
```

On the SecretStore side there is then no auth block and no keys. The operator uses this role.
