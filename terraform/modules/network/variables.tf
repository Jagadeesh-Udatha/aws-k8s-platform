variable "name" {
  description = "Name prefix for the VPC and its resources."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block. A /16 leaves room for /20 pod subnets."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones (MSK needs the broker count to be a multiple of this)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "Use 2 or 3 availability zones."
  }
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheaper, single-AZ egress) instead of one per AZ."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for every resource."
  type        = map(string)
  default     = {}
}
