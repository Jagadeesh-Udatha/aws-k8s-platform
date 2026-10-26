output "secret_arns" {
  description = "Everything External Secrets Operator may read."
  value = [
    aws_secretsmanager_secret.payflow.arn,
    aws_secretsmanager_secret.telemetry.arn,
    aws_secretsmanager_secret.telemetry_mongo.arn,
  ]
}
