# EP11 events lab. Run the demo as a few short commands.
#
#   make up       once, before the session (cluster, LocalStack, queues, images)
#   make worker   deploy the worker
#   make send     send a good message, the worker processes it
#   make bad      send a poison message, watch it retry then hit the DLQ
#   make logs     tail the worker so you see processed vs failed
#   make dlq      show the DLQ depth and read the dead message
#   make status   queues, their depths and the pods
#   make down     delete the cluster
#
# `make test` runs the whole thing end to end and tears down.

CLUSTER  := events-lab
MAIN_URL := http://localhost:4566/000000000000/order-events
DLQ_URL  := http://localhost:4566/000000000000/order-events-dlq
LS       := kubectl exec deploy/localstack -- awslocal sqs

.DEFAULT_GOAL := help

help: ## list the commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  make %-8s %s\n", $$1, $$2}'

up: ## build everything up front (cluster, LocalStack, queues, images)
	./demo-setup.sh

down: ## delete the lab cluster
	./demo-teardown.sh

worker: ## deploy the worker
	kubectl apply -f worker.yaml
	kubectl rollout status deploy/worker --timeout=120s

send: ## send a good message (the worker processes it)
	$(LS) send-message --queue-url $(MAIN_URL) --message-body '{"order":123,"status":"paid"}' >/dev/null
	@echo "sent a good message"

bad: ## send a poison message (retries, then lands in the DLQ)
	$(LS) send-message --queue-url $(MAIN_URL) --message-body '{"order":666,"status":"bad"}' >/dev/null
	@echo "sent a poison message. give it ~20s, then: make dlq"

logs: ## tail the worker (processed vs failed)
	kubectl logs deploy/worker -f

dlq: ## show the DLQ depth and read the dead message
	@echo "DLQ depth: $$($(LS) get-queue-attributes --queue-url $(DLQ_URL) --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null | tr -d '\r')"
	@echo "dead message: $$($(LS) receive-message --queue-url $(DLQ_URL) --query 'Messages[0].Body' --output text 2>/dev/null | tr -d '\r')"

status: ## queues, their depths and the pods
	@echo "main queue: $$($(LS) get-queue-attributes --queue-url $(MAIN_URL) --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null | tr -d '\r') waiting"
	@echo "dlq:        $$($(LS) get-queue-attributes --queue-url $(DLQ_URL) --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null | tr -d '\r') waiting"
	@kubectl get pods 2>/dev/null

test: ## ONE command end to end: build, run worker, good + poison message, prove DLQ, tear down
	@$(MAKE) up
	@$(MAKE) worker
	@$(MAKE) send
	@$(MAKE) bad
	@echo "waiting for the poison message to exhaust its retries..."
	@until [ "$$($(LS) get-queue-attributes --queue-url $(DLQ_URL) --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 3; done
	@echo "=== worker log ===" ; kubectl logs deploy/worker --tail=6 | grep -E 'processed|FAILED' || true
	@$(MAKE) dlq
	@echo ""
	@echo "=== end-to-end PASSED, tearing down ==="
	@$(MAKE) down

.PHONY: help up down worker send bad logs dlq status test
