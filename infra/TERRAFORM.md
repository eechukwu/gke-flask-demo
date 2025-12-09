# Terraform Interview Guide - Senior Level (20 Questions)

---

## Q1: What is Terraform and how does it differ from CloudFormation?

**Terraform:**
- Multi-cloud (AWS, GCP, Azure, K8s)
- HCL syntax, provider-based
- External state file (S3, GCS)

**CloudFormation:**
- AWS-only
- YAML/JSON, state managed by AWS
- Deeper AWS integration

---

## Q2: What is Terraform state and why is it critical?

- Maps real resources ↔ Terraform config
- Tracks resource attributes and dependencies
- Enables plan/diff calculation
- Must be stored securely (remote backend, encryption)

---

## Q3: Why use remote state instead of local?

- **Collaboration:** Shared truth for the team
- **Locking:** Prevents concurrent applies (S3+DynamoDB, GCS)
- **Durability:** Not tied to laptop, easier backups
- **CI/CD:** Pipelines need access to state

---

## Q4: What is drift and how do you handle it?

**Drift** = Infrastructure changed outside Terraform.

**Detect:** `terraform plan` shows unexpected diffs

**Handle:**
- Update code to match reality
- Let Terraform revert manual changes
- `terraform import` for new resources

---

## Q5: Explain `count` vs `for_each`. When use each?

**count:** Index-based (0, 1, 2). Problematic when removing middle items.

**for_each:** Key-based, stable references. Better for named resources.

**Rule:** Prefer `for_each` for resources that may change.

---

## Q6: How do you structure Terraform for multiple environments?
```
infra/
├── modules/
│   └── vpc/
├── aws/envs/
│   ├── dev/
│   ├── staging/
│   └── prod/
```

- Separate state per environment
- Shared modules
- Environment-specific tfvars

---

## Q7: When would you use `terraform import`?

When a resource exists and you want Terraform to manage it.

**Flow:**
1. Write resource block
2. `terraform import <resource> <cloud-id>`
3. `terraform plan` to verify
4. Adjust code until clean

---

## Q8: How do you handle secrets in Terraform?

- **Never** commit secrets to Git
- Use AWS Secrets Manager / GCP Secret Manager
- Read via data sources
- Mark variables as `sensitive = true`
- Use GitHub Secrets in CI

---

## Q9: How do you run Terraform safely in CI/CD?

**Plan job:**
```bash
terraform init
terraform validate
terraform plan -out=tfplan
# Upload tfplan artifact
```

**Apply job:**
```bash
# Download tfplan
terraform apply tfplan
# Only on main branch
```

---

## Q10: Explain Terraform's dependency graph.

Terraform builds a DAG (Directed Acyclic Graph).

**Implicit:** `subnet_id = aws_subnet.main.id`

**Explicit:** `depends_on = [aws_iam_role.policy]`

**View:** `terraform graph | dot -Tpng > graph.png`

---

## Q11: What are `lifecycle` rules? Give examples.
```hcl
lifecycle {
  create_before_destroy = true   # Blue-green
  prevent_destroy       = true   # Block deletion
  ignore_changes        = [tags] # Ignore drift
}
```

---

## Q12: How do you handle provider version upgrades?
```hcl
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"  # Allows 5.x, not 6.x
  }
}
```

**Upgrade:** `terraform init -upgrade`, then `terraform plan`

---

## Q13: What's your approach to `terraform destroy` safety?

- Separate destroy workflow
- `workflow_dispatch` with confirmation input
- Type "DESTROY" to confirm
- Hard-code environment check
- Never auto-destroy prod

---

## Q14: How do you enforce Terraform quality in CI?
```bash
terraform fmt -check    # Formatting
terraform validate      # Syntax
tflint                  # Linting
tfsec / checkov         # Security
```

Block merges if checks fail.

---

## Q15: Explain `moved` blocks and when to use them.
```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}
```

**Use cases:**
- Rename resources
- Move into/out of modules
- Refactor without destroy/create

---

## Q16: How do you recover from corrupted state?

1. **Check versioning:**
```bash
aws s3api list-object-versions --bucket state-bucket
aws s3api get-object --version-id <id> recovered.tfstate
```

2. **Push recovered:**
```bash
terraform state push recovered.tfstate
```

---

## Q17: What are data sources and when do you use them?

**Data sources** read existing infrastructure.
```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}
```

**Use cases:** Reference existing resources, look up AMIs, cross-stack references.

---

## Q18: How do you implement least privilege for Terraform?

- **Plan role:** Read-only + state read/write
- **Apply role:** Full resource permissions
- **Scope by environment:** Restrict prod role to main branch only

---

## Q19: Why should bootstrap resources NOT be in Terraform?

**Bootstrap resources:** SA, state bucket, IAM roles for Terraform itself.

**Problem:** `terraform destroy` deletes SA → loses auth mid-operation → state corruption.

**Rule:** Never let Terraform manage credentials it uses to run.

---

## Q20: Describe your approach to Terraform in a new organization.

1. **Foundation:** Remote backend, state locking, CI/CD pipeline
2. **Structure:** Monorepo or separate repos, module library, env separation
3. **Standards:** Naming conventions, tagging, code review
4. **Security:** OIDC auth, least privilege, secret management
5. **Governance:** Policy as code, cost controls, drift detection

---

## Quick Reference

### Essential Commands
```bash
terraform init              # Initialize
terraform init -upgrade     # Upgrade providers
terraform plan              # Preview changes
terraform plan -out=tfplan  # Save plan
terraform apply tfplan      # Apply saved plan
terraform destroy           # Destroy all
terraform fmt               # Format code
terraform validate          # Validate syntax
terraform state list        # List resources
terraform state mv          # Rename resource
terraform import            # Import resource
terraform force-unlock      # Release lock
```

### Files to Gitignore
```
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
```

### Files to Commit
```
*.tf
.terraform.lock.hcl
```
