output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets in the dev VPC"
  value       = module.vpc.public_subnets
}

output "bastion_public_ip" {
  description = "Public IP of the bastion/test EC2 instance"
  value       = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  description = "Private IP of the app server"
  value       = aws_instance.app.private_ip
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}