#!/usr/bin/env bash
# Run this BEFORE the session. It builds the cluster, installs metrics-server
# (patched for Kind's self-signed kubelet certs) and pre-loads the images, so on
# stage you only apply the Deployment and the HPA and drive load. Safe to run twice.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=workloads-lab

echo "==> cluster"
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

echo "==> pre-load images"
for img in registry.k8s.io/hpa-example busybox:1.36; do
  docker pull -q "$img" >/dev/null 2>&1 || true
  kind load docker-image "$img" --name "$CLUSTER" >/dev/null 2>&1 || true
done

echo "==> metrics-server (with the Kind TLS flag)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null
# Kind's kubelet uses a self-signed cert, so metrics-server needs to skip verifying it.
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1 || true
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

echo
echo "READY. On stage, run:"
echo "  kubectl apply -f manifests/api-gateway.yaml -f manifests/hpa.yaml"
echo "  kubectl get hpa api-gateway -w"
echo "  kubectl apply -f manifests/loadgen.yaml     # watch it scale up"
