#!/usr/bin/env bash
# Deploy PostgreSQL, Kafka, MongoDB and both services to the current kube context (a kind cluster).
# The images payflow-ledger:ci and telemetry-stream:ci must already be loaded:
#   docker build -t payflow-ledger:ci ../payflow-ledger && kind load docker-image payflow-ledger:ci --name platform
set -euo pipefail
NS=${NS:-platform}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" apply -f "$ROOT/dev/deps.yaml"
for d in postgres kafka mongo; do
  kubectl -n "$NS" rollout status "deploy/$d" --timeout=240s
done

for app in payflow-ledger telemetry-stream; do
  echo "--- installing $app"
  helm upgrade --install "$app" "$ROOT/charts/spring-service" -n "$NS" \
    -f "$ROOT/deploy/$app/values.yaml" -f "$ROOT/deploy/$app/values-kind.yaml" \
    --wait --timeout 6m
done

for app in payflow-ledger telemetry-stream; do
  helm test "$app" -n "$NS" --timeout 3m
done
