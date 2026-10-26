# App configuration secrets in AWS Secrets Manager. External Secrets Operator copies them into
# Kubernetes Secrets (see deploy/*/values-<env>.yaml), so no credential ever lands in git or Helm values.
resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "random_password" "ops" {
  length  = 24
  special = false
}

resource "random_password" "auditor" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "payflow" {
  name                    = "payflow/${var.env}"
  description             = "PayFlow ledger runtime config (${var.env})"
  recovery_window_in_days = var.recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "payflow" {
  secret_id = aws_secretsmanager_secret.payflow.id
  secret_string = jsonencode({
    db_url           = var.db_url
    db_user          = var.db_user
    db_password      = var.db_password
    kafka_bootstrap  = var.kafka_bootstrap
    jwt_secret       = random_password.jwt.result
    ops_password     = random_password.ops.result
    auditor_password = random_password.auditor.result
  })
}

resource "aws_secretsmanager_secret" "telemetry" {
  name                    = "telemetry/${var.env}"
  description             = "Telemetry stream runtime config (${var.env})"
  recovery_window_in_days = var.recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "telemetry" {
  secret_id     = aws_secretsmanager_secret.telemetry.id
  secret_string = jsonencode({ kafka_bootstrap = var.kafka_bootstrap })
}

# MongoDB runs on Atlas, outside this account. Terraform only creates the empty secret;
# the connection string is pasted in once:
#   aws secretsmanager put-secret-value --secret-id telemetry/<env>/mongo --secret-string '{"uri":"mongodb+srv://..."}'
resource "aws_secretsmanager_secret" "telemetry_mongo" {
  name                    = "telemetry/${var.env}/mongo"
  description             = "Atlas connection string for telemetry (${var.env}), set by hand"
  recovery_window_in_days = var.recovery_window_days
  tags                    = var.tags
}
