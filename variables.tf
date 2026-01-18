# variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "my-k8s-cluster"
}

variable "ssh_key_name" {
  description = "Name for the SSH key pair"
  type        = string
  default     = "k8s-cluster-key"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "master_instance_type" {
  description = "Instance type for master node"
  type        = string
  default     = "t3.micro"
}

variable "worker_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.micro"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "master_private_ip" {
  description = "Private IP for master node"
  type        = string
  default     = "10.0.1.10"
}

variable "worker_ip_prefix" {
  description = "IP prefix for worker nodes (e.g., 10.0.1.)"
  type        = string
  default     = "10.0.1."
}