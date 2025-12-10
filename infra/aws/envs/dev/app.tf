########################################
# App Security Group (private tier)
########################################
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "App server HTTP access from within VPC"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTP from anywhere inside the VPC CIDR
  # (e.g. bastion in 10.10.10.x -> app in 10.10.30.x)
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  # Outbound: allow all (so app can reach internet via NAT if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Name        = "${var.project_name}-${var.environment}-app-sg"
  }
}

########################################
# App EC2 instance in private subnet (COMMENTED OUT – REPLACED BY ASG)
########################################
/*
resource "aws_instance" "app" {
  ami                         = "ami-078182bbf5b33d14d" # Amazon Linux 2023 in eu-west-2
  instance_type               = var.app_instance_type
  subnet_id                   = module.vpc.private_subnets[0] # first private subnet
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = false # keep it private

  user_data_replace_on_change = true # Forces instance replacement when user_data changes

  user_data = <<-EOF
#!/bin/bash
set -eux
# Amazon Linux 2023 uses dnf
dnf update -y
dnf install -y nginx
cat > /usr/share/nginx/html/index.html << 'PAGE'
<html>
  <head><title>DevOps Interview Lab - App</title></head>
  <body>
    <h1>DevOps Interview Lab - App Server</h1>
    <p>Environment: ${var.environment}</p>
  </body>
</html>
PAGE
systemctl enable nginx
systemctl start nginx
EOF

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Name        = "${var.project_name}-${var.environment}-app"
    Role        = "app"
  }
}
*/

########################################
# App Auto Scaling Policy (CPU-based)
########################################

resource "aws_autoscaling_policy" "app_cpu_target" {
  name                   = "${var.project_name}-${var.environment}-app-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      # Use the built-in ASG CPU metric
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    # Try to keep average CPU around this value (percent)
    target_value = var.app_cpu_target
  }
}