#!/usr/bin/env bash
# One-time AWS setup for the dev environment, using eksctl and the AWS CLI:
#   EKS cluster -> ECR repositories -> RDS for MySQL -> Amazon MSK (Kafka) -> secrets in AWS Secrets Manager.
# MongoDB runs on MongoDB Atlas; paste its connection string when asked.
# COST: EKS, NAT, RDS and MSK are billed by the hour. Run aws/destroy.sh when you are done.
set -euo pipefail
REGION=${AWS_REGION:-ap-south-1}
CLUSTER=platform-dev
ROOT=$(cd "$(dirname "$0")/.." && pwd)
aws() { command aws --region "$REGION" "$@"; }

echo "== EKS"
eksctl create cluster -f "$ROOT/aws/cluster.yaml"
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query cluster.resourcesVpcConfig.vpcId --output text)
NODE_SG=$(aws eks describe-cluster --name "$CLUSTER" --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)
PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query 'Subnets[].SubnetId' --output text)

echo "== ECR"
for app in payflow-ledger telemetry-stream; do
  aws ecr create-repository --repository-name "$app" --image-tag-mutability IMMUTABLE \
    --image-scanning-configuration scanOnPush=true >/dev/null 2>&1 || echo "ECR repo $app already exists"
done

echo "== Security group for MySQL and Kafka (only the EKS nodes can connect)"
DATA_SG=$(aws ec2 create-security-group --group-name platform-dev-data --description "RDS + MSK for platform-dev" \
  --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$DATA_SG" --protocol tcp --port 3306 --source-group "$NODE_SG"
aws ec2 authorize-security-group-ingress --group-id "$DATA_SG" --protocol tcp --port 9092 --source-group "$NODE_SG"

echo "== RDS for MySQL 8.4 (private, encrypted)"
DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')
# shellcheck disable=SC2086
aws rds create-db-subnet-group --db-subnet-group-name platform-dev --db-subnet-group-description platform-dev \
  --subnet-ids $PRIVATE_SUBNETS >/dev/null
aws rds create-db-instance --db-instance-identifier platform-dev-mysql --engine mysql --engine-version 8.4 \
  --db-instance-class db.t4g.micro --allocated-storage 20 --storage-encrypted \
  --db-name payflow --master-username payflow --master-user-password "$DB_PASSWORD" \
  --db-subnet-group-name platform-dev --vpc-security-group-ids "$DATA_SG" --no-publicly-accessible \
  --backup-retention-period 1 >/dev/null

echo "== Amazon MSK (2 brokers, one per AZ)"
read -r -a SUBNET_ARRAY <<<"$PRIVATE_SUBNETS"
MSK_ARN=$(aws kafka create-cluster --cluster-name platform-dev --kafka-version 3.8.x --number-of-broker-nodes 2 \
  --broker-node-group-info "{\"InstanceType\":\"kafka.t3.small\",\"ClientSubnets\":[\"${SUBNET_ARRAY[0]}\",\"${SUBNET_ARRAY[1]}\"],\"SecurityGroups\":[\"$DATA_SG\"],\"StorageInfo\":{\"EbsStorageInfo\":{\"VolumeSize\":20}}}" \
  --encryption-info '{"EncryptionInTransit":{"ClientBroker":"TLS_PLAINTEXT","InCluster":true}}' \
  --query ClusterArn --output text)

echo "== Waiting for RDS and MSK (15-30 minutes)"
aws rds wait db-instance-available --db-instance-identifier platform-dev-mysql
DB_HOST=$(aws rds describe-db-instances --db-instance-identifier platform-dev-mysql --query 'DBInstances[0].Endpoint.Address' --output text)
until [ "$(aws kafka describe-cluster --cluster-arn "$MSK_ARN" --query ClusterInfo.State --output text)" = ACTIVE ]; do sleep 30; done
KAFKA=$(aws kafka get-bootstrap-brokers --cluster-arn "$MSK_ARN" --query BootstrapBrokerString --output text)

echo "== Secrets Manager"
read -r -p "MongoDB Atlas connection string for telemetry-stream: " MONGO_URI
aws secretsmanager create-secret --name platform-dev/payflow-ledger --secret-string "$(jq -nc \
  --arg url "jdbc:mysql://$DB_HOST:3306/payflow" --arg pw "$DB_PASSWORD" --arg kafka "$KAFKA" \
  --arg jwt "$(openssl rand -hex 32)" --arg ops "$(openssl rand -hex 12)" --arg aud "$(openssl rand -hex 12)" \
  '{DB_URL:$url, DB_USER:"payflow", DB_PASSWORD:$pw, KAFKA_BOOTSTRAP:$kafka,
    PAYFLOW_JWT_SECRET:$jwt, PAYFLOW_OPS_PASSWORD:$ops, PAYFLOW_AUDITOR_PASSWORD:$aud}')" >/dev/null
aws secretsmanager create-secret --name platform-dev/telemetry-stream --secret-string "$(jq -nc \
  --arg kafka "$KAFKA" --arg mongo "$MONGO_URI" '{KAFKA_BOOTSTRAP:$kafka, MONGO_URI:$mongo}')" >/dev/null

echo "Done. Deploy with: aws/deploy.sh payflow-ledger ../payflow-ledger"
