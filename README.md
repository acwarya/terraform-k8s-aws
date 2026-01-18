# Kubernetes Cluster on AWS - Terraform

## Description
This repository contains Terraform configuration to deploy a Kubernetes cluster on AWS using free-tier resources.

## Architecture
- 1 Master Node (t3.micro)
- 2 Worker Nodes (t3.micro)
- Custom VPC with public subnet
- Security groups configured for Kubernetes

## Prerequisites
- AWS Account with credentials configured
- Terraform >= 1.0
- SSH key pair

## Usage

### 1. Configure Variables
`ash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
`

### 2. Deploy
`ash
terraform init
terraform plan
terraform apply
`

### 3. Access Cluster
`ash
ssh -i <key-name>.pem ubuntu@<master-ip>
kubectl get nodes
`

## Resources Created
- VPC and Subnet
- Internet Gateway
- Security Groups
- 3 EC2 Instances (1 master, 2 workers)
- SSH Key Pair

## Cleanup
`ash
terraform destroy
`

## Cost
Estimated cost: ~-3/month (storage only, instances covered by free tier)
