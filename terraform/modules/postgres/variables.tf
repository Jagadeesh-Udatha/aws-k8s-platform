variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "client_security_group_id" {
  description = "Security group allowed to connect (the EKS node group)."
  type        = string
}

variable "database" {
  type    = string
  default = "payflow"
}

variable "username" {
  type    = string
  default = "payflow"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 100
}

variable "multi_az" {
  description = "Synchronous standby in a second AZ with automatic failover."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
