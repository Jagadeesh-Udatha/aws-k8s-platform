#!/usr/bin/env bash
# Delete everything aws/create.sh made (secrets are deleted without a recovery window).
set -euo pipefail
REGION=${AWS_REGION:-ap-south-1}
aws() { command aws --region "$REGION" "$@"; }

for app in payflow-ledger telemetry-stream; do
  kubectl -n platform delete service "$app" --ignore-not-found   # releases its load balancer first
  aws secretsmanager delete-secret --secret-id "platform-dev/$app" --force-delete-without-recovery || true
  aws ecr delete-repository --repository-name "$app" --force || true
done
MSK_ARN=$(aws kafka list-clusters --cluster-name-filter platform-dev --query 'ClusterInfoList[0].ClusterArn' --output text)
[ "$MSK_ARN" != None ] && aws kafka delete-cluster --cluster-arn "$MSK_ARN"
aws rds delete-db-instance --db-instance-identifier platform-dev-mysql --skip-final-snapshot || true
aws rds wait db-instance-deleted --db-instance-identifier platform-dev-mysql || true
aws rds delete-db-subnet-group --db-subnet-group-name platform-dev || true
until ! aws kafka describe-cluster --cluster-arn "$MSK_ARN" >/dev/null 2>&1; do sleep 30; done
SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=platform-dev-data --query 'SecurityGroups[0].GroupId' --output text)
[ "$SG" != None ] && aws ec2 delete-security-group --group-id "$SG"
eksctl delete cluster --name platform-dev --region "$REGION" --wait
