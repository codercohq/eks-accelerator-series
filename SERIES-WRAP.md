# EKS Accelerator Series: summary and project completion guide

Eleven sessions take a nine-service Go application from a laptop to a secure, autoscaling platform on EKS. Each session ships one piece the platform needs and builds on the last. This file summarises what was built and what you still have to build to finish the capstone.

## The episodes

| # | Session | Ships | Key technical point |
|---|---|---|---|
| 1 | Foundations | docker compose + kind, the core objects (Pod, Deployment, Service, StatefulSet) | The async path is stubbed, so the work is the platform rather than the app. |
| 2 | Containers | multi-stage Dockerfile per service, small images, health endpoints, ECR | A queue worker scales on backlog, not CPU. |
| 3 | Networking | own VPC module, 3 AZs, `/24` public and `/19` private subnets, subnet discovery tags | Max-pods is an ENI/IP limit, `(3 x 9) + 2 = 29` on an m5.large. NAT versus VPC endpoints is a cost decision. |
| 4 | The cluster | EKS (1.33+) with managed node groups, core addons, access entries, kubeconfig | Control plane is $0.10/hour. The bootstrap node group is plumbing for system pods, Karpenter owns the rest. The EBS driver is left on a borrowed node role on purpose. |
| 5 | Karpenter | own Karpenter module, NodePool and EC2NodeClass | Controller on Pod Identity. Spot with an interruption queue. Consolidation trades cost against churn. |
| 6 | Storage and identity | gp3 default and gp3-retain StorageClasses, EBS CSI on its own IRSA role, first snapshot objects | `WaitForFirstConsumer` puts the zonal volume in the pod's AZ. The EP4 node-role shortcut comes off. |
| 7 | Postgres and Redis | Postgres and Valkey StatefulSets, headless Services, volumeClaimTemplates | Valkey over Redis after the licence change. Bitnami images no longer pull. The AZ-pinning problem: a pod is welded to its volume's AZ. |
| 8 | Secrets | External Secrets Operator, SecretStore and ExternalSecret, operator IRSA role | A Kubernetes Secret is base64, not encryption. Source values live in Secrets Manager. |
| 9 | Manifests and autoscaling | nine Deployments with probes and resource requests, HPA, Kustomize base and overlays | Never put a dependency on a liveness probe. HPA on CPU for request-path services, KEDA on queue depth for the worker. |
| 10 | Ingress, DNS and HTTPS | Traefik behind an NLB, cert-manager with Let's Encrypt DNS-01, ExternalDNS | One Ingress drives routing, the certificate and the DNS record. HTTP redirects to HTTPS. ingress-nginx is retired, Gateway API is next. |
| 11 | The event bus | SQS queue and dead-letter queue with a redrive policy, worker IRSA role, DLQ CloudWatch alarm | Standard SQS is at-least-once, so handlers must be idempotent. The redrive policy parks a poison message after N tries. |

## Patterns that run through the build

- **Own Terraform modules.** Every infrastructure session ships a module you wrote rather than a wrapped upstream one. The review grades that module.
- **Least-privilege IRSA per component.** The EBS driver, the External Secrets Operator, cert-manager, ExternalDNS and the worker each get a role scoped to one set of actions on one set of resources. No `sqs:*`, no `route53:*`, no `secretsmanager:*` on `*`.
- **Pod Identity or IRSA.** Pod Identity for the Karpenter controller (the newer default), IRSA everywhere a tool still needs it. Both assume a role, neither uses a static key.
- **Build it, then break it.** Each deep dive flips one lever and reads the failure (`AccessDenied`, a volume node-affinity conflict, a pending Service), because explaining a failure is the gradeable skill.
- **Cost levers.** Spot capacity, EKS version currency, NAT versus endpoints and tearing the cluster down between sessions.
- **Callbacks.** The EP4 node-role shortcut is removed in EP6. The EP2 worker-scaling rule returns in EP9. The EP3 subnet tags make the EP10 NLB schedulable.

## Remaining project requirements, not covered as sessions

These are in the project brief and are yours to build. They are how you earn the capstone:

- CI with GitHub Actions and OIDC, image scanning before deploy, no long-lived credentials.
- GitOps with ArgoCD, an App-of-Apps syncing dev from Git.
- Zero-downtime rollouts with automated rollback on failure.
- Database migrations across the services that share one Postgres, without downtime.
- Observability: metrics, dashboards and alerts that answer what is broken inside ten minutes.

## Completing the project

- Write the required README sections before the Terraform. The review grades the decisions you can defend in prose.
- Tear the cluster down between work sessions. The control plane, NAT and load balancers bill by the hour.
- Restore a snapshot, do not only take one. An untested restore is an assumption.
- Scope every IAM policy to the resource and the action. A `*` is a finding.
- Keep the application unchanged. It is scaffolding for the platform.
- Read the error before changing anything. Most failures here state the cause once you stop skimming.

## How the review grades

You demonstrate the project and explain every resource you committed. The governing rule from `project.md`: if you cannot explain a resource you committed, you did not build it. State what is incomplete and how you would finish it, rather than hiding the gap.
