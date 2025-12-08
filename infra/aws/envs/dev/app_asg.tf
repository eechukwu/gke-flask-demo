########################################
# App Launch Template for ASG
########################################

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-app-"
  image_id      = "ami-078182bbf5b33d14d" # same AMI as your current app instance
  instance_type = var.app_instance_type

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -eux

    yum update -y || true
    yum install -y nginx

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
    systemctl restart nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Name        = "${var.project_name}-${var.environment}-app"
      Role        = "app"
    }
  }
}

########################################
# App Auto Scaling Group
########################################

resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-${var.environment}-app-asg"
  max_size                  = var.app_asg_max_size
  min_size                  = var.app_asg_min_size
  desired_capacity          = var.app_asg_desired_capacity
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Attach to existing ALB target group
  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-app"
    propagate_at_launch = true
  }
}