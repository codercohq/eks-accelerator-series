# EP9 ingress lab. Run the demo as a few short commands.
#
#   make up       once, before the session (cluster, images, Traefik)
#   make route    apply the apps + Ingress, then curl both hostnames
#   make shop     curl the shop hostname
#   make admin    curl the admin hostname
#   make miss     curl an unknown hostname (Traefik answers 404)
#   make kill     delete the Traefik pod, show routing recovers
#   make status   show the ingress, the pods and the services
#   make down     delete the cluster
#
# `make test` runs the whole thing end to end and tears down.

CLUSTER := ingress-lab

.DEFAULT_GOAL := help

help: ## list the commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  make %-8s %s\n", $$1, $$2}'

up: ## build everything up front (cluster, images, Traefik)
	./demo-setup.sh

down: ## delete the lab cluster
	./demo-teardown.sh

route: ## apply the apps + Ingress, then curl both hostnames
	kubectl apply -f manifests/apps.yaml -f manifests/ingress.yaml
	kubectl rollout status deploy/shop deploy/admin --timeout=120s
	@sleep 2
	@$(MAKE) -s shop
	@$(MAKE) -s admin

shop: ## curl the shop hostname (routes to the api-gateway stand-in)
	@echo "shop.localhost  -> $$(curl -s --max-time 10 -H 'Host: shop.localhost' http://localhost/)"

admin: ## curl the admin hostname
	@echo "admin.localhost -> $$(curl -s --max-time 10 -H 'Host: admin.localhost' http://localhost/)"

miss: ## curl an unknown hostname (Traefik answers 404)
	@echo "nope.localhost  -> HTTP $$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H 'Host: nope.localhost' http://localhost/)"

kill: ## delete the Traefik pod and show the route recovers on the same entrypoint
	kubectl -n traefik delete pod -l app.kubernetes.io/name=traefik
	kubectl -n traefik rollout status deploy/traefik --timeout=120s
	@echo "waiting for the new pod to serve..."
	@until curl -s --max-time 5 -H 'Host: shop.localhost' http://localhost/ | grep -q SHOP; do sleep 2; done
	@$(MAKE) -s shop

status: ## show the ingress, the pods and the services
	@kubectl get ingress 2>/dev/null
	@kubectl get pods 2>/dev/null
	@kubectl -n traefik get pods 2>/dev/null

test: ## ONE command end to end: build, route, prove routing, kill-and-recover, tear down
	@$(MAKE) up
	@$(MAKE) route
	@$(MAKE) miss
	@$(MAKE) kill
	@echo ""
	@echo "=== end-to-end PASSED, tearing down ==="
	@$(MAKE) down

.PHONY: help up down route shop admin miss kill status test
