module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = "${var.project_name}-${var.environment}-vpc"

  cidr = "10.10.0.0/16"

  azs = [
    "eu-west-2a",
    "eu-west-2b",
  ]

  public_subnets = [
    "10.10.10.0/24",
    "10.10.20.0/24",
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}