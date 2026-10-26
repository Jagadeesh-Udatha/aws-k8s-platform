# State lives in S3 with native lock files (Terraform >= 1.10, no DynamoDB table needed).
# terraform init -backend-config=backend.hcl   (copy backend.hcl.example and fill in your bucket)
terraform {
  backend "s3" {}
}
