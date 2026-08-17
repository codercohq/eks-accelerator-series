#!/usr/bin/env bash
# Run this BEFORE the session. It does the slow parts (cluster, image pulls,
# Helm install, LocalStack) so that on stage you only run the teaching steps:
# apply the SecretStore and ExternalSecret, show the sync, then rotate.
#
# It is safe to run twice. Each step either skips or refreshes.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=secrets-lab

echo "==> cluster"
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> pre-load images into the cluster (so nothing stalls on stage)"
for img in localstack/localstack:3 postgres:18 busybox:1.36; do
  docker pull -q "$img" >/dev/null 2>&1 || true
  kind load docker-image "$img" --name "$CLUSTER" >/dev/null 2>&1 || true
done

echo "==> LocalStack"
kubectl apply -f localstack.yaml >/dev/null
kubectl rollout status deploy/localstack --timeout=300s

echo "==> seed the source secret (idempotent)"
SECRET='{"username":"app","dbname":"app","password":"s3cr3t-from-localstack"}'
kubectl exec deploy/localstack -- awslocal secretsmanager create-secret \
  --name eks-accel/dev/postgres --secret-string "$SECRET" >/dev/null 2>&1 \
  || kubectl exec deploy/localstack -- awslocal secretsmanager put-secret-value \
       --secret-id eks-accel/dev/postgres --secret-string "$SECRET" >/dev/null

echo "==> External Secrets Operator"
helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace -f eso-values.yaml --wait --timeout 300s >/dev/null
# the validating webhook needs to be up before any SecretStore is accepted
kubectl -n external-secrets rollout status deploy/external-secrets-webhook --timeout=120s

echo
echo "READY. On stage, run:"
echo "  kubectl apply -f manifests/secretstore.yaml -f manifests/externalsecret.yaml"
echo "  kubectl get externalsecret postgres          # SecretSynced"
echo "  kubectl get secret postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d ; echo"
echo "  kubectl apply -f manifests/postgres.yaml"
