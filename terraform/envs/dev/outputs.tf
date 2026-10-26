output "cluster_name" {
  value = module.platform.cluster_name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.platform.cluster_name} --region ${var.region}"
}

output "ecr_repository_urls" {
  value = module.platform.ecr_repository_urls
}

output "github_deploy_role_arn" {
  value = module.platform.github_deploy_role_arn
}
