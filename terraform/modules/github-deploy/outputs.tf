output "role_arn" {
  description = "Put this in the GitHub environment variable AWS_DEPLOY_ROLE_ARN."
  value       = aws_iam_role.deploy.arn
}
