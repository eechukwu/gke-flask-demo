###########################
# Bastion EC2 + Security
###########################

# Latest Amazon Linux 2023 in this region
data "aws_ami" "amazon_linux_2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Security group for bastion host
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Bastion SSH/HTTP access"
  vpc_id      = module.vpc.vpc_id

  # SSH access (22) from allowed CIDRs
  dynamic "ingress" {
    for_each = var.bastion_allowed_ssh_cidrs
    content {
      description = "SSH from allowed CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Optional HTTP access (80) from same CIDRs (to test nginx in browser)
  dynamic "ingress" {
    for_each = var.bastion_enable_http ? var.bastion_allowed_ssh_cidrs : []
    content {
      description = "HTTP from allowed CIDR"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Outbound: allow all (typical for bastion)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Bastion EC2 instance in the first public subnet
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.bastion_instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  associate_public_ip_address = true

  # OPTIONAL: if you have an EC2 key pair, uncomment and set in tfvars
  # key_name = var.bastion_key_name

  user_data = <<-EOT
              #!/bin/bash
              yum update -y

              # Install nginx
              yum install -y nginx

              systemctl enable nginx
              systemctl start nginx

              echo "<h1>DevOps Interview Lab - Bastion (Environment: ${var.environment})</h1>" > /usr/share/nginx/html/index.html
              EOT

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Role        = "bastion"
  }
}