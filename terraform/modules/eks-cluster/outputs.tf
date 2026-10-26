output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "For IRSA roles (service account -> IAM role)."
  value       = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  description = "Security group of the worker nodes; RDS and MSK allow traffic from it."
  value       = module.eks.node_security_group_id
}
