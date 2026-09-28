# EP11 manifests

The real-AWS worker. It consumes the SQS queue from the `events` terraform module through its own IRSA role.

## Prerequisites

- The `events` module applied, so the queue, the DLQ, the worker role and the DLQ alarm exist.
- The worker image built and pushed (EP2 covered the build).

## Wire it up

Fill in the three placeholders from the terraform outputs, then apply:

```bash
cd 11-events/terraform/envs/dev
terraform output worker_role_arn      # -> the service account annotation
terraform output queue_url            # -> QUEUE_URL

kubectl apply -f k8s/worker.yaml
kubectl rollout status deploy/worker
```

## The point

The worker reaches SQS through its IRSA role, scoped to receive and delete on the one queue. No keys anywhere. It has no way to reach another queue. The producers (order-service and the rest) get their own role with `sqs:SendMessage`, kept separate so each service holds only what it uses.

For a hands-on version with no AWS account, see [`../lab/`](../lab/README.md).
