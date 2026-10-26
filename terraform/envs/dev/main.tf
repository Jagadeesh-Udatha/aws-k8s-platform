# Dev: two AZs, one NAT gateway, spot nodes, smallest data tier, everything destroyable.
module "platform" {
  source = "../../platform"

  env                         = "dev"
  region                      = var.region
  create_github_oidc_provider = true # first env in the account creates it; prod looks it up

  vpc_cidr           = "10.20.0.0/16"
  az_count           = 2
  single_nat_gateway = true

  admin_cidrs         = var.admin_cidrs
  node_instance_types = ["m6i.large", "m5.large", "m6a.large"] # several types = better spot availability
  capacity_type       = "SPOT"
  node_min            = 2
  node_max            = 4
  node_desired        = 2

  db_instance_class = "db.t4g.micro"
  db_multi_az       = false

  kafka_broker_count  = 2
  kafka_instance_type = "kafka.t3.small"
  kafka_volume_gb     = 20

  deletion_protection = false
}
