# Part 3: Bastion Host
## Your Secure Gateway to Private Resources

---

## 📋 Table of Contents

| Section | Description |
|---------|-------------|
| [1. What is a Bastion?](#1-what-is-a-bastion) | Why it exists and what it does |
| [2. bastion.tf Code](#2-bastiontf---the-code) | Complete file breakdown |
| [3. AMI Data Source](#3-ami-data-source) | Finding the right Amazon image |
| [4. Security Group](#4-security-group) | Controlling access (SSH & HTTP) |
| [5. Dynamic Blocks](#5-dynamic-blocks-explained) | Terraform looping magic |
| [6. EC2 Instance](#6-ec2-instance) | The actual server |
| [7. User Data Script](#7-user-data-script) | Bootstrap automation |
| [8. Traffic Flow](#8-traffic-flow) | How connections work |
| [9. Interview Questions](#9-interview-questions) | Key concepts to remember |

---

## 1. What is a Bastion?

### The Problem

```
┌─────────────────────────────────────────────────────────────────┐
│                     THE PROBLEM                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Your app servers are in PRIVATE subnets (no public IP)        │
│                                                                  │
│   YOU (Admin)                         APP SERVER                 │
│   ┌─────────┐                        ┌─────────┐                │
│   │  💻     │                        │ 🖥️      │                │
│   │ Laptop  │ ──────── ??? ────────► │ Private │                │
│   │         │                        │ 10.10.30│                │
│   └─────────┘                        └─────────┘                │
│                                                                  │
│   ❌ You CAN'T SSH directly - no public IP!                     │
│   ❌ You CAN'T reach it from the internet!                      │
│                                                                  │
│   How do you manage, debug, or access your app servers?         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### The Solution: Bastion Host

```
┌─────────────────────────────────────────────────────────────────┐
│                     THE SOLUTION                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   A BASTION (aka Jump Box) is a secure "stepping stone"         │
│                                                                  │
│   YOU (Admin)          BASTION              APP SERVER           │
│   ┌─────────┐        ┌─────────┐          ┌─────────┐           │
│   │  💻     │  SSH   │ 🔐      │   SSH    │ 🖥️      │           │
│   │ Laptop  │ ──────►│ Public  │ ────────►│ Private │           │
│   │         │  :22   │ 3.x.x.x │   :22    │ 10.10.30│           │
│   └─────────┘        └─────────┘          └─────────┘           │
│                                                                  │
│   STEP 1: SSH to bastion (public IP)                            │
│   STEP 2: From bastion, SSH to private server                   │
│                                                                  │
│   ✅ Private servers stay hidden from internet                  │
│   ✅ Only ONE entry point to secure                             │
│   ✅ All access is logged and auditable                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why Not Just Make App Servers Public?

| Approach | Security Risk | Management |
|----------|---------------|------------|
| App servers public | 🔴 HIGH - Direct attack surface | Easy but dangerous |
| Bastion + Private | 🟢 LOW - Single entry point | Slightly complex but secure |

**Think of it like a building:**
- ❌ Bad: Every office has a door to the street (many entry points)
- ✅ Good: One reception desk, then internal doors (controlled access)

---

## 2. bastion.tf - The Code

### Complete File

```hcl
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

  # Optional HTTP access (80) from same CIDRs
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

  # Outbound: allow all
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

  user_data = <<-EOT
              #!/bin/bash
              yum update -y
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
```

---

## 3. AMI Data Source

### The Code

```hcl
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
```

### What is a Data Source?

```
┌─────────────────────────────────────────────────────────────────┐
│              RESOURCE vs DATA SOURCE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   RESOURCE:                      DATA SOURCE:                    │
│   "CREATE something"             "FIND something that exists"    │
│                                                                  │
│   resource "aws_instance" {...}  data "aws_ami" {...}           │
│   → Creates a new EC2            → Finds an existing AMI        │
│                                                                  │
│   resource "aws_vpc" {...}       data "aws_vpc" {...}           │
│   → Creates a new VPC            → Finds an existing VPC        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why Not Hardcode the AMI?

```
┌─────────────────────────────────────────────────────────────────┐
│              HARDCODED vs DATA SOURCE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ❌ HARDCODED:                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ ami = "ami-078182bbf5b33d14d"                            │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│   Problems:                                                      │
│   • AMI IDs are REGION-SPECIFIC (won't work in us-east-1)      │
│   • AMI IDs change when Amazon releases security updates        │
│   • You must manually update the ID                             │
│                                                                  │
│   ─────────────────────────────────────────────────────────────  │
│                                                                  │
│   ✅ DATA SOURCE:                                                │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ data "aws_ami" "amazon_linux_2023" {                     │   │
│   │   owners      = ["amazon"]                               │   │
│   │   most_recent = true                                     │   │
│   │   filter { name = "name" values = ["al2023-ami-*"] }    │   │
│   │ }                                                        │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│   Benefits:                                                      │
│   • Automatically finds AMI in ANY region                       │
│   • Always gets the LATEST version (security patches!)          │
│   • No manual updates needed                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### How the Filter Works

```
data "aws_ami" "amazon_linux_2023" {
  owners      = ["amazon"]           # Only AMIs owned by Amazon
  most_recent = true                 # Get newest if multiple match

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Wildcard pattern matching
  }
  #         al2023-ami-*-x86_64
  #         ↓
  #         Matches: al2023-ami-2023.1.20231212.0-kernel-6.1-x86_64
  #         Matches: al2023-ami-2024.1.20240315.0-kernel-6.1-x86_64
  #         most_recent = true → picks the 2024 one

  filter {
    name   = "architecture"
    values = ["x86_64"]              # 64-bit Intel/AMD (not ARM)
  }
}
```

### Using the Data Source

```hcl
# Reference it like this:
resource "aws_instance" "bastion" {
  ami = data.aws_ami.amazon_linux_2023.id   # Gets the AMI ID
  # ...
}
```

---

## 4. Security Group

### The Code

```hcl
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Bastion SSH/HTTP access"
  vpc_id      = module.vpc.vpc_id

  # SSH ingress - dynamic block (explained below)
  dynamic "ingress" {
    for_each = var.bastion_allowed_ssh_cidrs
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # HTTP ingress - conditional dynamic block
  dynamic "ingress" {
    for_each = var.bastion_enable_http ? var.bastion_allowed_ssh_cidrs : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Egress - allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Visual: Security Group Rules

```
┌─────────────────────────────────────────────────────────────────┐
│                    BASTION SECURITY GROUP                        │
│              (devOps-interview-lab-dev-bastion-sg)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   INBOUND RULES (What can come IN):                             │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  Type    │ Port │ Source      │ Purpose                 │   │
│   ├──────────┼──────┼─────────────┼─────────────────────────┤   │
│   │  SSH     │  22  │ 0.0.0.0/0   │ Allow SSH from anywhere │   │
│   │  HTTP    │  80  │ 0.0.0.0/0   │ Test nginx (optional)   │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│                                                                  │
│                        INTERNET                                  │
│                           │                                      │
│              ┌────────────┼────────────┐                        │
│              │            │            │                        │
│              ▼            ▼            ▼                        │
│           SSH:22       HTTP:80     Other ports                  │
│              │            │            │                        │
│              ▼            ▼            ▼                        │
│           ✅ ALLOW     ✅ ALLOW     ❌ BLOCKED                  │
│                                                                  │
│                    ┌─────────────┐                              │
│                    │   BASTION   │                              │
│                    │   SERVER    │                              │
│                    └──────┬──────┘                              │
│                           │                                      │
│   OUTBOUND RULES:         │                                      │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  Type    │ Port │ Destination │ Purpose                 │   │
│   ├──────────┼──────┼─────────────┼─────────────────────────┤   │
│   │  ALL     │ ALL  │ 0.0.0.0/0   │ Can reach anywhere      │   │
│   └─────────────────────────────────────────────────────────┘   │
│                           │                                      │
│              ┌────────────┴────────────┐                        │
│              │                         │                        │
│              ▼                         ▼                        │
│        App Servers              Internet                        │
│        (SSH to them)            (Download packages)             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Understanding the Rules

| Direction | Port | Protocol | Source/Dest | Why |
|-----------|------|----------|-------------|-----|
| **Inbound** | 22 | TCP | 0.0.0.0/0 | SSH access from anywhere |
| **Inbound** | 80 | TCP | 0.0.0.0/0 | HTTP for testing nginx |
| **Outbound** | ALL | ALL | 0.0.0.0/0 | Bastion can reach anything |

### Why Egress Allows All

```
┌─────────────────────────────────────────────────────────────────┐
│              WHY BASTION NEEDS FULL EGRESS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   The bastion needs to:                                         │
│                                                                  │
│   1. SSH to private app servers (port 22)                       │
│      Bastion → 10.10.30.x:22 → App Server                       │
│                                                                  │
│   2. Download packages from internet                            │
│      Bastion → Internet → yum repositories                      │
│                                                                  │
│   3. Possibly access other internal services                    │
│      Bastion → 10.10.x.x → Any internal service                 │
│                                                                  │
│   SIMPLEST APPROACH: Allow all egress (0.0.0.0/0)              │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │   egress {                                               │   │
│   │     from_port   = 0          # All ports                 │   │
│   │     to_port     = 0          # All ports                 │   │
│   │     protocol    = "-1"       # All protocols             │   │
│   │     cidr_blocks = ["0.0.0.0/0"]  # Anywhere              │   │
│   │   }                                                      │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Dynamic Blocks Explained

### What is a Dynamic Block?

A dynamic block **generates multiple blocks** from a list - like a loop!

### Without Dynamic (Repetitive)

```hcl
# If you wanted to allow SSH from 3 IPs, you'd write:

ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["1.2.3.4/32"]
}

ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["5.6.7.8/32"]
}

ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["9.10.11.12/32"]
}

# 😫 So much repetition!
```

### With Dynamic (Clean)

```hcl
# Same result with dynamic block:

variable "allowed_cidrs" {
  default = ["1.2.3.4/32", "5.6.7.8/32", "9.10.11.12/32"]
}

dynamic "ingress" {
  for_each = var.allowed_cidrs    # Loop through the list
  content {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ingress.value] # Current item in loop
  }
}

# ✅ Creates 3 ingress rules automatically!
```

### How It Works (Visual)

```
┌─────────────────────────────────────────────────────────────────┐
│                    DYNAMIC BLOCK FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   INPUT: var.bastion_allowed_ssh_cidrs = ["0.0.0.0/0"]          │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ dynamic "ingress" {                                      │   │
│   │   for_each = var.bastion_allowed_ssh_cidrs              │   │
│   │   content {                                              │   │
│   │     from_port   = 22                                     │   │
│   │     to_port     = 22                                     │   │
│   │     protocol    = "tcp"                                  │   │
│   │     cidr_blocks = [ingress.value]                        │   │
│   │   }                           ▲                          │   │
│   │ }                             │                          │   │
│   └───────────────────────────────┼──────────────────────────┘   │
│                                   │                              │
│   ITERATION 1:                    │                              │
│   ingress.value = "0.0.0.0/0" ────┘                              │
│                                                                  │
│   OUTPUT: Creates 1 ingress rule                                │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ ingress {                                                │   │
│   │   from_port   = 22                                       │   │
│   │   to_port     = 22                                       │   │
│   │   protocol    = "tcp"                                    │   │
│   │   cidr_blocks = ["0.0.0.0/0"]                           │   │
│   │ }                                                        │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Conditional Dynamic Block

```hcl
# HTTP is OPTIONAL based on var.bastion_enable_http

dynamic "ingress" {
  for_each = var.bastion_enable_http ? var.bastion_allowed_ssh_cidrs : []
  #         ▲                         ▲                              ▲
  #         │                         │                              │
  #         IF true                   THEN use this list             ELSE empty list
  #                                                                  (no rules created)
  content {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ingress.value]
  }
}
```

```
┌─────────────────────────────────────────────────────────────────┐
│              CONDITIONAL LOGIC                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   var.bastion_enable_http = true                                │
│                                                                  │
│   for_each = true ? ["0.0.0.0/0"] : []                          │
│            = ["0.0.0.0/0"]                                       │
│                                                                  │
│   → Creates 1 HTTP ingress rule ✅                              │
│                                                                  │
│   ─────────────────────────────────────────────────────────────  │
│                                                                  │
│   var.bastion_enable_http = false                               │
│                                                                  │
│   for_each = false ? ["0.0.0.0/0"] : []                         │
│            = []   (empty list)                                   │
│                                                                  │
│   → Creates 0 rules (nothing to iterate) ❌                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. EC2 Instance

### The Code

```hcl
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.bastion_instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  associate_public_ip_address = true

  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl enable nginx
              systemctl start nginx
              echo "<h1>DevOps Interview Lab - Bastion</h1>" > /usr/share/nginx/html/index.html
              EOT

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Role        = "bastion"
  }
}
```

### Line-by-Line Explanation

| Line | Code | What It Does |
|------|------|--------------|
| `ami` | `data.aws_ami.amazon_linux_2023.id` | Uses the AMI found by data source |
| `instance_type` | `var.bastion_instance_type` | t3.micro (from tfvars) |
| `subnet_id` | `module.vpc.public_subnets[0]` | First public subnet (10.10.10.0/24) |
| `vpc_security_group_ids` | `[aws_security_group.bastion_sg.id]` | Attach the bastion SG |
| `associate_public_ip_address` | `true` | Gets a public IP |
| `user_data` | `<<-EOT ... EOT` | Bootstrap script (runs on first boot) |

### Why Public Subnet?

```
┌─────────────────────────────────────────────────────────────────┐
│              BASTION MUST BE IN PUBLIC SUBNET                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Bastion needs:                                                │
│   ✅ Public IP (to be reachable from internet)                  │
│   ✅ Route to Internet Gateway (to send/receive traffic)        │
│                                                                  │
│   PUBLIC SUBNET provides both! ✓                                │
│                                                                  │
│   subnet_id = module.vpc.public_subnets[0]                      │
│             = First public subnet (10.10.10.0/24)               │
│             = In eu-west-2a                                      │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                     PUBLIC SUBNET                        │   │
│   │                    10.10.10.0/24                         │   │
│   │                                                          │   │
│   │   ┌─────────────────────────────────────────────────┐   │   │
│   │   │              BASTION                             │   │   │
│   │   │                                                  │   │   │
│   │   │   Private IP: 10.10.10.x (auto-assigned)        │   │   │
│   │   │   Public IP:  3.x.x.x (auto-assigned)           │   │   │
│   │   │                                                  │   │   │
│   │   │   associate_public_ip_address = true            │   │   │
│   │   │                                                  │   │   │
│   │   └─────────────────────────────────────────────────┘   │   │
│   │                                                          │   │
│   │   Route Table: 0.0.0.0/0 → Internet Gateway             │   │
│   │                                                          │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. User Data Script

### The Code

```bash
#!/bin/bash
yum update -y

# Install nginx
yum install -y nginx

systemctl enable nginx
systemctl start nginx

echo "<h1>DevOps Interview Lab - Bastion (Environment: ${var.environment})</h1>" > /usr/share/nginx/html/index.html
```

### What is User Data?

```
┌─────────────────────────────────────────────────────────────────┐
│                      USER DATA                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   User data is a BOOTSTRAP SCRIPT that runs:                    │
│   • Automatically on FIRST BOOT                                 │
│   • As ROOT user                                                │
│   • Before you can SSH in                                       │
│                                                                  │
│   TIMELINE:                                                     │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                                                          │   │
│   │   terraform apply                                        │   │
│   │         │                                                │   │
│   │         ▼                                                │   │
│   │   AWS creates EC2 instance                               │   │
│   │         │                                                │   │
│   │         ▼                                                │   │
│   │   Instance boots up                                      │   │
│   │         │                                                │   │
│   │         ▼                                                │   │
│   │   USER DATA RUNS ◄─── yum update, install nginx, etc.   │   │
│   │         │                                                │   │
│   │         ▼                                                │   │
│   │   Instance ready                                         │   │
│   │         │                                                │   │
│   │         ▼                                                │   │
│   │   You can SSH in (nginx already running!)               │   │
│   │                                                          │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Script Breakdown

| Line | Command | What It Does |
|------|---------|--------------|
| 1 | `#!/bin/bash` | Use bash shell |
| 2 | `yum update -y` | Update all packages (-y = yes to prompts) |
| 3 | `yum install -y nginx` | Install nginx web server |
| 4 | `systemctl enable nginx` | Start nginx on every boot |
| 5 | `systemctl start nginx` | Start nginx now |
| 6 | `echo "..." > /usr/.../index.html` | Create custom homepage |

### Heredoc Syntax

```hcl
user_data = <<-EOT
              #!/bin/bash
              yum update -y
              ...
              EOT
```

```
┌─────────────────────────────────────────────────────────────────┐
│                    HEREDOC EXPLAINED                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   <<-EOT                                                        │
│    │ │                                                          │
│    │ └── "EOT" is just a marker (could be "EOF", "SCRIPT", etc)│
│    │                                                            │
│    └── The "-" means "strip leading whitespace"                 │
│                                                                  │
│   Everything between <<-EOT and EOT is treated as a string     │
│   that can span multiple lines.                                 │
│                                                                  │
│   WITHOUT "-":                    WITH "-":                     │
│   <<EOT                          <<-EOT                         │
│   #!/bin/bash                        #!/bin/bash                │
│   EOT                                EOT                        │
│                                                                  │
│   (must be at column 0)          (can be indented)              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Traffic Flow

### SSH to Bastion

```
┌─────────────────────────────────────────────────────────────────┐
│                    SSH TO BASTION                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   YOU                           BASTION                          │
│   ┌─────────┐                  ┌─────────┐                      │
│   │ 💻      │   ssh ec2-user@  │ 🔐      │                      │
│   │ Your IP │ ───────────────► │ 3.x.x.x │                      │
│   │         │   3.x.x.x        │         │                      │
│   └─────────┘                  └─────────┘                      │
│                                     │                            │
│   SECURITY GROUP CHECK:             │                            │
│   ┌─────────────────────────────────┴───────────────────────┐   │
│   │                                                          │   │
│   │   Source: Your IP                                        │   │
│   │   Destination Port: 22                                   │   │
│   │   Protocol: TCP                                          │   │
│   │                                                          │   │
│   │   Rule: SSH (22) from 0.0.0.0/0                         │   │
│   │   Match: ✅ YES                                          │   │
│   │                                                          │   │
│   │   Result: ALLOWED                                        │   │
│   │                                                          │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Bastion to App Server

```
┌─────────────────────────────────────────────────────────────────┐
│                BASTION → APP SERVER (SSH)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   BASTION                         APP SERVER                     │
│   ┌─────────────┐                ┌─────────────┐                │
│   │ 10.10.10.x  │  ssh ec2-user@ │ 10.10.30.x  │                │
│   │             │ ─────────────► │             │                │
│   │ (public     │  10.10.30.x    │ (private    │                │
│   │  subnet)    │                │  subnet)    │                │
│   └─────────────┘                └─────────────┘                │
│         │                              │                         │
│         │   STEP 1: Bastion SG         │   STEP 2: App SG       │
│         │   (egress check)             │   (ingress check)      │
│         │                              │                         │
│         ▼                              ▼                         │
│   ┌───────────────┐            ┌───────────────┐                │
│   │ Egress: ALL   │            │ Ingress: 80   │                │
│   │ to 0.0.0.0/0  │            │ from VPC CIDR │                │
│   │               │            │               │                │
│   │ ✅ ALLOWED    │            │ ❌ Port 22    │                │
│   │               │            │ not open!     │                │
│   └───────────────┘            └───────────────┘                │
│                                                                  │
│   ⚠️  NOTE: Your current app_sg only allows port 80!            │
│       To SSH from bastion, you'd need to add port 22.           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### HTTP to Bastion (Testing Nginx)

```
┌─────────────────────────────────────────────────────────────────┐
│                    HTTP TO BASTION                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   BROWSER                         BASTION                        │
│   ┌─────────────┐                ┌─────────────┐                │
│   │ 🌐          │  http://       │ 🔐          │                │
│   │             │ ─────────────► │ 3.x.x.x:80  │                │
│   │ GET /       │                │             │                │
│   └─────────────┘                └──────┬──────┘                │
│                                         │                        │
│                                         ▼                        │
│                                  ┌─────────────┐                │
│                                  │   NGINX     │                │
│                                  │             │                │
│                                  │ Returns:    │                │
│                                  │ index.html  │                │
│                                  └─────────────┘                │
│                                         │                        │
│                                         ▼                        │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                                                          │   │
│   │   <h1>DevOps Interview Lab - Bastion (Environment: dev) │   │
│   │   </h1>                                                  │   │
│   │                                                          │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Interview Questions

### Q1: What is a bastion host and why do we need one?

> A bastion (jump box) is a secure server in a public subnet that provides access to private resources. It's the single entry point to your private network, making security auditing easier and reducing attack surface.

### Q2: Why use a data source for the AMI instead of hardcoding?

> Data sources automatically find the latest AMI in any region. Hardcoded AMI IDs are region-specific and become outdated when security patches are released. Data sources ensure you always get the latest secure image.

### Q3: What is a dynamic block and when would you use it?

> A dynamic block generates multiple similar blocks from a list, like a loop. Use it when you need to create multiple ingress rules, tags, or other repeated configurations based on variable input. It reduces code duplication.

### Q4: What does `protocol = "-1"` mean in a security group?

> Protocol "-1" means ALL protocols (TCP, UDP, ICMP, etc.). It's typically used in egress rules to allow all outbound traffic.

### Q5: When does user data run?

> User data runs automatically on the FIRST boot of an EC2 instance, as the root user, before SSH becomes available. It's used for bootstrap tasks like installing packages and configuring services.

### Q6: Why does the bastion have both public and private IPs?

> The public IP (3.x.x.x) allows access from the internet. The private IP (10.10.10.x) allows communication with other resources in the VPC. All EC2 instances in AWS have private IPs; public IPs are optional.

### Q7: What's the security risk of `0.0.0.0/0` for SSH?

> It allows SSH from ANY IP address on the internet. For production, you should restrict this to specific IPs (your office, VPN) like `["203.0.113.0/24"]`. Your current config is fine for learning but not for production.

### Q8: What happens if the bastion's security group has no egress rules?

> By default, AWS security groups ALLOW all outbound traffic. If you explicitly set NO egress rules, all outbound traffic would be blocked - the bastion couldn't reach app servers or download updates.

---

## ✅ Part 3 Complete!

**Next: [Part 4 - Application Load Balancer](./Part4-ALB.md)**

Covers:
- ALB security group
- Load balancer configuration
- Target groups
- Listeners and routing
- Health checks