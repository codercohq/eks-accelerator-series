# EP10 ingress lab. Run the demo as a few short commands.
#
#   make up       once, before the session (cluster, Traefik, cert-manager)
#   make issuer   create the local CA that stands in for Let's Encrypt
#   make route    apply the app + Ingress (cert-manager issues the cert)
#   make https    curl HTTPS, and show HTTP redirects to it
#   make cert     show the Certificate and who issued it
#   make status   ingress, certificate, pods
#   make down     delete the cluster
#
# `make test` runs the whole thing end to end and tears down.

CLUSTER := ingress-lab
CURL    := curl -sk --resolve shop.localhost:80:127.0.0.1 --resolve shop.localhost:443:127.0.0.1

.DEFAULT_GOAL := help

help: ## list the commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  make %-8s %s\n", $$1, $$2}'

up: ## build everything up front (cluster, Traefik, cert-manager)
	./demo-setup.sh

down: ## delete the lab cluster
	./demo-teardown.sh

issuer: ## create the local CA (stands in for Let's Encrypt)
	kubectl apply -f manifests/issuer.yaml
	@echo "waiting for the CA issuer..."
	@until kubectl get clusterissuer lab-ca -o jsonpath='{.status.conditions[0].status}' 2>/dev/null | grep -q True; do sleep 3; done
	@echo "lab-ca ready"

route: ## apply the app + Ingress (cert-manager issues the cert)
	kubectl apply -f manifests/app.yaml -f manifests/ingress.yaml
	kubectl rollout status deploy/shop --timeout=120s
	@echo "waiting for cert-manager to issue the cert..."
	@until kubectl get certificate shop-tls -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null | grep -q Ready; do sleep 3; done
	@echo "cert issued"
	@echo "waiting for Traefik to serve the backend over HTTPS..."
	@until $(CURL) https://shop.localhost/ 2>/dev/null | grep -q SHOP; do sleep 3; done
	@echo "HTTPS live"

https: ## curl HTTPS, and show HTTP redirects to it
	@echo "HTTP  -> $$($(CURL) -I http://shop.localhost/ 2>/dev/null | awk 'NR==1{print $$2, $$3, $$4}')"
	@echo "HTTPS -> $$($(CURL) https://shop.localhost/ 2>/dev/null)"

cert: ## show the Certificate and who issued it
	@kubectl get certificate shop-tls
	@echo -n "served by issuer: "; echo | openssl s_client -connect 127.0.0.1:443 -servername shop.localhost 2>/dev/null | openssl x509 -noout -issuer

status: ## ingress, certificate and pods
	@kubectl get ingress,certificate 2>/dev/null
	@kubectl get pods 2>/dev/null
	@kubectl -n traefik get pods 2>/dev/null

test: ## ONE command end to end: build, issue, route, prove HTTPS + redirect, tear down
	@$(MAKE) up
	@$(MAKE) issuer
	@$(MAKE) route
	@$(MAKE) https
	@echo ""
	@echo "=== end-to-end PASSED, tearing down ==="
	@$(MAKE) down

.PHONY: help up down issuer route https cert status test
