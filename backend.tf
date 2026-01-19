terraform {
  backend "s3" {
    bucket         = "terraform-state-k8s-ac-20260119155141"
    key            = "k8s-cluster/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
