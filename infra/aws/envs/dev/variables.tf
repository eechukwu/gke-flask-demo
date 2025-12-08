# --------------------------------------------------------------------------------------------------
# Global / common variables
# --------------------------------------------------------------------------------------------------

variable "project_name" {
  description = "Project name for tagging and resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
}

# --------------------------------------------------------------------------------------------------
# VPC / networking
# --------------------------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability Zones to spread subnets across"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs (bastion / ALB etc.)"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs (app / DB etc.)"
  type        = list(string)
}

# --------------------------------------------------------------------------------------------------
# Bastion EC2 instance
# --------------------------------------------------------------------------------------------------

variable "bastion_instance_type" {
  description = "Instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the bastion"
  type        = list(string)
}

variable "bastion_enable_http" {
  description = "Whether to open HTTP (80) on the bastion SG for test web access"
  type        = bool
  default     = true
}

variable "allowed_http_cidr" {
  description = "CIDR allowed to reach the public ALB over HTTP"
  type        = string
  default     = "0.0.0.0/0"
}

# App EC2/ASG settings
variable "app_instance_type" {
  description = "Instance type for the app servers"
  type        = string
  default     = "t3.micro"
}

variable "app_asg_min_size" {
  description = "Minimum number of app instances in ASG"
  type        = number
  default     = 1
}

variable "app_asg_max_size" {
  description = "Maximum number of app instances in ASG"
  type        = number
  default     = 2
}

variable "app_asg_desired_capacity" {
  description = "Desired number of app instances in ASG"
  type        = number
  default     = 1
}

variable "app_asg_cpu_target" {
  description = "Target average CPU utilisation for the app ASG"
  type        = number
  default     = 40
}

# Target average CPU % for the app ASG
variable "app_cpu_target" {
  description = "Target average CPU utilization (%) for the app Auto Scaling Group"
  type        = number
  default     = 50
}