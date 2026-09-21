# Lab: ingress, HTTPS and cert-manager on a local Kind cluster

You can run most of the front-door story on your laptop. Traefik takes traffic on `localhost`, cert-manager issues a certificate, then the app is served over HTTPS with plain HTTP redirected up to it. It is the same set of objects you use on EKS, with two swaps: Kind's port mapping stands in for the NLB, plus a local certificate authority stands in for Let's Encrypt.

## What you will see

- Traefik routing a hostname to a service.
- cert-manager issuing a TLS certificate into a Secret on its own.
- The app served over HTTPS, with the certificate signed by our issuer.
- A plain HTTP request redirected to HTTPS.

## Prerequisites

```bash
docker --version     # OrbStack or Docker Desktop
kind --version
kubectl version --client
helm version
```

Nothing else must be using ports 80 and 443 on your machine.

## Running it live

For teaching, do the slow parts before the room joins with `./demo-setup.sh` (cluster, Traefik, cert-manager). Then on stage you apply the issuer, the app and the Ingress and curl. `./demo-teardown.sh` deletes the cluster. There is a `Makefile` too, see the end.

## 1. Cluster, Traefik and cert-manager

```bash
cd 10-ingress/lab
kind create cluster --config kind-config.yaml

helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik -n traefik --create-namespace \
  -f traefik-values.yaml --wait

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl -n cert-manager rollout status deploy/cert-manager-webhook
```

The kind config maps the node's ports 80 and 443 to your laptop, so once Traefik is listening you can curl `localhost`. The Traefik values also redirect plain HTTP to HTTPS.

## 2. The issuer (our stand-in for Let's Encrypt)

```bash
kubectl apply -f manifests/issuer.yaml
kubectl get clusterissuer
```

On EKS the issuer talks to Let's Encrypt and proves you own the domain with a Route 53 DNS-01 challenge. That needs a real domain, so it cannot run locally. Here we make a small certificate authority of our own instead. cert-manager does the same job either way: it issues a Certificate and stores the cert in a Secret. Only who signs it changes.

## 3. The app and the Ingress

```bash
kubectl apply -f manifests/app.yaml -f manifests/ingress.yaml
kubectl get ingress
```

Look at `manifests/ingress.yaml`. Two things trigger the certificate: the `cert-manager.io/cluster-issuer` annotation names the issuer, then the `tls` block names the hostname and the Secret to store the cert in. cert-manager notices, issues the cert and writes `shop-tls`. Watch it happen:

```bash
kubectl get certificate shop-tls -w
# READY becomes True once the cert is issued
```

## 4. HTTPS and the redirect

```bash
# HTTPS, served with the cert-manager certificate
curl -sk --resolve shop.localhost:443:127.0.0.1 https://shop.localhost/
# hello from SHOP over HTTPS

# plain HTTP is redirected up to HTTPS
curl -skL --resolve shop.localhost:80:127.0.0.1 \
  --resolve shop.localhost:443:127.0.0.1 http://shop.localhost/
# a 308 redirect, then the same HTTPS response
```

Confirm the certificate really came from our issuer rather than a Traefik default:

```bash
echo | openssl s_client -connect 127.0.0.1:443 -servername shop.localhost 2>/dev/null \
  | openssl x509 -noout -issuer
# issuer=CN=lab-ca
```

The `--resolve` flag is us faking DNS, pointing `shop.localhost` at the local address. On EKS that is a real Route 53 record, which ExternalDNS creates for you.

## How this maps to EKS

| In this lab (Kind) | On EKS (this episode) |
|---|---|
| kind port mapping 80/443 to localhost | an AWS NLB in front of Traefik |
| local CA ClusterIssuer | a Let's Encrypt ClusterIssuer over ACME |
| `--resolve` faking the hostname | a real Route 53 record from ExternalDNS |
| the redirect in Traefik values | the same redirect in Traefik values |

Same Ingress, same cert-manager Certificate, same Traefik. The certificate signer and the DNS are the parts that need real AWS.

## The Makefile

```bash
make up       # once before the session: cluster, Traefik, cert-manager
make issuer   # the local CA
make route    # app + Ingress, cert-manager issues the cert
make https    # curl HTTPS and show the redirect
make test     # the whole thing end to end, then tears down
make down     # delete the cluster
```

## Where the local lab stops

- **Real Let's Encrypt.** The ACME DNS-01 challenge proves you own a real domain, so it only runs against a real domain and Route 53. Locally we sign with our own CA, which is why the browser would call it untrusted. The cert-manager flow is identical.
- **ExternalDNS.** It writes Route 53 records, so it needs a real hosted zone. Locally we fake the name with `--resolve`.
- **The NLB.** Kind has no cloud load balancer, so the port mapping stands in.
