#!/usr/bin/env bash
# Run this BEFORE the session. It does the slow parts (cluster, image pulls,
# Traefik, cert-manager) so on stage you only apply the issuer, the app and the
# Ingress, then curl HTTPS. Safe to run twice.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ingress-lab
CM_VERSION=v1.16.2

echo "==> cluster"
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> pre-load images"
for img in hashicorp/http-echo:1.0; do
  docker pull -q "$img" >/dev/null 2>&1 || true
  kind load docker-image "$img" --name "$CLUSTER" >/dev/null 2>&1 || true
done

echo "==> Traefik"
helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update traefik >/dev/null
helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace -f traefik-values.yaml --wait --timeout 300s >/dev/null
kubectl -n traefik rollout status deploy/traefik --timeout=180s

echo "==> cert-manager"
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CM_VERSION}/cert-manager.yaml" >/dev/null
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s

echo
echo "READY. On stage, run:"
echo "  kubectl apply -f manifests/issuer.yaml"
echo "  kubectl apply -f manifests/app.yaml -f manifests/ingress.yaml"
echo "  curl -skL --resolve shop.localhost:80:127.0.0.1 --resolve shop.localhost:443:127.0.0.1 http://shop.localhost/"
