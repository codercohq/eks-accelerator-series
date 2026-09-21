# EP10 manifests

The real-AWS front door. Traefik behind an NLB, a Let's Encrypt issuer, ExternalDNS and the api-gateway Ingress that ties them together.

## Prerequisites

- The AWS Load Balancer Controller, so a LoadBalancer Service becomes an NLB. Callback to EP3: the public subnets need the `kubernetes.io/role/elb` tags.
- The two IRSA roles from `terraform/`, one for cert-manager and one for ExternalDNS.
- A Route 53 hosted zone for your domain.

## Order

```bash
# Traefik, fronted by the NLB
helm repo add traefik https://traefik.github.io/charts && helm repo update
helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace -f traefik-values.yaml --wait
kubectl -n traefik get svc traefik      # EXTERNAL-IP becomes the NLB hostname

# cert-manager (the operator), then the issuer
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
# annotate the cert-manager service account with its IRSA role, then:
kubectl apply -f clusterissuer.yaml

# ExternalDNS, with its own IRSA role in the values
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns && helm repo update
helm upgrade --install external-dns external-dns/external-dns \
  -n external-dns --create-namespace -f externaldns-values.yaml --wait

# the Ingress that drives all three
kubectl apply -f ingress.yaml
```

## Watch it come together

```bash
kubectl get certificate app-tls -w        # cert-manager: Ready once issued
kubectl -n external-dns logs deploy/external-dns | grep app   # the Route 53 record
curl https://app.example.com/             # HTTPS, real cert, real DNS
```

## The point

One Ingress object does three jobs: Traefik routes it, cert-manager gives it a certificate, ExternalDNS gives it a DNS record. Each controller reaches AWS through its own IRSA role, so there are no keys anywhere.

Test the issuer against Let's Encrypt staging first (the `clusterissuer.yaml` default), then switch to production once it issues cleanly, because production has strict rate limits.

For a hands-on version with no AWS account, see [`../lab/`](../lab/README.md).
