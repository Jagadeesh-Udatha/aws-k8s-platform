#!/usr/bin/env bash
# Build one service, push it to ECR (tag = git SHA) and roll it out on EKS with kubectl.
#   aws/deploy.sh payflow-ledger ../payflow-ledger
# Config and secrets come from AWS Secrets Manager (platform-dev/<app>, written by aws/create.sh).
set -euo pipefail
APP=${1:?app name: payflow-ledger or telemetry-stream}
SRC=${2:?path to the app repository}
REGION=${AWS_REGION:-ap-south-1}
CLUSTER=${CLUSTER:-platform-dev}
NS=platform
ROOT=$(cd "$(dirname "$0")/.." && pwd)
K="kubectl -n $NS"

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
TAG=$(git -C "$SRC" rev-parse --short=12 HEAD)
IMAGE="$REGISTRY/$APP:$TAG"

echo "== Image $IMAGE"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
if aws ecr describe-images --region "$REGION" --repository-name "$APP" --image-ids imageTag="$TAG" >/dev/null 2>&1; then
  echo "already in ECR (tags are immutable)"
else
  docker build -t "$IMAGE" "$SRC"
  docker push "$IMAGE"
fi

echo "== Kubernetes"
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
kubectl apply -f "$ROOT/k8s/namespace.yaml"

# Every key of the Secrets Manager JSON becomes an env var of the pods (through a Kubernetes Secret).
SECRET_JSON=$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "platform-dev/$APP" --query SecretString --output text)
mapfile -t LITERALS < <(jq -r 'to_entries[] | "--from-literal=\(.key)=\(.value)"' <<<"$SECRET_JSON")
kubectl create secret generic "$APP" "${LITERALS[@]}" --dry-run=client -o yaml | $K apply -f -

case "$APP" in
  payflow-ledger)   CONFIG=(--from-literal=PAYFLOW_OUTBOX_RELAY_ENABLED=true) ;;
  telemetry-stream) CONFIG=(--from-literal=CONSUMER_THREADS=2 --from-literal=SPRING_PROFILES_ACTIVE=json) ;;
esac
kubectl create configmap "$APP" "${CONFIG[@]}" --dry-run=client -o yaml | $K apply -f -

$K apply -f "$ROOT/k8s/$APP/"
# On AWS the Service gets a load balancer; the manifest stays ClusterIP for kind.
$K patch service "$APP" -p '{"spec":{"type":"LoadBalancer"}}'
$K set image "deploy/$APP" app="$IMAGE"
# Restart so pods pick up changed config/secrets even when the image is the same.
$K rollout restart "deploy/$APP"
if ! $K rollout status "deploy/$APP" --timeout=8m; then
  echo "Rollout failed, rolling back" >&2
  $K rollout undo "deploy/$APP"
  exit 1
fi
echo "URL: http://$($K get service "$APP" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
