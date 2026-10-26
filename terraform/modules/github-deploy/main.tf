# Role that GitHub Actions assumes through OIDC (no long-lived AWS keys in GitHub).
# It can push images to this env's ECR repos and run Helm in one namespace — nothing else.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only workflow jobs bound to this GitHub environment (which can require a reviewer for prod).
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${var.env}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${var.cluster_name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
  tags                 = var.tags
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = var.ecr_repository_arns
  }
  statement {
    sid       = "FindCluster"
    actions   = ["eks:DescribeCluster"]
    resources = [var.cluster_arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# Kubernetes side: an EKS access entry with the built-in edit policy, scoped to the app namespace only.
resource "aws_eks_access_entry" "deploy" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.deploy.arn
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "deploy" {
  cluster_name  = var.cluster_name
  principal_arn = aws_eks_access_entry.deploy.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.namespace]
  }
}
