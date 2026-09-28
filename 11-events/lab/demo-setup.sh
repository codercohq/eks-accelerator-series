#!/usr/bin/env bash
# Run this BEFORE the session. It builds the cluster, starts LocalStack, creates
# the queue and the dead-letter queue with a redrive policy, and pre-loads the
# images, so on stage you only deploy the worker and send messages.
# Safe to run twice.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=events-lab
DLQ_ARN="arn:aws:sqs:us-east-1:000000000000:order-events-dlq"
MAIN_URL="http://localhost:4566/000000000000/order-events"

echo "==> cluster"
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> pre-load images"
for img in localstack/localstack:3 amazon/aws-cli:2.15.30; do
  docker pull -q "$img" >/dev/null 2>&1 || true
  kind load docker-image "$img" --name "$CLUSTER" >/dev/null 2>&1 || true
done

echo "==> LocalStack"
kubectl apply -f localstack.yaml >/dev/null
kubectl rollout status deploy/localstack --timeout=300s

echo "==> queues"
# the dead-letter queue first, so we have its ARN for the redrive policy
kubectl exec deploy/localstack -- awslocal sqs create-queue --queue-name order-events-dlq >/dev/null 2>&1 || true
kubectl exec deploy/localstack -- awslocal sqs create-queue --queue-name order-events >/dev/null 2>&1 || true
# redrive policy: after 3 failed receives the message moves to the DLQ.
# short visibility timeout so a failed message comes back quickly in the demo.
kubectl exec deploy/localstack -- awslocal sqs set-queue-attributes --queue-url "$MAIN_URL" \
  --attributes "{\"VisibilityTimeout\":\"5\",\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" >/dev/null

echo
echo "READY. On stage, run:"
echo "  kubectl apply -f worker.yaml"
echo "  make send        # a good message, worker processes it"
echo "  make bad         # a poison message, watch it land in the DLQ"
echo "  make dlq         # read the dead message"
