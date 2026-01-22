#!/bin/bash
# Setup script for Terraform S3 backend
# Run this before using the Terraform configuration

set -e

echo "========================================="
echo "  Terraform Backend Setup"
echo "========================================="
echo ""

# Check if backend-config.hcl already exists
if [ -f "backend-config.hcl" ]; then
    echo "  backend-config.hcl already exists"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! \ =~ ^[Yy]\$ ]]; then
        echo "Exiting without changes"
        exit 0
    fi
fi

# Generate unique bucket name
BUCKET_NAME="terraform-state-\ashishdell\ashis-\"
REGION="us-east-1"
TABLE_NAME="terraform-state-lock"

echo "Creating S3 bucket: \"

# Create S3 bucket
aws s3 mb s3://\ --region \

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket \ \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket \ \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket \ \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Creating DynamoDB table: \"

# Create DynamoDB table
aws dynamodb create-table \
  --table-name \ \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region \

# Wait for table
aws dynamodb wait table-exists --table-name \

# Create backend-config.hcl
cat > backend-config.hcl << EOF
# Terraform Backend Configuration
# Generated: \01/19/2026 16:01:43
# This file is not committed to Git

bucket = "\"

# Optional overrides (uncomment to use)
# region         = "\"
# encrypt        = true
# dynamodb_table = "\"
EOF

echo ""
echo "========================================="
echo " Setup Complete!"
echo "========================================="
echo ""
echo "S3 Bucket:       \"
echo "DynamoDB Table:  \"
echo "Region:          \"
echo ""
echo "Backend config saved to: backend-config.hcl"
echo ""
echo "Next steps:"
echo "  1. Run: terraform init -backend-config=backend-config.hcl"
echo "  2. Run: terraform plan"
echo "  3. Run: terraform apply"
echo ""