# Lab: Ingress on a local Kind cluster

You can run the whole ingress flow on your laptop. Traefik is the ingress controller, with two tiny web apps standing in for your services. You send a request to `localhost` with a hostname, then Traefik routes it to the right app. It is the same Ingress object you use on EKS, with Kind's port mapping standing in for the NLB.

## What you will see

- Traefik taking traffic on `localhost` and routing by hostname.
- `shop.localhost` reaching one app and `admin.localhost` reaching another, through one Ingress.
- An unknown hostname getting a 404 straight from Traefik.
- You delete the Traefik pod and watch the route come straight back.

## Prerequisites

```bash
docker --version     # OrbStack or Docker Desktop
kind --version
kubectl version --client
helm version
```

Nothing must already be using ports 80 and 443 on your machine.

## Running it live

For teaching, do the slow parts before the room joins with `./demo-setup.sh` (cluster, image pull, Traefik). Then on stage you only apply the apps and the Ingress and curl. `./demo-teardown.sh` deletes the cluster. There is also a `Makefile`, see the end.

## 1. Cluster and Traefik

```bash
cd 09-ingress/lab
kind create cluster --config kind-config.yaml
```

The kind config maps the node's ports 80 and 443 to your laptop, so once Traefik is listening you can curl `localhost`. On EKS the NLB does that job. Install Traefik:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik -n traefik --create-namespace \
  -f traefik-values.yaml --wait
kubectl -n traefik get pods      # one Running pod
```

## 2. Two apps and one Ingress

```bash
kubectl apply -f manifests/apps.yaml       # shop and admin, each returns its name
kubectl apply -f manifests/ingress.yaml    # the routing rule
kubectl get ingress                        # host rules for shop.localhost and admin.localhost
```

## 3. Route by hostname

```bash
curl -H "Host: shop.localhost"  http://localhost/
# hello from SHOP (the api-gateway)

curl -H "Host: admin.localhost" http://localhost/
# hello from ADMIN
```

Same address, same port, two different apps. Traefik read the `Host` header and picked the backend. That is what an ingress controller does.

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: nope.localhost" http://localhost/
# 404
```

A hostname with no rule gets a 404 from Traefik itself, because nothing told it where to send that traffic.

## 4. The controller is not a single point of the route

```bash
kubectl -n traefik delete pod -l app.kubernetes.io/name=traefik
kubectl -n traefik rollout status deploy/traefik
curl -H "Host: shop.localhost" http://localhost/
# hello from SHOP again
```

The pod was replaced and the route came back on its own. On EKS the NLB in front keeps the public address stable while Traefik pods come and go underneath it.

## How this maps to EKS

| In this lab (Kind) | On EKS (this episode) |
|---|---|
| kind port mapping 80/443 to localhost | an AWS NLB in front of Traefik |
| Traefik on a hostPort | Traefik behind the NLB, target-type ip |
| `curl -H "Host: shop.localhost"` | a real DNS name resolving to the NLB |
| one node | Traefik pods spread across nodes |

Same Ingress object, same Traefik, same host routing. Only the front door changes: a port mapping locally, a real load balancer on AWS.

## Clean up

```bash
kind delete cluster --name ingress-lab
```

## The Makefile

The lab is wrapped as short commands:

```bash
make up       # once before the session: cluster, images, Traefik
make route    # apply the apps + Ingress, curl both hostnames
make miss     # curl an unknown hostname (404)
make kill     # delete the Traefik pod, show the route recovers
make status   # ingress, pods, services
make test     # the whole thing end to end, then tears down
make down     # delete the cluster
```

## Where the local lab stops

Most of this is faithful to EKS. A couple of things are AWS-only and the lab fakes them:

- **The NLB itself.** On EKS a real Network Load Balancer sits in front of Traefik and gives you a stable public address. Kind has no cloud load balancer, so the kind port mapping stands in.
- **The AWS Load Balancer Controller.** On EKS that controller watches the Traefik Service and creates the NLB, using the subnet tags from EP3. There is no cloud API on Kind, so none of that runs here.
- **Real DNS and TLS.** Here you fake the hostname with a `Host:` header over plain HTTP. Real names and HTTPS certificates come in EP10.
