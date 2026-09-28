# Module: events

The event bus. A main SQS queue, a dead-letter queue, the worker's IRSA role and a CloudWatch alarm on the DLQ.

## What it makes

- `order-events`: the main queue, with a redrive policy that moves a message to the DLQ after `max_receive_count` failed receives.
- `order-events-dlq`: the dead-letter queue.
- `<cluster>-worker`: an IRSA role trusted by the worker service account, allowed to receive and delete on the main queue only. No `sqs:*`.
- A CloudWatch alarm that fires when the DLQ holds a message.

## Wiring it up

- Annotate `worker_role_arn` onto the worker service account.
- Set `queue_url` as `QUEUE_URL` on the worker.
- The producers (order-service and friends) need their own role with `sqs:SendMessage` on the queue. Keep them separate from the worker, so each service holds only what it uses.
