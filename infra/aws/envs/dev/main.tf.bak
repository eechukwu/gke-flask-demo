terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # We'll define this variable soon in variables.tf
  region = var.aws_region
}

# -----------------------------
# VPC using official AWS module
# -----------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # Name will show up on the VPC in AWS console
  name = "${var.project_name}-${var.environment}-vpc"

  # Whole network range for this VPC
  cidr = "10.10.0.0/16"

  # We'll use 2 AZs in the chosen region
  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b",
  ]

  # Two public subnets (one per AZ)
  public_subnets = [
    "10.10.10.0/24",
    "10.10.20.0/24",
  ]

  # Keep it simple for now: only public subnets, no NAT
  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
