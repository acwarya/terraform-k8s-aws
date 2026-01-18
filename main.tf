# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  subnet_cidr  = var.subnet_cidr
  aws_region   = var.aws_region
}

# Generate SSH key
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.k8s_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/${var.ssh_key_name}.pem"
  file_permission = "0600"
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Master Node
resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  vpc_security_group_ids = [module.vpc.security_group_id]
  subnet_id              = module.vpc.subnet_id
  private_ip             = var.master_private_ip

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/scripts/master-init.sh", {
    master_ip = var.master_private_ip
  })

  tags = {
    Name = "${var.cluster_name}-master"
    Role = "master"
  }
}

# Worker Nodes
resource "aws_instance" "k8s_workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.k8s_key.key_name
  vpc_security_group_ids = [module.vpc.security_group_id]
  subnet_id              = module.vpc.subnet_id
  private_ip             = "${var.worker_ip_prefix}${11 + count.index}"

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/scripts/worker-init.sh", {
    worker_id = count.index + 1
    master_ip = var.master_private_ip
  })

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }

  depends_on = [aws_instance.k8s_master]
}

# Outputs
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "master_public_ip" {
  value       = aws_instance.k8s_master.public_ip
  description = "Public IP of the master node"
}

output "worker_public_ips" {
  value       = aws_instance.k8s_workers[*].public_ip
  description = "Public IPs of worker nodes"
}

output "ssh_key_path" {
  value = "${path.module}/${var.ssh_key_name}.pem"
}

output "ssh_command_master" {
  value = "ssh -i ${path.module}/${var.ssh_key_name}.pem ubuntu@${aws_instance.k8s_master.public_ip}"
}

output "connection_info" {
  value = <<-EOT
  
  ========================================
  Kubernetes Cluster Setup Complete!
  ========================================
  
  VPC ID: ${module.vpc.vpc_id}
  SSH Key: ${path.module}/${var.ssh_key_name}.pem
  
  Master Node: ${aws_instance.k8s_master.public_ip}
  Worker 1:    ${aws_instance.k8s_workers[0].public_ip}
  Worker 2:    ${aws_instance.k8s_workers[1].public_ip}
  
  Connect to master:
  ssh -i ${path.module}/${var.ssh_key_name}.pem ubuntu@${aws_instance.k8s_master.public_ip}
  
  Check cluster status:
  kubectl get nodes
  kubectl get pods -A
  
  Note: The cluster setup takes 10-15 minutes to fully complete.
  All nodes will join automatically!
  
  ========================================
  EOT
}