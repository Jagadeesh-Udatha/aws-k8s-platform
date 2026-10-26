variable "repositories" {
  type = list(string)
}

variable "keep_images" {
  type    = number
  default = 30
}

variable "force_delete" {
  description = "Allow terraform destroy to remove repositories that still hold images (dev only)."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
