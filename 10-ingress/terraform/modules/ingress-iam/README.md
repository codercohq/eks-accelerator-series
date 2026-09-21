# Module: ingress-iam

The IAM side of the front door. Two IRSA roles, both scoped to one Route 53 hosted zone, both reusing the OIDC provider from EP6.

## What it makes

- `<cluster>-cert-manager`: trusted by the cert-manager service account, allowed to write records into the zone to answer the ACME DNS-01 challenge.
- `<cluster>-external-dns`: trusted by the ExternalDNS service account, allowed to publish and reconcile records in the zone.

## Wiring it up

- Annotate `cert_manager_role_arn` onto the cert-manager service account (Helm value or the Deployment's service account).
- Put `external_dns_role_arn` into `k8s/externaldns-values.yaml` as the serviceAccount role-arn.

Neither controller holds an access key. Each assumes its role through the cluster OIDC provider, the same pattern as EP6 and EP8.
