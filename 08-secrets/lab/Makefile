# EP8 secrets lab. Run the demo as a few short commands.
#
#   make up        once, before the session (slow parts: cluster, images, operator)
#   make secret    show the secret sitting in Secrets Manager
#   make sync      apply the SecretStore + ExternalSecret, watch it sync
#   make db        run Postgres on the synced Secret and prove the password
#   make rotate    rotate at the source, watch the cluster follow
#   make break     point at a missing key, show it fail safely, then restore
#   make status    show everything at a glance
#   make down      delete the cluster
#
# `make demo` runs the happy path start to finish for a rehearsal.

CLUSTER   := secrets-lab
SECRET_ID := eks-accel/dev/postgres
INIT_PW   := s3cr3t-from-localstack
LS        := kubectl exec deploy/localstack --

.DEFAULT_GOAL := help

help: ## list the commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  make %-9s %s\n", $$1, $$2}'

up: ## build everything up front (cluster, images, LocalStack, operator, seed)
	./demo-setup.sh

down: ## delete the lab cluster
	./demo-teardown.sh

secret: ## show the secret that lives in Secrets Manager (LocalStack)
	@echo "secrets in the store:"
	@$(LS) awslocal secretsmanager list-secrets --query 'SecretList[].Name' --output text
	@echo "value of $(SECRET_ID):"
	@$(LS) awslocal secretsmanager get-secret-value --secret-id $(SECRET_ID) --query SecretString --output text

sync: ## apply the SecretStore + ExternalSecret and watch the operator build the Secret
	kubectl apply -f manifests/secretstore.yaml -f manifests/externalsecret.yaml
	@echo "waiting for the operator..."
	@sleep 8
	kubectl get externalsecret postgres
	@$(MAKE) -s show

show: ## print the Kubernetes Secret the operator built (decoded)
	@echo "synced POSTGRES_PASSWORD: $$(kubectl get secret postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)"

db: ## run Postgres on the synced Secret, then prove the password from another pod
	kubectl apply -f manifests/postgres.yaml
	kubectl rollout status statefulset/postgres --timeout=180s
	@$(MAKE) -s prove

prove: ## check the DB password from a second pod (right works, wrong is refused)
	@kubectl delete pod pw-ok pw-bad --ignore-not-found >/dev/null 2>&1 || true
	@kubectl run pw-ok  --image=postgres:18 --restart=Never --env=PGPASSWORD=$(INIT_PW) --command -- sh -c 'psql -h postgres -U app -d app -tAc "select 1" 2>&1; true' >/dev/null
	@kubectl run pw-bad --image=postgres:18 --restart=Never --env=PGPASSWORD=nope --command -- sh -c 'psql -h postgres -U app -d app -tAc "select 1" 2>&1; true' >/dev/null
	@kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/pw-ok pod/pw-bad --timeout=90s >/dev/null 2>&1 || true
	@echo "  right password ($(INIT_PW)) -> $$(kubectl logs pw-ok | grep -iE '^1$$|failed' | head -1)"
	@echo "  wrong password (nope)       -> $$(kubectl logs pw-bad | grep -ioE 'password authentication failed' | head -1)"
	@kubectl delete pod pw-ok pw-bad --ignore-not-found >/dev/null 2>&1 || true

rotate: ## rotate the password at the source and watch the Secret follow
	$(LS) awslocal secretsmanager put-secret-value --secret-id $(SECRET_ID) \
	  --secret-string '{"username":"app","dbname":"app","password":"ROTATED-v2"}'
	@echo "waiting one refresh interval..."
	@sleep 20
	@$(MAKE) -s show
	@echo "note: the Secret changed, but the running Postgres keeps its original password (it read it once at boot)."

break: ## point the ExternalSecret at a missing key, show it fail safely, then restore
	kubectl patch externalsecret postgres --type=json \
	  -p='[{"op":"replace","path":"/spec/data/2/remoteRef/key","value":"eks-accel/dev/nope"}]'
	@sleep 6
	kubectl get externalsecret postgres
	@echo "restoring..."
	@kubectl patch externalsecret postgres --type=json \
	  -p='[{"op":"replace","path":"/spec/data/2/remoteRef/key","value":"eks-accel/dev/postgres"}]' >/dev/null
	@sleep 4 ; kubectl get externalsecret postgres

logs: ## follow the operator logs
	kubectl -n external-secrets logs deploy/external-secrets -f

status: ## show the operator objects, the Secret and the pods
	@kubectl get externalsecret,secretstore 2>/dev/null
	@kubectl get secret postgres 2>/dev/null
	@kubectl get pods 2>/dev/null

demo: up sync db ## run the whole happy path for a rehearsal (up, sync, db)
	@echo ""
	@echo "happy path done. now try: make rotate | make break | make status | make down"

test: ## ONE command end to end: build, sync, boot DB, prove password, rotate, tear down
	@$(MAKE) up
	@$(MAKE) sync
	@$(MAKE) db
	@$(MAKE) rotate
	@echo ""
	@echo "=== end-to-end PASSED, tearing down ==="
	@$(MAKE) down

.PHONY: help up down secret sync show db prove rotate break logs status demo test
