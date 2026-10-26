# aws-k8s-platform

Kubernetes and AWS deployment for two of my Spring Boot services:

- [payflow-ledger](https://github.com/Jagadeesh-Udatha/payflow-ledger): payments ledger on PostgreSQL + Kafka (transactional outbox)
- [telemetry-stream](https://github.com/Jagadeesh-Udatha/telemetry-stream): vehicle GPS stream processing on Kafka + MongoDB

One generic Helm chart deploys both services. Terraform builds the AWS side: VPC, EKS, RDS PostgreSQL, MSK, ECR, Secrets Manager, cluster add-ons and a GitHub OIDC deploy role. Every push runs CI, which spins up a real kind cluster, deploys both services with their dependencies and runs an end-to-end smoke test.

```
                    GitHub Actions ──OIDC──▶ IAM deploy role ──▶ ECR push + helm upgrade (namespace "platform" only)
                                                                      │
 ┌──────────────────────────── VPC (2-3 AZs) ─────────────────────────┼───────────────────────┐
 │ public subnets:   ALB  ◀── AWS Load Balancer Controller (Ingress) │                       │
 │ private subnets:  EKS managed node group                          ▼                       │
 │                     ├─ payflow-ledger    (HPA, PDB, ExternalSecret, NetworkPolicy)         │
 │                     ├─ telemetry-stream  (HPA, PDB, ExternalSecret, NetworkPolicy)         │
 │                     └─ add-ons: external-secrets, cluster-autoscaler, metrics-server       │
 │ database subnets: RDS PostgreSQL 16 (TLS only)    MSK Kafka (TLS)                          │
 └────────────────────────────────────────────────────────────────────────────────────────────┘
 Secrets Manager: payflow/<env>, telemetry/<env>, telemetry/<env>/mongo (MongoDB Atlas URI)
```

## Layout

| Path | What it is |
|---|---|
| `charts/spring-service` | Generic chart for a Spring Boot service: Deployment, Service, ConfigMap, Secret or ExternalSecret, HPA, PDB, Ingress (ALB), NetworkPolicy, ServiceMonitor, `helm test` hook. `values.schema.json` rejects bad values at install time. |
| `deploy/<app>/values*.yaml` | Per-app values plus overlays for `kind`, `dev` and `prod`. |
| `dev/` | Local/CI environment: kind config, in-cluster Postgres/Kafka/Mongo, `up.sh` and `smoke.sh`. |
| `terraform/modules/*` | network, eks-cluster, postgres, kafka, ecr, app-secrets, cluster-addons, github-deploy |
| `terraform/platform` | Wires the modules into one environment. |
| `terraform/envs/{dev,prod}` | Thin roots: only the sizing differs (spot vs on-demand, single vs per-AZ NAT, Multi-AZ RDS, broker count, deletion protection). |
| `.github/workflows` | `ci.yml` (lint, schema validation, Terraform checks, kind e2e) and `deploy.yml` (manual deploy to EKS). |

## What the chart does for a Spring Boot pod

- Startup, liveness and readiness probes on `/actuator/health/*`, with a startup probe so slow JVM starts are not killed.
- Graceful shutdown: `SERVER_SHUTDOWN=graceful`, a `preStop` sleep so the endpoint leaves the load balancer first, and `terminationGracePeriodSeconds`.
- `JAVA_TOOL_OPTIONS` sizes the heap from the container memory limit.
- Runs as non-root user 10001 with a read-only root filesystem (writable `/tmp` only), all capabilities dropped and the RuntimeDefault seccomp profile.
- Checksum annotations restart pods when the ConfigMap or Secret changes.
- Topology spread across zones and nodes; a PodDisruptionBudget keeps replicas up during node drains.

## Run it locally (kind)

Needs Docker, kind, kubectl, helm and jq.

```bash
kind create cluster --config dev/kind.yaml
docker build -t payflow-ledger:ci ../payflow-ledger && kind load docker-image payflow-ledger:ci --name platform
docker build -t telemetry-stream:ci ../telemetry-stream && kind load docker-image telemetry-stream:ci --name platform
./dev/up.sh      # Postgres, Kafka, Mongo, then both services via Helm, then helm test
./dev/smoke.sh   # transfer + idempotent replay + Kafka event; GPS event -> overspeed alert
```

## Deploy to AWS

> **Cost warning.** This creates billable resources: the EKS control plane alone is about $0.10/hour, plus nodes, NAT gateway(s), RDS and MSK. Dev is sized small, but run `terraform destroy` when you're done.

```bash
cd terraform/envs/dev
cp backend.hcl.example backend.hcl            # point at your S3 state bucket
cp terraform.tfvars.example terraform.tfvars  # your IP in admin_cidrs
terraform init -backend-config=backend.hcl
terraform apply
# MongoDB is on Atlas; paste its URI once:
aws secretsmanager put-secret-value --secret-id telemetry/dev/mongo --secret-string '{"uri":"mongodb+srv://..."}'
```

Then in GitHub, create an environment `dev` with the variable `AWS_DEPLOY_ROLE_ARN` set to the `github_deploy_role_arn` output, and run the **Deploy** workflow. Give the `prod` environment a required reviewer.

## Security choices

- No AWS keys in GitHub. Actions log in with OIDC, and the role trusts only this repo's jobs in the matching GitHub environment.
- The deploy role can push to its own ECR repositories and has `AmazonEKSEditPolicy` scoped to the `platform` namespace only.
- App credentials live in Secrets Manager. External Secrets Operator syncs them into Kubernetes using an IRSA role that can read only those secrets.
- RDS enforces TLS (`rds.force_ssl`) and MSK clients use TLS. Both accept connections only from the node security group.
- The Kubernetes API endpoint is public but limited to `admin_cidrs`; a validation rule rejects `0.0.0.0/0`.
- ECR tags are immutable (the tag is the git SHA) and images are scanned on push.

## Known limits

- MSK uses network isolation instead of client authentication. Next step: IAM auth with a per-service IRSA role.
- PayFlow's outbox relay uses `SELECT ... FOR UPDATE SKIP LOCKED`, so replicas never publish the same row twice. Per-account event order across replicas is not strict; that would need a single active relay (e.g. ShedLock).
- The AWS path is validated with `terraform validate` and tflint in CI, not applied from CI. The kind path is deployed and tested on every push.
