# Kubernetes Cluster on AWS - Terraform

Deploy a production-ready Kubernetes cluster on AWS using free-tier resources with S3 backend for state management.

## Features

-  1 Master Node (t3.micro, 2GB RAM)
-  2 Worker Nodes (t3.micro, 1GB RAM each)
-  Custom VPC (10.0.0.0/16)
-  S3 backend for persistent state
-  DynamoDB state locking
-  Fully automated with Jenkins
-  Free tier optimized

## Quick Start

### Prerequisites

- AWS Account
- AWS CLI configured
- Terraform >= 1.0

### 1. Create Your S3 Backend

Each user needs their own S3 bucket for state storage.

**Option A: Use the Setup Script (Easiest)**
```powershell
.\setup-backend.ps1
```

**Option B: Manual Setup**

PowerShell:
```powershell
$BUCKET = "terraform-state-$env:USERNAME-$(Get-Date -Format 'yyyyMMddHHmmss')"
aws s3 mb s3://$BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket $BUCKET --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws dynamodb create-table --table-name terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1
Write-Host "Your bucket: $BUCKET"
```

### 2. Configure Backend
```bash
# Copy the example
cp backend-config.hcl.example backend-config.hcl

# Edit with your bucket name
notepad backend-config.hcl
```

Add your bucket name:
```hcl
bucket = "terraform-state-yourname-123456789"
```

 **Important:** `backend-config.hcl` is in `.gitignore` and will NOT be committed.

### 3. Deploy
```bash
terraform init -backend-config=backend-config.hcl
terraform plan
terraform apply
```

### 4. Access Cluster
```bash
terraform output master_public_ip
ssh -i <cluster-name>.pem ubuntu@<master-ip>
kubectl get nodes
```

## Architecture
```
VPC (10.0.0.0/16)
 Public Subnet (10.0.1.0/24)
    Master Node (10.0.1.10)
    Worker Node 1 (10.0.1.11)
    Worker Node 2 (10.0.1.12)
 Internet Gateway
 Security Groups
```

## State Management

### Why S3 Backend?

- **Persistence**: State survives ephemeral CI/CD environments
- **Locking**: DynamoDB prevents concurrent modifications
- **Versioning**: Recover from mistakes
- **Security**: Each user has their own isolated state

### Backend Files

| File | Purpose | In Git? |
|------|---------|---------|
| `backend.tf` | Backend structure |  Yes |
| `backend-config.hcl.example` | Template |  Yes |
| `backend-config.hcl` | Your bucket |  No (.gitignore) |

## Configuration

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | us-east-1 | AWS region |
| `cluster_name` | my-k8s-cluster | Cluster name |
| `vpc_cidr` | 10.0.0.0/16 | VPC CIDR block |
| `worker_count` | 2 | Number of workers |

## CI/CD with Jenkins

This repo integrates with Jenkins pipelines for automated deployment.

**Pipeline Repo**: https://github.com/acwarya/jenkins-pipelines

## Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| EC2 (t3.micro  3) | ~$0 (free tier)* |
| EBS (50GB) | ~$2 |
| S3 (state) | ~$0 |
| DynamoDB | ~$0 |
| **Total** | **~$2-3** |

*First 750 hours free

## Cleanup
```bash
terraform destroy
aws s3 rm s3://your-bucket/k8s-cluster/terraform.tfstate
```

## Troubleshooting

### Backend not configured
```bash
terraform init -backend-config=backend-config.hcl -reconfigure
```

### State locked
```bash
terraform force-unlock <LOCK_ID>
```

## License

MIT License
