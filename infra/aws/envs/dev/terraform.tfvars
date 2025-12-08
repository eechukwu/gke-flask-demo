aws_region   = "eu-west-2"
project_name = "devOps-interview-lab"
environment  = "dev"

# Bastion
bastion_instance_type     = "t3.micro"
bastion_allowed_ssh_cidrs = ["0.0.0.0/0"]
bastion_enable_http       = true

# VPC & subnets
vpc_cidr        = "10.10.0.0/16"
azs             = ["eu-west-2a", "eu-west-2b"]
public_subnets  = ["10.10.10.0/24", "10.10.20.0/24"]
private_subnets = ["10.10.30.0/24", "10.10.40.0/24"]


# App (ASG)
app_instance_type        = "t3.micro"
app_asg_min_size         = 1
app_asg_max_size         = 2
app_asg_desired_capacity = 1

app_cpu_target = 40