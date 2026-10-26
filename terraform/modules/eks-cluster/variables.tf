variable "name" {
  description = "Cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API (office VPN, CI runners)."
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "Don't open the Kubernetes API to the whole internet."
  }
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min" {
  type    = number
  default = 3
}

variable "node_max" {
  type    = number
  default = 9
}

variable "node_desired" {
  type    = number
  default = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
