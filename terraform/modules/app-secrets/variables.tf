variable "env" {
  type = string
}

variable "db_url" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "kafka_bootstrap" {
  type = string
}

variable "recovery_window_days" {
  description = "0 deletes immediately (dev); 7-30 keeps a restore window (prod)."
  type        = number
  default     = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
