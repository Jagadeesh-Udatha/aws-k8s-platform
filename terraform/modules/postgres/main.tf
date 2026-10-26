# RDS PostgreSQL for PayFlow: encrypted, TLS-only, reachable only from the EKS nodes.
resource "random_password" "master" {
  length  = 32
  special = false # avoids URL-escaping problems in the JDBC URL
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-pg-"
  description = "PostgreSQL from EKS nodes only"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_nodes" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = var.client_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "EKS nodes"
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-pg16-"
  family      = "postgres16"
  tags        = var.tags

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "500" # log queries slower than 500 ms
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  db_name  = var.database
  username = var.username
  password = random_password.master.result
  port     = 5432

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # storage autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.this.name
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_days
  backup_window                = "20:00-21:00" # 01:30-02:30 IST
  maintenance_window           = "sun:21:30-sun:22:30"
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  copy_tags_to_snapshot        = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name}-final" : null

  tags = var.tags
}
