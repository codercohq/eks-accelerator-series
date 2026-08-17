# Lab: External Secrets on a local Kind cluster

You can run the whole secrets flow on your laptop, with no AWS account. LocalStack plays the part of AWS Secrets Manager. The External Secrets Operator syncs a secret out of it into a normal Kubernetes Secret that a pod reads. It is the same set of objects you use on EKS, with LocalStack swapped in for real Secrets Manager.

## What you will see

- A secret living in Secrets Manager (LocalStack), never in your Git repo.
- The operator turning it into a Kubernetes Secret on its own.
- A pod reading that Secret as an environment variable.
- You rotate the secret at the source and watch the cluster catch up by itself.

## Prerequisites

```bash
docker --version     # OrbStack or Docker Desktop
kind --version
kubectl version --client
helm version
```

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
  --secret-string '{"username":"app","password":"s3cr3t-from-localstack"}'
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

## 6. Rotate it and watch the cluster follow

Change the secret at the source:

```bash
kubectl exec deploy/localstack -- awslocal secretsmanager put-secret-value \
  --secret-id eks-accel/dev/postgres \
  --secret-string '{"username":"app","password":"ROTATED-v2"}'
```

Wait one refresh interval (15 seconds), then read the Kubernetes Secret again:

```bash
sleep 20
kubectl get secret postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d ; echo
# ROTATED-v2
```

You changed the secret in one place and the cluster updated itself. No `kubectl edit`, no redeploy of the manifests.

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
