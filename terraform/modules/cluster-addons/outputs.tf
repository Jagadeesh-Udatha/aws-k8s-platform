output "irsa_role_arns" {
  value = {
    aws_lb_controller  = module.lb_controller_irsa.iam_role_arn
    external_secrets   = module.external_secrets_irsa.iam_role_arn
    cluster_autoscaler = module.cluster_autoscaler_irsa.iam_role_arn
  }
}
