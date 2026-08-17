# EP8 manifests

The real-AWS versions. A `SecretStore` pointed at AWS Secrets Manager and two `ExternalSecret` objects that rebuild the EP7 `postgres` and `valkey` Secrets from it.

## Order

The operator has to exist first. Install it with the controller service account annotated with the IRSA role from `terraform/`, then:

```bash
kubectl apply -f secretstore.yaml
kubectl apply -f externalsecrets.yaml
kubectl get externalsecret        # both reach SecretSynced
kubectl get secret postgres valkey
```

## Seed the source secrets once

The operator reads secrets, it does not invent them. Create them in Secrets Manager first (use your own values):

```bash
aws secretsmanager create-secret --name eks-accel/dev/postgres \
  --secret-string '{"username":"app","dbname":"app","password":"CHANGE-ME"}'
aws secretsmanager create-secret --name eks-accel/dev/valkey \
  --secret-string '{"password":"CHANGE-ME"}'
```

## The point

No password is in this repo. The `postgres` and `valkey` Secrets the StatefulSets mount are built at runtime from Secrets Manager. The operator reaches Secrets Manager through its IRSA role, with no access keys anywhere.

## Retire the EP7 placeholders

EP7 shipped plain `secret.yaml` files with a placeholder password. Once these ExternalSecrets own the `postgres` and `valkey` Secret names, delete those old files so nothing overwrites the synced values.

For a hands-on version with no AWS account, see [`../lab/`](../lab/README.md).
