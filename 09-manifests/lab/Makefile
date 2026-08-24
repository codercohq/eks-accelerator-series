# EP9 workloads lab. Run the demo as a few short commands.
#
#   make up       once, before the session (cluster, metrics-server, images)
#   make deploy   apply the api-gateway Deployment + Service + HPA
#   make dns      prove Service DNS: reach api-gateway by name from another pod
#   make load     start the load generator
#   make watch    watch the HPA scale up (Ctrl-C to stop)
#   make top      show pod CPU right now
#   make stop     stop the load
#   make status   deployment, hpa and pods at a glance
#   make down     delete the cluster
#
# `make test` runs the whole thing end to end and tears down.

CLUSTER := workloads-lab

.DEFAULT_GOAL := help

help: ## list the commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  make %-8s %s\n", $$1, $$2}'

up: ## build everything up front (cluster, metrics-server, images)
	./demo-setup.sh

down: ## delete the lab cluster
	./demo-teardown.sh

deploy: ## apply the api-gateway Deployment + Service + HPA
	kubectl apply -f manifests/api-gateway.yaml -f manifests/hpa.yaml
	kubectl rollout status deploy/api-gateway --timeout=120s

dns: ## prove Service DNS: reach api-gateway by name from another pod
	@kubectl delete pod dnscheck --ignore-not-found >/dev/null 2>&1 || true
	@kubectl run dnscheck --image=busybox:1.36 --restart=Never --command -- \
	  sh -c 'nslookup api-gateway; echo ---; wget -q -O- http://api-gateway/' >/dev/null
	@kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/dnscheck --timeout=40s >/dev/null 2>&1 || true
	@kubectl logs dnscheck
	@kubectl delete pod dnscheck --ignore-not-found >/dev/null 2>&1 || true

load: ## start the load generator (hits api-gateway through its Service DNS)
	kubectl apply -f manifests/loadgen.yaml

watch: ## watch the HPA scale up
	kubectl get hpa api-gateway -w

top: ## show pod CPU right now
	kubectl top pods -l app=api-gateway

stop: ## stop the load
	kubectl delete -f manifests/loadgen.yaml --ignore-not-found

status: ## deployment, hpa and pods at a glance
	@kubectl get deploy,hpa,pods -l app=api-gateway 2>/dev/null

test: ## ONE command end to end: deploy, prove DNS, load, wait for scale-up, tear down
	@$(MAKE) up
	@$(MAKE) deploy
	@$(MAKE) dns
	@$(MAKE) load
	@echo "waiting for the HPA to scale past 1 replica..."
	@until [ "$$(kubectl get hpa api-gateway -o jsonpath='{.status.currentReplicas}' 2>/dev/null)" -gt 1 ] 2>/dev/null; do sleep 10; kubectl get hpa api-gateway --no-headers 2>/dev/null; done
	@echo "=== scaled up ==="
	@kubectl get deploy api-gateway
	@$(MAKE) down

.PHONY: help up down deploy dns load watch top stop status test
