#!/usr/bin/env bash
# Deploy MySQL, Kafka, MongoDB and both services to the current kube context (a kind cluster) with plain kubectl.
# The images payflow-ledger:ci and telemetry-stream:ci must already be loaded:
#   docker build -t payflow-ledger:ci ../payflow-ledger && kind load docker-image payflow-ledger:ci --name platform
set -euo pipefail
NS=platform
ROOT=$(cd "$(dirname "$0")/.." && pwd)
K="kubectl -n $NS"

kubectl apply -f "$ROOT/k8s/namespace.yaml"
$K apply -f "$ROOT/dev/deps.yaml"
for d in mysql kafka mongo; do
  $K rollout status "deploy/$d" --timeout=240s
done

# Config and secrets for kind. On EKS, aws/deploy.sh creates the same objects from AWS Secrets Manager.
apply_config() { kubectl create "$@" --dry-run=client -o yaml | $K apply -f -; }
apply_config configmap payflow-ledger \
  --from-literal=DB_URL=jdbc:mysql://mysql:3306/payflow \
  --from-literal=KAFKA_BOOTSTRAP=kafka:9092 \
  --from-literal=PAYFLOW_OUTBOX_RELAY_ENABLED=true
apply_config secret generic payflow-ledger \
  --from-literal=DB_USER=payflow --from-literal=DB_PASSWORD=payflow \
  --from-literal=PAYFLOW_JWT_SECRET=kind-only-secret-0123456789abcdef0123456789 \
  --from-literal=PAYFLOW_OPS_PASSWORD=ops-kind-password \
  --from-literal=PAYFLOW_AUDITOR_PASSWORD=auditor-kind-password
apply_config configmap telemetry-stream \
  --from-literal=KAFKA_BOOTSTRAP=kafka:9092 \
  --from-literal=MONGO_URI=mongodb://mongo:27017/telemetry \
  --from-literal=CONSUMER_THREADS=1 \
  --from-literal=SPRING_PROFILES_ACTIVE=json

# kind has one node and no metrics-server, so skip the HPA/PDB and run one replica of the locally built image.
for app in payflow-ledger telemetry-stream; do
  echo "--- deploying $app"
  $K apply -f "$ROOT/k8s/$app/deployment.yaml" -f "$ROOT/k8s/$app/service.yaml"
  $K set image "deploy/$app" app="$app:ci"
  $K scale "deploy/$app" --replicas=1
  $K rollout status "deploy/$app" --timeout=6m
done
