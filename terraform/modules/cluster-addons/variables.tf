variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "secret_arns" {
  description = "Secrets Manager ARNs External Secrets Operator may read."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
