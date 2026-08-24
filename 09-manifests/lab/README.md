# Lab: workloads, probes and autoscaling on a local Kind cluster

You can run the autoscaling story on your laptop. A service that burns CPU per request, a HorizontalPodAutoscaler watching it, plus a load generator that drives the CPU up so you watch the cluster add pods on its own. It also shows the two things every service needs: probes and resource requests.

## What you will see

- A Deployment with a readiness probe and a liveness probe, with what each one is for.
- One service reaching another by its Service DNS name, never by IP.
- CPU climbing under load, then the HPA adding pods to keep up.
- The pods scaling back down once the load stops.

## Prerequisites

```bash
docker --version     # OrbStack or Docker Desktop
kind --version
kubectl version --client
```

## Running it live

For teaching, do the slow parts before the room joins with `./demo-setup.sh` (cluster, metrics-server, images). Then on stage you apply the Deployment and HPA and drive load. `./demo-teardown.sh` deletes the cluster. There is a `Makefile` too, see the end.

## 1. Cluster and metrics-server

The HPA reads CPU from metrics-server, which does not ship with Kubernetes, so you install it. On Kind it needs one extra flag, because Kind's kubelet uses a self-signed certificate:

```bash
cd 09-manifests/lab
kind create cluster --name workloads-lab

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deploy/metrics-server
```

## 2. Deploy the service

```bash
kubectl apply -f manifests/api-gateway.yaml -f manifests/hpa.yaml
kubectl rollout status deploy/api-gateway
kubectl get deploy,svc,hpa -l app=api-gateway
```

Look at `manifests/api-gateway.yaml`. It has a **readiness probe** (a pod gets traffic only once this passes) and a **liveness probe** (a wedged pod gets restarted). It also sets a **CPU request** of 100m, which is the number the HPA measures against.

## 3. One service reaches another by name

```bash
kubectl run dnscheck --image=busybox:1.36 --restart=Never --command -- \
  sh -c 'nslookup api-gateway; echo ---; wget -q -O- http://api-gateway/'
kubectl logs dnscheck
# resolves api-gateway.default.svc.cluster.local, then prints OK!
kubectl delete pod dnscheck
```

Inside the cluster a service is reachable at its name. That is how your nine services call each other, no IPs anywhere.

## 4. Watch it autoscale

Start the load, then watch the HPA in another view:

```bash
kubectl apply -f manifests/loadgen.yaml
kubectl get hpa api-gateway -w
```

Within a minute or two the CPU column climbs past the 50% target, then the HPA raises the replica count. Confirm the pods actually appeared:

```bash
kubectl get pods -l app=api-gateway
kubectl top pods -l app=api-gateway
```

You changed nothing about the Deployment. Load went up, the HPA added pods.

## 5. Scale back down

```bash
kubectl delete -f manifests/loadgen.yaml
kubectl get hpa api-gateway -w
```

CPU falls, then after a few minutes the HPA removes the extra pods. Scale-down is deliberately slower than scale-up, so a brief dip does not tear pods away.

## How this maps to EKS

| In this lab (Kind) | On EKS (this episode) |
|---|---|
| metrics-server with `--kubelet-insecure-tls` | metrics-server as a normal addon |
| one `hpa-example` service | your nine services from the base |
| HPA on CPU | HPA on CPU, plus KEDA on queue depth for the worker |
| pods scale on one node | pods scale, then Karpenter adds nodes for them |

Same Deployment, same probes, same HPA. On EKS the HPA adding pods is also what triggers Karpenter from EP5 to add nodes when the current ones are full.

## The Makefile

```bash
make up       # once before the session: cluster, metrics-server, images
make deploy   # Deployment + Service + HPA
make dns      # prove Service DNS from another pod
make load     # start the load generator
make watch    # watch the HPA scale up
make test     # the whole thing end to end, then tears down
make down     # delete the cluster
```

## Where the local lab stops

- **KEDA on queue depth.** The worker scales on how many SQS messages wait, not on CPU. That needs real SQS, so it is shown on EKS, not here.
- **Karpenter adding nodes.** On one Kind node the pods just pack tighter. On EKS the HPA adding pods is what makes Karpenter add a node.
- **The metrics flicker.** On Kind you may see the HPA read `<unknown>` for a few seconds now and then, a metrics-server sampling gap on a single small node. On EKS it is steady.
