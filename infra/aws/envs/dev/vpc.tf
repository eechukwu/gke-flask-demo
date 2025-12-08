module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  # AZs to spread subnets across
  azs = var.azs

  # Public subnets (for bastion, ALB, etc.)
  public_subnets = var.public_subnets

  # 🔹 NEW: Private subnets (for app/DB later)
  private_subnets = var.private_subnets

  # 🔹 NEW: NAT so private subnets can talk OUT to the internet
  enable_nat_gateway = true
  single_nat_gateway = true

  # Public subnets automatically get public IPs on launch
  map_public_ip_on_launch = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}