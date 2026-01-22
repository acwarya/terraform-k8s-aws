# Backend configuration for Terraform state storage
# The bucket name is provided at runtime via backend-config file or CLI
# This allows each user to use their own S3 bucket

terraform {
  backend "s3" {
    # Bucket name will be provided via:
    # 1. backend-config.hcl file (recommended for CI/CD)
    # 2. terraform init -backend-config="bucket=my-bucket"
    # 3. Environment variables
    
    key            = "k8s-cluster/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
