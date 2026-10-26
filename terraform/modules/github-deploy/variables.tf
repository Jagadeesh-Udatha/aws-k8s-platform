variable "env" {
  type = string
}

variable "github_repo" {
  description = "owner/name of the repository whose workflows may deploy."
  type        = string
}

variable "create_oidc_provider" {
  description = "The GitHub OIDC provider is one per AWS account: create it in the first env, look it up in the rest."
  type        = bool
  default     = false
}

variable "cluster_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "ecr_repository_arns" {
  type = list(string)
}

variable "namespace" {
  type    = string
  default = "platform"
}

variable "tags" {
  type    = map(string)
  default = {}
}
