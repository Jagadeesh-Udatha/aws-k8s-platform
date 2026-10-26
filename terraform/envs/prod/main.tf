# Prod: three AZs with a NAT gateway each, on-demand nodes, Multi-AZ Postgres, 3-broker MSK, deletion protection.
module "platform" {
  source = "../../platform"

  env    = "prod"
  region = var.region

  vpc_cidr           = "10.30.0.0/16"
  az_count           = 3
  single_nat_gateway = false

  admin_cidrs         = var.admin_cidrs
  node_instance_types = ["m6i.large"]
  capacity_type       = "ON_DEMAND"
  node_min            = 3
  node_max            = 9
  node_desired        = 3

  db_instance_class = "db.m7g.large"
  db_multi_az       = true

  kafka_broker_count  = 3
  kafka_instance_type = "kafka.m7g.large"
  kafka_volume_gb     = 200

  deletion_protection = true
}
