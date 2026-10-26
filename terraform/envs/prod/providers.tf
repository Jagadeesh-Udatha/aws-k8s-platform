provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "aws-k8s-platform" }
  }
}

# Helm talks to the cluster this same root creates; the token comes from the AWS CLI at plan/apply time.
provider "helm" {
  kubernetes {
    host                   = module.platform.cluster_endpoint
    cluster_ca_certificate = base64decode(module.platform.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.platform.cluster_name, "--region", var.region]
    }
  }
}
