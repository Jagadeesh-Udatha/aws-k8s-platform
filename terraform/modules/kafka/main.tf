# Amazon MSK for both services: TLS between clients and brokers, encrypted at rest, one broker per AZ (or a multiple).
resource "aws_security_group" "msk" {
  name_prefix = "${var.name}-msk-"
  description = "Kafka TLS from EKS nodes only"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "tls_from_nodes" {
  security_group_id            = aws_security_group.msk.id
  referenced_security_group_id = var.client_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 9094
  to_port                      = 9094
  description                  = "Kafka TLS from EKS nodes"
}

resource "aws_msk_configuration" "this" {
  name           = "${var.name}-config"
  kafka_versions = [var.kafka_version]

  # Telemetry and PayFlow create their topics at startup (KafkaAdmin), so auto-create stays off.
  server_properties = <<-EOT
    auto.create.topics.enable=false
    default.replication.factor=${min(3, var.broker_count)}
    min.insync.replicas=${var.broker_count >= 3 ? 2 : 1}
    unclean.leader.election.enable=false
    log.retention.hours=168
  EOT
}

resource "aws_cloudwatch_log_group" "broker" {
  name              = "/msk/${var.name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_msk_cluster" "this" {
  cluster_name           = var.name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.broker_count

  broker_node_group_info {
    instance_type   = var.instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.volume_size_gb
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  # Network isolation is the access control here (private subnets + the SG above).
  # Next step for prod: IAM auth (port 9098) so each service's IRSA role gets topic-level permissions.
  client_authentication {
    unauthenticated = true
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.broker.name
      }
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.broker_count % length(var.subnet_ids) == 0
      error_message = "MSK needs the broker count to be a multiple of the number of subnets (AZs)."
    }
  }
}
