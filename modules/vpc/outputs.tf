# modules/vpc/outputs.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.k8s_vpc.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = aws_subnet.k8s_subnet.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.k8s_sg.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.k8s_vpc.cidr_block
}