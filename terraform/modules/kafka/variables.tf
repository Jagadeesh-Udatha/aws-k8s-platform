variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "One subnet per AZ (the database subnets)."
  type        = list(string)
}

variable "client_security_group_id" {
  type = string
}

variable "kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "broker_count" {
  type    = number
  default = 3
}

variable "instance_type" {
  type    = string
  default = "kafka.m7g.large"
}

variable "volume_size_gb" {
  type    = number
  default = 100
}

variable "tags" {
  type    = map(string)
  default = {}
}
