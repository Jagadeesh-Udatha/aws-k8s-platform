# VPC across 2-3 AZs: public subnets for the ALB, private subnets for EKS nodes and pods,
# isolated database subnets for RDS and MSK.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name = var.name
  cidr = var.cidr
  azs  = local.azs

  # /20 private subnets: the VPC CNI gives every pod a VPC IP, so pods need room.
  private_subnets  = [for i, _ in local.azs : cidrsubnet(var.cidr, 4, i)]
  public_subnets   = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, 48 + i)]
  database_subnets = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, 56 + i)]

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway # dev: one NAT to save cost; prod: one per AZ
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags the AWS Load Balancer Controller uses to find subnets for internet-facing and internal ALBs.
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }

  tags = var.tags
}
