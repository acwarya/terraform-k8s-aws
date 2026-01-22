# Terraform S3 Backend Setup Script (PowerShell)
# This script creates an S3 bucket and DynamoDB table for Terraform state

param(
    [string]$Region = "us-east-1"
)

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Terraform Backend Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if backend-config.hcl exists
if (Test-Path "backend-config.hcl") {
    Write-Host "  backend-config.hcl already exists" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Exiting without changes" -ForegroundColor Yellow
        exit 0
    }
}

# Generate unique bucket name
$BucketName = "terraform-state-$env:USERNAME-$(Get-Date -Format 'yyyyMMddHHmmss')"
$TableName = "terraform-state-lock"

Write-Host "Creating S3 bucket: $BucketName" -ForegroundColor Yellow

# Create S3 bucket
aws s3 mb s3://$BucketName --region $Region

if ($LASTEXITCODE -ne 0) {
    Write-Host " Failed to create S3 bucket" -ForegroundColor Red
    exit 1
}

# Enable versioning
Write-Host "Enabling versioning..." -ForegroundColor Yellow
aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Enabled

# Block public access
Write-Host "Blocking public access..." -ForegroundColor Yellow
aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table
Write-Host "Creating DynamoDB table: $TableName" -ForegroundColor Yellow
aws dynamodb create-table --table-name $TableName --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $Region 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Waiting for DynamoDB table..." -ForegroundColor Yellow
    aws dynamodb wait table-exists --table-name $TableName
    Write-Host " DynamoDB table created" -ForegroundColor Green
} else {
    Write-Host "  DynamoDB table may already exist" -ForegroundColor Yellow
}

# Create backend-config.hcl
@"
bucket = "$BucketName"
"@ | Out-File -FilePath backend-config.hcl -Encoding UTF8

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "   Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "S3 Bucket:       $BucketName" -ForegroundColor Yellow
Write-Host "DynamoDB Table:  $TableName" -ForegroundColor Yellow
Write-Host "Region:          $Region" -ForegroundColor Yellow
Write-Host ""
Write-Host "Backend config saved to: backend-config.hcl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. terraform init -backend-config=backend-config.hcl" -ForegroundColor White
Write-Host "  2. terraform plan" -ForegroundColor White
Write-Host "  3. terraform apply" -ForegroundColor White
Write-Host ""
