output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "github_deploy_role_arn" {
  value = module.github_deploy.role_arn
}

output "postgres_address" {
  value = module.postgres.address
}

output "kafka_bootstrap_brokers_tls" {
  value = module.kafka.bootstrap_brokers_tls
}

output "irsa_role_arns" {
  value = module.addons.irsa_role_arns
}
