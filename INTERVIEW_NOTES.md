# Interview notes

Short answers I can give about this repo, and the follow-up questions they invite.

**Why one generic chart instead of one chart per service?**
Both services are Spring Boot apps with the same runtime needs: probes, graceful shutdown, secrets, autoscaling. One chart keeps those rules in one place. Each service only supplies values, and `values.schema.json` catches typos before anything reaches the cluster.

**How do secrets get into the pods?**
Terraform generates the passwords and writes them to Secrets Manager. External Secrets Operator runs with an IRSA role that can read only those secret ARNs, and it syncs them into a Kubernetes Secret that the pod loads with `envFrom`. Nothing sensitive is in git or Helm values. The chart refuses to render if both a plain Secret and an ExternalSecret are turned on.

**How does a deploy happen without downtime?**
Rolling update with `maxUnavailable: 0`. The readiness probe gates traffic. On shutdown, `preStop` sleeps a few seconds so the ALB stops sending traffic first, then Spring drains in-flight requests (`server.shutdown=graceful`). The PDB keeps a minimum number of pods during node drains, and `helm upgrade --atomic` rolls back if the new pods never become ready.

**What runs PayFlow's outbox relay when there are several replicas?**
Every replica runs it. The batch query takes row locks with `FOR UPDATE SKIP LOCKED`, so two pods never pick the same rows. The trade-off: events for one account could publish out of order across pods. If that matters, I'd elect a single active relay with ShedLock.

**How is CI given access to AWS?**
GitHub OIDC. The IAM role's trust policy checks the token's audience and `sub` (`repo:Jagadeesh-Udatha/aws-k8s-platform:environment:<env>`). The role can push to its own ECR repos and edit only the `platform` namespace through an EKS access entry. A required reviewer on the prod GitHub environment acts as the approval gate.

**Dev vs prod differences?**
Same modules, different inputs:
- AZs: 2 in dev, 3 in prod.
- NAT: one in dev, one per AZ in prod.
- Nodes: spot with mixed instance types in dev, on-demand in prod.
- Data stores: Multi-AZ RDS and 3 MSK brokers (`min.insync.replicas=2`) in prod only.
- Deletion protection and a secret recovery window in prod only.

**How do you test infrastructure code without paying for AWS on every push?**
Two layers:
- Terraform gets `fmt`, `validate` and tflint on every push.
- The Kubernetes side runs for real: CI builds both images, creates a kind cluster, deploys Postgres, Kafka and Mongo plus both services through the same chart, and runs `helm test` and an end-to-end smoke script (a transfer, an idempotent replay, the Kafka event, a GPS event that raises an overspeed alert).

**What would you add next?**
- MSK IAM auth.
- Argo CD for GitOps instead of `helm upgrade` from Actions.
- Karpenter instead of cluster-autoscaler.
- A Grafana dashboard driven by the ServiceMonitor metrics.
