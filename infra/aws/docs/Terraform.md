# Part 1: Backend, Providers & Variables
## The Foundation of Your Terraform Configuration

---

## 📋 Table of Contents

| Section | Description |
|---------|-------------|
| [1. _backend.tf](#1-backendtf---state-storage) | State storage in S3 |
| [2. providers.tf](#2-providerstf---aws-connection) | AWS connection & versions |
| [3. variables.tf](#3-variablestf---input-definitions) | Input definitions & types |
| [4. terraform.tfvars](#4-terraformtfvars---actual-values) | Actual configuration values |
| [5. Interview Questions](#5-interview-questions) | Key concepts to remember |

---

## 1. _backend.tf - State Storage

### The Code

```hcl
terraform {
  backend "s3" {
    bucket  = "devops-interview-lab-tfstate"
    key     = "aws/dev/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}
```

### Line-by-Line Explanation

| Line | Code | What It Does |
|------|------|--------------|
| 1 | `terraform {` | Opens Terraform settings block |
| 2 | `backend "s3" {` | "Store my state in AWS S3" |
| 3 | `bucket = "devops-interview-lab-tfstate"` | S3 bucket name |
| 4 | `key = "aws/dev/terraform.tfstate"` | File path inside bucket |
| 5 | `region = "eu-west-2"` | Bucket's AWS region (London) |
| 6 | `encrypt = true` | Encrypt state file at rest |

### What is Terraform State?

**State = Terraform's "memory"** of what it created.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Your .tf files say:              State file remembers:        │
│   "I WANT this"                    "I CREATED this"             │
│                                                                 │
│   ┌─────────────────────┐          ┌─────────────────────────┐  │
│   │ resource "aws_      │          │ {                       │  │
│   │ instance" "web" {   │    →     │   "aws_instance.web": { │  │
│   │   ami = "ami-xxx"   │          │     "id": "i-0abc123",  │  │
│   │   instance_type =   │          │     "public_ip": "3.x.x"│  │
│   │     "t3.micro"      │          │   }                     │  │
│   │ }                   │          │ }                       │  │
│   └─────────────────────┘          └─────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Why it matters:**
- `terraform plan` compares your .tf files with state
- Knows what to CREATE, UPDATE, or DELETE
- Without state, Terraform would create duplicates!

### Why Remote State (S3)?

**❌ Problem with Local State:**

```
Your Laptop                      GitHub Actions (CI/CD)
┌──────────────┐                 ┌──────────────┐
│ terraform    │                 │ terraform    │
│ .tfstate     │                 │ .tfstate     │
│              │                 │              │
│ "VPC exists" │                 │ "VPC doesn't │
│              │                 │  exist!"     │
└──────────────┘                 └──────────────┘
        │                               │
        └───────────┬───────────────────┘
                    │
                    ▼
              😱 CONFLICT!
        Different views of reality
```

**✅ Solution with Remote State (S3):**

```
Your Laptop                      GitHub Actions (CI/CD)
┌──────────────┐                 ┌──────────────┐
│ terraform    │                 │ terraform    │
│   init       │                 │   init       │
└──────┬───────┘                 └──────┬───────┘
       │                                │
       └────────────┬───────────────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │      S3 BUCKET      │
         │  ┌───────────────┐  │
         │  │ terraform     │  │  ← SINGLE SOURCE
         │  │ .tfstate      │  │    OF TRUTH!
         │  └───────────────┘  │
         └─────────────────────┘
                    │
                    ▼
            ✅ EVERYONE AGREES
```

### Benefits of Remote State

| Benefit | Explanation |
|---------|-------------|
| **Team collaboration** | Everyone reads/writes same state |
| **CI/CD friendly** | GitHub Actions can run terraform |
| **State locking** | Prevents concurrent modifications |
| **Encryption** | State may contain secrets - protect it! |

### Your S3 Bucket Structure

```
S3 Bucket: devops-interview-lab-tfstate
│
└── aws/
    └── dev/
        └── terraform.tfstate    ← Your state file lives here
    
    (Future: you could add)
    └── prod/
        └── terraform.tfstate    ← Separate state for production
```

---

## 2. providers.tf - AWS Connection

### The Code

```hcl
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
  region = var.aws_region
}
```

### Line-by-Line Explanation

| Line | Code | What It Does |
|------|------|--------------|
| 2 | `required_version = ">= 1.6.0"` | Terraform CLI must be 1.6.0 or newer |
| 5 | `source = "hashicorp/aws"` | Download from official Terraform Registry |
| 6 | `version = "~> 5.0"` | Use any 5.x version (not 6.0) |
| 11 | `region = var.aws_region` | Deploy to region from variables (eu-west-2) |

### Version Constraints Cheat Sheet

| Constraint | Meaning | Example Matches |
|------------|---------|-----------------|
| `= 5.0.0` | Exactly this version | 5.0.0 only |
| `>= 5.0` | This or newer | 5.0, 5.1, 6.0, 7.0... |
| `~> 5.0` | Rightmost can increment | 5.0, 5.1, 5.99 (NOT 6.0) |
| `~> 5.1.0` | Only patch increments | 5.1.0, 5.1.1 (NOT 5.2.0) |

**Your Config (`~> 5.0`):**
```
✓ 5.0    ✓ 5.1    ✓ 5.50    ✓ 5.99    ✗ 6.0

WHY? Major versions (5→6) often have breaking changes.
     Minor versions (5.0→5.1) add features safely.
```

### How Providers Work

```
STEP 1: terraform init
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Terraform reads providers.tf                              │
│   "You need hashicorp/aws version ~> 5.0"                   │
│                                                             │
│   Downloads from: registry.terraform.io                     │
│   Saves to: .terraform/providers/...                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘

STEP 2: terraform plan/apply
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   ┌──────────────┐      ┌──────────────┐                    │
│   │  Your .tf    │      │ AWS Provider │                    │
│   │    files     │ ───► │   Plugin     │                    │
│   │              │      │              │                    │
│   │ "Create VPC" │      │ Translates   │                    │
│   └──────────────┘      │ to API calls │                    │
│                         └──────┬───────┘                    │
│                                │                            │
│                                ▼                            │
│                         ┌──────────────┐                    │
│                         │   AWS APIs   │                    │
│                         │  (eu-west-2) │                    │
│                         │              │                    │
│                         │ • EC2 API    │                    │
│                         │ • VPC API    │                    │
│                         │ • ELB API    │                    │
│                         └──────────────┘                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. variables.tf - Input Definitions

### What This File Does

Defines the **SCHEMA** - what variables exist, their types, and defaults.

> Think of it as a form template with blank fields to fill in.

### Variable Types

| Type | Example | Your Usage |
|------|---------|------------|
| `string` | `"hello"`, `"t3.micro"` | project_name, vpc_cidr |
| `number` | `42`, `3.14` | app_asg_min_size, app_cpu_target |
| `bool` | `true`, `false` | bastion_enable_http |
| `list(string)` | `["a", "b", "c"]` | azs, public_subnets |
| `map(string)` | `{key = "value"}` | (not used in your config) |

### Required vs Optional Variables

**REQUIRED (no default):**

```hcl
variable "project_name" {
  description = "Project name"
  type        = string
}  # ← NO default line = REQUIRED
```
→ If you don't provide a value, Terraform will **ERROR!**

**OPTIONAL (has default):**

```hcl
variable "bastion_instance_type" {
  description = "Instance type"
  type        = string
  default     = "t3.micro"  # ← HAS default = OPTIONAL
}
```
→ If you don't provide a value, uses `"t3.micro"`

### Your Variables Summary

| Variable | Type | Required? | Purpose |
|----------|------|-----------|---------|
| `project_name` | string | Yes | Resource naming |
| `environment` | string | Yes | dev/prod tag |
| `aws_region` | string | Yes | AWS region |
| `vpc_cidr` | string | Yes | VPC IP range |
| `azs` | list(string) | Yes | Availability zones |
| `public_subnets` | list(string) | Yes | Public subnet CIDRs |
| `private_subnets` | list(string) | Yes | Private subnet CIDRs |
| `bastion_instance_type` | string | No | Bastion EC2 size |
| `bastion_allowed_ssh_cidrs` | list(string) | Yes | Who can SSH |
| `bastion_enable_http` | bool | No | Open port 80? |
| `app_instance_type` | string | No | App EC2 size |
| `app_asg_min_size` | number | No | Min ASG instances |
| `app_asg_max_size` | number | No | Max ASG instances |
| `app_cpu_target` | number | No | CPU scaling target |

---

## 4. terraform.tfvars - Actual Values

### The Code

```hcl
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
app_cpu_target           = 40
```

### How Variables Flow

```
terraform.tfvars          variables.tf              Resource Files
(THE VALUES)              (THE SCHEMA)              (THE USAGE)

┌─────────────────┐      ┌─────────────────┐       ┌────────────────┐
│                 │      │ variable "vpc_  │       │ module "vpc" { │
│ vpc_cidr =      │ ───► │ cidr" {         │ ────► │   cidr =       │
│ "10.10.0.0/16"  │      │   type = string │       │   var.vpc_cidr │
│                 │      │ }               │       │ }              │
└─────────────────┘      └─────────────────┘       └────────────────┘
```

### Your Network Layout (From Variables)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        VPC: 10.10.0.0/16                                │
│                       (65,536 IP addresses)                             │
│                                                                         │
│   ┌─────────────────────────────┐    ┌─────────────────────────────┐   │
│   │      eu-west-2a             │    │      eu-west-2b             │   │
│   │                             │    │                             │   │
│   │  PUBLIC: 10.10.10.0/24      │    │  PUBLIC: 10.10.20.0/24      │   │
│   │  ┌───────────────────────┐  │    │  ┌───────────────────────┐  │   │
│   │  │  Bastion, ALB         │  │    │  │  ALB                  │  │   │
│   │  │  (254 IPs)            │  │    │  │  (254 IPs)            │  │   │
│   │  └───────────────────────┘  │    │  └───────────────────────┘  │   │
│   │                             │    │                             │   │
│   │  PRIVATE: 10.10.30.0/24     │    │  PRIVATE: 10.10.40.0/24     │   │
│   │  ┌───────────────────────┐  │    │  ┌───────────────────────┐  │   │
│   │  │  App Servers          │  │    │  │  App Servers          │  │   │
│   │  │  (254 IPs)            │  │    │  │  (254 IPs)            │  │   │
│   │  └───────────────────────┘  │    │  └───────────────────────┘  │   │
│   │                             │    │                             │   │
│   └─────────────────────────────┘    └─────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Interview Questions

### Q1: Why use remote state instead of local state?

> Remote state enables team collaboration and CI/CD pipelines. Everyone reads/writes the same state file, preventing conflicts and drift. It's the **Single Source of Truth**.

### Q2: What does `~> 5.0` mean for provider versions?

> It means "any 5.x version but not 6.0". The rightmost number can increment. This protects against breaking changes in major versions while allowing minor updates.

### Q3: What's the difference between variables.tf and terraform.tfvars?

> `variables.tf` defines the **SCHEMA** (what variables exist, their types, defaults). `terraform.tfvars` provides the actual **VALUES**.

### Q4: What happens if you don't provide a required variable?

> Terraform will error with "No value for required variable" and refuse to plan/apply.

### Q5: Why encrypt the state file?

> State can contain sensitive data (passwords, keys, resource IDs). Encryption at rest protects this data in S3.

### Q6: What is the purpose of `terraform init`?

> It initializes the working directory, downloads required providers from the registry, and configures the backend for state storage.

### Q7: Why pin provider versions?

> Reproducibility - prevents unexpected breaking changes from affecting your infrastructure. Everyone on the team uses the same provider version.

---

## ✅ Part 1 Complete!

**Next: [Part 2 - VPC & Networking](./Part2-VPC-Networking.md)**

Covers:
- CIDR blocks explained simply
- Public vs Private subnets
- Internet Gateway vs NAT Gateway
- Route tables and how traffic flows