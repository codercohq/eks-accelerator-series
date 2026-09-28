# Lab: the event bus on a local Kind cluster

You can run the whole queue story on your laptop. LocalStack plays the part of AWS SQS, a worker pulls messages off a queue, then a poison message ends up in the dead-letter queue on its own. It is the same setup you run on EKS, with LocalStack swapped in for real SQS.

## What you will see

- A worker long-polling a queue and processing messages.
- A good message handled and removed from the queue.
- A poison message retried a few times, then moved to the dead-letter queue.
- The dead message sitting in the DLQ, ready to inspect.

## Prerequisites

```bash
docker --version     # OrbStack or Docker Desktop
kind --version
kubectl version --client
```

## Running it live

For teaching, do the slow parts before the room joins with `./demo-setup.sh` (cluster, LocalStack, the two queues). Then on stage you deploy the worker and send messages. `./demo-teardown.sh` deletes the cluster. There is a `Makefile` too, see the end.

## 1. Cluster, LocalStack and the queues

```bash
cd 11-events/lab
kind create cluster --config kind-config.yaml
kubectl apply -f localstack.yaml
kubectl rollout status deploy/localstack
```

Create the dead-letter queue first, then the main queue, then wire them together:

```bash
DLQ_ARN=arn:aws:sqs:us-east-1:000000000000:order-events-dlq
MAIN=http://localhost:4566/000000000000/order-events

kubectl exec deploy/localstack -- awslocal sqs create-queue --queue-name order-events-dlq
kubectl exec deploy/localstack -- awslocal sqs create-queue --queue-name order-events

# the redrive policy: after 3 failed receives, move the message to the DLQ.
# a short visibility timeout so a failed message comes back quickly.
kubectl exec deploy/localstack -- awslocal sqs set-queue-attributes --queue-url "$MAIN" \
  --attributes '{"VisibilityTimeout":"5","RedrivePolicy":"{\"deadLetterTargetArn\":\"'"$DLQ_ARN"'\",\"maxReceiveCount\":\"3\"}"}'
```

## 2. Deploy the worker

```bash
kubectl apply -f worker.yaml
kubectl rollout status deploy/worker
kubectl logs deploy/worker
# worker up, polling http://localstack:4566/000000000000/order-events
```

Look at `worker.yaml`. It long-polls the queue, prints each message, deletes the good ones and deliberately fails anything with `bad` in it by not deleting it.

## 3. A good message

```bash
kubectl exec deploy/localstack -- awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/order-events \
  --message-body '{"order":123,"status":"paid"}'

kubectl logs deploy/worker | tail
# processed: {"order":123,"status":"paid"}
```

The worker picked it up, handled it and deleted it. Gone from the queue.

## 4. A poison message and the DLQ

```bash
kubectl exec deploy/localstack -- awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/order-events \
  --message-body '{"order":666,"status":"bad"}'

# watch the worker try it a few times
kubectl logs deploy/worker -f
# FAILED to process: {"order":666,"status":"bad"}  (leaving it for retry)
# FAILED to process: {"order":666,"status":"bad"}  (leaving it for retry)
# FAILED to process: {"order":666,"status":"bad"}  (leaving it for retry)
```

Each time the worker fails, it leaves the message on the queue. After the visibility timeout it comes back. Once it has been received more than the redrive limit, SQS moves it to the dead-letter queue. Check:

```bash
DLQ=http://localhost:4566/000000000000/order-events-dlq
kubectl exec deploy/localstack -- awslocal sqs get-queue-attributes \
  --queue-url $DLQ --attribute-names ApproximateNumberOfMessages
# ApproximateNumberOfMessages: 1

kubectl exec deploy/localstack -- awslocal sqs receive-message \
  --queue-url $DLQ --query 'Messages[0].Body' --output text
# {"order":666,"status":"bad"}
```

There it is. The bad message stopped blocking the worker and is parked in the DLQ, where you can look at it, fix the cause and replay it later.

## How this maps to EKS

| In this lab (Kind) | On EKS (this episode) |
|---|---|
| LocalStack | real AWS SQS |
| static keys / endpoint on the worker | the worker's own IRSA role, no keys |
| `awslocal sqs ...` | `aws sqs ...` |
| checking DLQ depth by hand | a CloudWatch alarm on DLQ depth |

Same queue, same DLQ, same redrive policy, same worker loop. The identity and the alerting are the parts that need real AWS.

## The Makefile

```bash
make up       # once before the session: cluster, LocalStack, queues
make worker   # deploy the worker
make send     # a good message
make bad      # a poison message
make dlq      # DLQ depth and the dead message
make test     # the whole thing end to end, then tears down
make down     # delete the cluster
```

## Where the local lab stops

- **IRSA.** On EKS the worker reaches SQS through its own IAM role, with no keys. LocalStack does not enforce IAM, so the lab uses static `test` keys. The "no keys, scoped to one queue" property is real-AWS only.
- **The CloudWatch alarm.** Real SQS raises an alarm when the DLQ has messages. Here you check the depth by hand.
- **FIFO ordering.** This lab uses a standard queue. FIFO queues, with their exactly-once handling, are an AWS feature you would test against real SQS.
