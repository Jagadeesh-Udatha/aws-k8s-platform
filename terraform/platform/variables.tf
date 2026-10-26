variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env is dev or prod."
  }
}

variable "region" {
  type = string
}

variable "github_repo" {
  type    = string
  default = "Jagadeesh-Udatha/aws-k8s-platform"
}

variable "create_github_oidc_provider" {
  type    = bool
  default = false
}

variable "apps" {
  type    = list(string)
  default = ["payflow-ledger", "telemetry-stream"]
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type = number
}

variable "single_nat_gateway" {
  type = bool
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "admin_cidrs" {
  type = list(string)
}

variable "node_instance_types" {
  type = list(string)
}

variable "capacity_type" {
  type = string
}

variable "node_min" {
  type = number
}

variable "node_max" {
  type = number
}

variable "node_desired" {
  type = number
}

variable "db_instance_class" {
  type = string
}

variable "db_multi_az" {
  type = bool
}

variable "kafka_broker_count" {
  type = number
}

variable "kafka_instance_type" {
  type = string
}

variable "kafka_volume_gb" {
  type = number
}

variable "deletion_protection" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}
