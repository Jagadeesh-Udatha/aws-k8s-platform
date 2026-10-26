# Cluster add-ons installed with Helm. Each controller that calls AWS gets its own IAM role through IRSA,
# trusted only by its own Kubernetes service account.
locals {
  oidc = { provider_arn = var.oidc_provider_arn }
}

module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.55"

  role_name                              = "${var.cluster_name}-aws-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = merge(local.oidc, { namespace_service_accounts = ["kube-system:aws-load-balancer-controller"] })
  }
  tags = var.tags
}

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.55"

  role_name                             = "${var.cluster_name}-external-secrets"
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = var.secret_arns # read-only, only these secrets
  external_secrets_ssm_parameter_arns   = []

  oidc_providers = {
    main = merge(local.oidc, { namespace_service_accounts = ["external-secrets:external-secrets"] })
  }
  tags = var.tags
}

module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.55"

  role_name                        = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]

  oidc_providers = {
    main = merge(local.oidc, { namespace_service_accounts = ["kube-system:cluster-autoscaler"] })
  }
  tags = var.tags
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.11.0"

  values = [yamlencode({
    clusterName  = var.cluster_name
    region       = var.region
    vpcId        = var.vpc_id
    replicaCount = 2
    serviceAccount = {
      name        = "aws-load-balancer-controller"
      annotations = { "eks.amazonaws.com/role-arn" = module.lb_controller_irsa.iam_role_arn }
    }
  })]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.17.0" # first release serving the external-secrets.io/v1 API used by the app chart

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      name        = "external-secrets"
      annotations = { "eks.amazonaws.com/role-arn" = module.external_secrets_irsa.iam_role_arn }
    }
  })]
}

# The ClusterSecretStore needs the CRDs from the release above, so it ships as its own tiny chart.
resource "helm_release" "secret_store" {
  name      = "aws-secret-store"
  namespace = "external-secrets"
  chart     = "${path.module}/charts/secret-store"

  values = [yamlencode({
    region         = var.region
    serviceAccount = { name = "external-secrets", namespace = "external-secrets" }
  })]

  depends_on = [helm_release.external_secrets]
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.43.2"

  values = [yamlencode({
    awsRegion     = var.region
    autoDiscovery = { clusterName = var.cluster_name }
    rbac = {
      serviceAccount = {
        name        = "cluster-autoscaler"
        annotations = { "eks.amazonaws.com/role-arn" = module.cluster_autoscaler_irsa.iam_role_arn }
      }
    }
    extraArgs = {
      balance-similar-node-groups   = true
      skip-nodes-with-local-storage = false
      expander                      = "least-waste"
    }
  })]
}
