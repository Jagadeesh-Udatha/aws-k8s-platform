# EKS control plane + one managed node group in the private subnets.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name    = var.name
  cluster_version = var.kubernetes_version

  # Public API endpoint limited to admin CIDRs; nodes talk to it privately.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.admin_cidrs
  cluster_endpoint_private_access      = true

  # Access entries (not the aws-auth ConfigMap). Whoever runs Terraform becomes cluster admin.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    eks-pod-identity-agent = {}
    vpc-cni = {
      before_compute = true # CNI must exist before nodes join, or pods get no IPs
    }
  }

  eks_managed_node_groups = {
    apps = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.capacity_type # SPOT in dev, ON_DEMAND in prod

      min_size     = var.node_min
      max_size     = var.node_max
      desired_size = var.node_desired

      labels = { workload = "apps" }

      # Rolling node upgrades replace a third of the group at a time; the app PDBs keep services up.
      update_config = { max_unavailable_percentage = 33 }
    }
  }

  # Only the cluster security group may carry the kubernetes.io/cluster tag: if two SGs on a node have it,
  # the AWS Load Balancer Controller can't decide which one to open for the ALB.
  # (Managed node groups tag their Auto Scaling groups for cluster-autoscaler discovery on their own.)
  node_security_group_tags = { "kubernetes.io/cluster/${var.name}" = null }

  tags = var.tags
}
