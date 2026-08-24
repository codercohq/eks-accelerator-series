# EP9 manifests

The real-AWS versions. Traefik as a LoadBalancer Service that the AWS Load Balancer Controller fronts with an NLB, plus the api-gateway Ingress.

## Prerequisite: the AWS Load Balancer Controller

The controller is what turns a `LoadBalancer` Service into a real NLB. If EP4 did not install it, install it now with its own IRSA role, the same identity pattern as EP6 and EP8. It also needs the public-subnet discovery tags from EP3 (`kubernetes.io/role/elb`), or it has nowhere to put the load balancer.

## Order

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace -f traefik-values.yaml --wait

kubectl -n traefik get svc traefik      # EXTERNAL-IP becomes the NLB hostname
kubectl apply -f ingress.yaml
```

## Reach it

```bash
NLB=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -H "Host: app.example.com" "http://$NLB/"
```

Point your DNS name at that NLB hostname, then the `Host:` header trick is no longer needed. Real DNS and HTTPS are EP10.

## The point

The NLB is the one stable front door. Traefik does the layer-7 routing inside the cluster, so pods can come and go without the public address changing.

For a hands-on version with no AWS account, see [`../lab/`](../lab/README.md).
