# Lab: External Secrets on a local Kind cluster

You can run the whole secrets flow on your laptop, with no AWS account. LocalStack plays the part of AWS Secrets Manager. The External Secrets Operator syncs a secret out of it into a normal Kubernetes Secret that a pod reads. It is the same set of objects you use on EKS, with LocalStack swapped in for real Secrets Manager.

## What you will see

- A secret living in Secrets Manager (LocalStack), never in your Git repo.
- The operator turning it into a Kubernetes Secret on its own.
- The actual Postgres database from EP7 booting on that password, with nothing typed in by hand.
- You rotate the secret at the source and watch the cluster catch up by itself.

## Prerequisites

```bash
docker --version     # OrbStack or Docker Desktop
kind --version
kubectl version --client
helm version
```

## Running it live

For teaching, do the slow parts before the room joins. `./demo-setup.sh` builds the cluster, pre-pulls the Postgres image, starts LocalStack, seeds the secret and installs the operator, so on stage you only run the teaching steps (apply the SecretStore and ExternalSecret, show the sync, then rotate). It is safe to run twice. `./demo-teardown.sh` deletes the cluster afterwards.

To learn it rather than present it, ignore the scripts and follow the numbered steps below by hand.

## 1. Cluster and LocalStack

```bash
cd 08-secrets/lab
kind create cluster --config kind-config.yaml
kubectl apply -f localstack.yaml
kubectl rollout status deploy/localstack
```

## 2. Put a secret in Secrets Manager

LocalStack ships the `awslocal` wrapper, which is the `aws` CLI pointed at LocalStack. Create the Postgres secret as a small JSON document:

```bash
kubectl exec deploy/localstack -- awslocal secretsmanager create-secret \
  --name eks-accel/dev/postgres \
  --secret-string '{"username":"app","dbname":"app","password":"s3cr3t-from-localstack"}'
```

That secret now lives in Secrets Manager. Nothing about it is in the cluster or your repo yet.

## 3. Install the External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  -f eso-values.yaml --wait
kubectl -n external-secrets get pods      # three pods, all Running
```

`eso-values.yaml` points the operator's AWS SDK at LocalStack. On a real cluster you drop those two lines and the SDK talks to real AWS.

## 4. Wire up the sync

```bash
kubectl apply -f manifests/secretstore.yaml     # where secrets come from
kubectl apply -f manifests/externalsecret.yaml  # what to pull and where to put it
kubectl get externalsecret postgres             # STATUS should reach SecretSynced
```

Now look at what the operator built for you:

```bash
kubectl get secret postgres
kubectl get secret postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d ; echo
# s3cr3t-from-localstack
```

You never wrote that Secret. The operator created it from Secrets Manager.

## 5. A pod reads it

```bash
kubectl apply -f manifests/consumer.yaml
kubectl wait --for=condition=Ready pod/reader --timeout=30s
kubectl logs reader
# password is: s3cr3t-from-localstack
```

## 6. Boot the real database on that Secret

The busybox pod was just a proof. Now run the actual EP7 Postgres StatefulSet, which has no secret of its own and takes all three of its credentials from the synced Secret:

```bash
kubectl apply -f manifests/postgres.yaml
kubectl rollout status statefulset/postgres
```

Now prove the password really is the one from Secrets Manager. Connect from a **second pod** rather than with `kubectl exec` into Postgres itself, because Postgres trusts connections from its own localhost with no password, so an in-pod `psql` would pass whatever you typed. A connection from another pod hits the real password check:

```bash
# the right password gets in
kubectl run pgcheck --image=postgres:18 --rm -it --restart=Never \
  --env=PGPASSWORD=s3cr3t-from-localstack \
  --command -- psql -h postgres -U app -d app -tAc "select 'connected'"
# connected

# a wrong password is refused
kubectl run pgbad --image=postgres:18 --rm -it --restart=Never \
  --env=PGPASSWORD=wrong \
  --command -- psql -h postgres -U app -d app -tAc "select 1"
# psql: error: ... password authentication failed for user "app"
```

Postgres came up and accepts only the real password. That password was never written into a manifest. It travelled from LocalStack Secrets Manager, through the operator, into the Secret the StatefulSet mounts.

## 7. Rotate it and watch the cluster follow

Change the secret at the source:

```bash
kubectl exec deploy/localstack -- awslocal secretsmanager put-secret-value \
  --secret-id eks-accel/dev/postgres \
  --secret-string '{"username":"app","dbname":"app","password":"ROTATED-v2"}'
```

Wait one refresh interval (15 seconds), then read the Kubernetes Secret again:

```bash
sleep 20
kubectl get secret postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d ; echo
# ROTATED-v2
```

You changed the secret in one place and the cluster updated itself. No `kubectl edit`, no redeploy of the manifests.

One honest caveat, true on real AWS too. The Kubernetes Secret updated, but the running Postgres did not change its own password, because it read the value once at startup and set the database password then. Syncing a Secret and changing a live database's password are two separate jobs. In production you pair rotation with something that also updates the database. Or you restart the consumer so it picks up the new value. The lab shows the sync half, which is the part External Secrets owns.

## Where the local lab stops

Most of this is faithful to EKS. A few things genuinely cannot be shown on Kind with LocalStack. It is worth naming them so nobody thinks the local run proves them:

- **The IRSA identity.** On EKS the operator assumes its own IAM role through the cluster OIDC provider, with no keys anywhere. Locally there is no real IAM or STS, so the lab uses static `test/test` keys into LocalStack instead. The whole "no access keys" property is real-AWS only.
- **IAM actually denying things.** Community LocalStack does not enforce IAM policies, so the "scope the role to one secret prefix" rule cannot be tested by watching it deny. The `AccessDenied` on `GetSecretValue`, along with the break-the-trust deep dive in the main README, only fires against real AWS.
- **Encryption at rest with KMS.** Real Secrets Manager encrypts every secret with a KMS key. LocalStack just stores it.
- **Managed rotation.** Real Secrets Manager can rotate a secret on a schedule with a Lambda. That is an AWS-side feature, not something the operator or Kind can stand in for.
- **Private networking.** On EKS the operator reaches Secrets Manager over a VPC endpoint. Here it is a Service in the cluster.

Everything else, the SecretStore, the ExternalSecret, the synced Secret and a real app consuming it, is exactly what you run on EKS.

## How this maps to EKS

| In this lab (Kind) | On EKS (this episode) |
|---|---|
| LocalStack | real AWS Secrets Manager |
| static keys in `localstack-creds` | the operator's own IRSA role, no keys |
| `AWS_ENDPOINT_URL` pointed at LocalStack | dropped, the SDK talks to real AWS |
| `awslocal secretsmanager ...` | `aws secretsmanager ...` |

Same SecretStore, same ExternalSecret, same synced Secret. Only the source and the login change.

## Clean up

```bash
kind delete cluster --name secrets-lab
```
