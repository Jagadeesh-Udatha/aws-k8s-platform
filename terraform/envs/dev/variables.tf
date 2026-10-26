variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "admin_cidrs" {
  description = "Your public IP as x.x.x.x/32, plus CI runner ranges if they run kubectl."
  type        = list(string)
}
