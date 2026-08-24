#!/usr/bin/env bash
# Run this BEFORE the session. It does the slow parts (cluster, image pulls,
# Traefik install) so that on stage you only apply the apps and the Ingress,
# then curl. Safe to run twice.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ingress-lab

echo "==> cluster"
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> pre-load images (so nothing stalls on stage)"
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

echo
echo "READY. On stage, run:"
echo "  kubectl apply -f manifests/apps.yaml -f manifests/ingress.yaml"
echo "  curl -H 'Host: shop.localhost'  http://localhost/"
echo "  curl -H 'Host: admin.localhost' http://localhost/"
