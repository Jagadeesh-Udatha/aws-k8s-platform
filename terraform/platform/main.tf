# One environment of the platform: network -> EKS -> data stores -> secrets -> add-ons -> CI access.
# envs/dev and envs/prod only differ in the inputs they pass here.
locals {
  name = "platform-${var.env}"
  tags = merge(var.tags, { Environment = var.env, ManagedBy = "terraform", Repo = var.github_repo })
}

module "network" {
  source             = "../modules/network"
  name               = local.name
  cidr               = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
  tags               = local.tags
}

module "eks" {
  source              = "../modules/eks-cluster"
  name                = local.name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  admin_cidrs         = var.admin_cidrs
  node_instance_types = var.node_instance_types
  capacity_type       = var.capacity_type
  node_min            = var.node_min
  node_max            = var.node_max
  node_desired        = var.node_desired
  tags                = local.tags
}

module "postgres" {
  source                   = "../modules/postgres"
  name                     = "${local.name}-payflow"
  vpc_id                   = module.network.vpc_id
  db_subnet_group_name     = module.network.database_subnet_group_name
  client_security_group_id = module.eks.node_security_group_id
  instance_class           = var.db_instance_class
  multi_az                 = var.db_multi_az
  deletion_protection      = var.deletion_protection
  tags                     = local.tags
}

module "kafka" {
  source                   = "../modules/kafka"
  name                     = "${local.name}-msk"
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.database_subnet_ids
  client_security_group_id = module.eks.node_security_group_id
  broker_count             = var.kafka_broker_count
  instance_type            = var.kafka_instance_type
  volume_size_gb           = var.kafka_volume_gb
  tags                     = local.tags
}

module "ecr" {
  source       = "../modules/ecr"
  repositories = [for app in var.apps : "${var.env}/${app}"]
  force_delete = !var.deletion_protection
  tags         = local.tags
}

module "app_secrets" {
  source               = "../modules/app-secrets"
  env                  = var.env
  db_url               = module.postgres.jdbc_url
  db_user              = module.postgres.username
  db_password          = module.postgres.password
  kafka_bootstrap      = module.kafka.bootstrap_brokers_tls
  recovery_window_days = var.deletion_protection ? 7 : 0
  tags                 = local.tags
}

module "addons" {
  source            = "../modules/cluster-addons"
  cluster_name      = module.eks.cluster_name
  region            = var.region
  vpc_id            = module.network.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  secret_arns       = module.app_secrets.secret_arns
  tags              = local.tags
}

module "github_deploy" {
  source               = "../modules/github-deploy"
  env                  = var.env
  github_repo          = var.github_repo
  create_oidc_provider = var.create_github_oidc_provider
  cluster_name         = module.eks.cluster_name
  cluster_arn          = module.eks.cluster_arn
  ecr_repository_arns  = module.ecr.repository_arns
  tags                 = local.tags
}
