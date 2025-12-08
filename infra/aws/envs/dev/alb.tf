########################################
# ALB Security Group (public tier)
########################################

resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "ALB HTTP access from internet"
  vpc_id      = module.vpc.vpc_id

  # Inbound: HTTP from the internet (for now, 0.0.0.0/0)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  # Outbound: ALB → targets in VPC
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
    Name        = "${var.project_name}-${var.environment}-alb-sg"
  }
}

########################################
# Application Load Balancer (public)
########################################

resource "aws_lb" "app_alb" {
  # ALB name must be 3-32 chars, alnum + hyphen, so we lowercase it
  name               = "${lower(var.project_name)}-${var.environment}-alb"
  internal           = false # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets # ALB lives in public subnets

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Name        = "${var.project_name}-${var.environment}-alb"
  }
}

########################################
# Target Group for App EC2
########################################

resource "aws_lb_target_group" "app_tg" {
  # TG name also has a 32-character limit, so we truncate safely
  name        = substr("${lower(var.project_name)}-${var.environment}-tg", 0, 32)
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance" # We’re registering the EC2 instance directly

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Name        = "${var.project_name}-${var.environment}-app-tg"
  }
}

########################################
# HTTP Listener → forward to target group
########################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

########################################
# Attach private App EC2 to target group
########################################

#resource "aws_lb_target_group_attachment" "app_attachment" {
#  target_group_arn = aws_lb_target_group.app_tg.arn
#  target_id        = aws_instance.app.id
#  port             = 80
#}

