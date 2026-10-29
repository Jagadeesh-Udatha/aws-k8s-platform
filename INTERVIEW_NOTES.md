# Interview notes

Short answers I can give about this repo, and the follow-up questions they invite.

**Why plain YAML and kubectl instead of a templating tool?**
Two services with the same shape don't need one. Each service has four small manifests I can read top to bottom; the only things that change per environment (image tag, config, secrets) are set by the deploy script with `kubectl set image` and `kubectl create configmap/secret --dry-run=client -o yaml | kubectl apply -f -`.

**How do secrets get into the pods?**
`aws/create.sh` generates the passwords and stores them in AWS Secrets Manager. `aws/deploy.sh` reads the secret with the AWS CLI and turns every key into a Kubernetes Secret, which the pod loads with `envFrom`. Nothing sensitive is in git.

**How does a deploy happen without downtime?**
Rolling update with `maxUnavailable: 0`. The readiness probe gates traffic. On shutdown, `preStop` sleeps a few seconds so the load balancer stops sending traffic first, then Spring drains in-flight requests (`server.shutdown=graceful`). The PDB keeps a pod up during node drains, and the deploy script runs `kubectl rollout undo` if the new pods never become ready.

**What runs PayFlow's outbox relay when there are several replicas?**
Every replica runs it. The batch query takes row locks with `FOR UPDATE SKIP LOCKED` (MySQL 8), so two pods never pick the same rows. The trade-off: events for one account could publish out of order across pods. If that matters, I'd run a single active relay.

**Why does telemetry-stream scale to at most 6 pods?**
`telemetry.raw` has 12 partitions and each pod runs 2 consumer threads. Kafka gives each partition to one consumer in the group, so a 7th pod would sit idle. The HPA also waits 5 minutes before scaling down to avoid rebalance storms.

**How is CI given access to AWS?**
GitHub OIDC: the IAM role trusts only this repository's jobs in the `dev` environment, so there are no stored AWS keys.

**How do you test this without paying for AWS on every push?**
- `kubeconform` validates every manifest against the Kubernetes 1.33 schemas, and `shellcheck` checks the scripts.
- CI builds both images, creates a kind cluster, deploys MySQL, Kafka and MongoDB plus both services with the same manifests, and runs an end-to-end smoke test (a transfer, an idempotent replay, the Kafka event, a GPS event that raises an overspeed alert).

**What would you add next?**
- TLS + IAM auth for MSK.
- An AWS Application Load Balancer with HTTPS in front of both services instead of one load balancer per Service.
- Separate dev and prod clusters with on-demand nodes and Multi-AZ RDS for prod.
