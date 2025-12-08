# Git Practices for GKE Flask Demo

- main = stable branch (CI + deployments)
- feature/* branches for new work
- Small, focused commits with clear messages
- Always open a PR from feature/* back into main
- Practising git stash, reset, and revert on this branch.
- Temporary line for practising git reset.

---

## Terraform – Core Commands (AWS VPC/EC2)

### Init & planning

- \`terraform init\`  
  Download providers & modules for this folder. Must be run once per env (or after changing providers/modules).

- \`terraform plan\`  
  Show what Terraform *would* change in AWS without actually doing it.
  - Reads \`*.tf\` + \`terraform.tfvars\`
  - Compares desired state vs real AWS
  - Outputs: “X to add, Y to change, Z to destroy”

### Applying & destroying

- \`terraform apply\`  
  - Re-runs the plan and then **performs** the changes (create/update/destroy).
  - Typical flow: review plan → type \`yes\`.

- \`terraform destroy\`  
  - Destroys all resources **managed by this state**.
  - Use carefully, usually only in lab/sandbox.

### State & inspection

- \`terraform show\`  
  Show the current state (what Terraform believes exists).

- \`terraform state list\`  
  List all resources tracked in the state file.

- \`terraform state show <resource>\`  
  Show details of a specific resource in state  
  e.g. \`terraform state show module.vpc.aws_vpc.this[0]\`

### Formatting & validation

- \`terraform fmt\`  
  Automatically format \`*.tf\` files to standard style.

- \`terraform validate\`  
  Check that the configuration is syntactically valid and internally consistent.

### Useful patterns (senior talk-track)

- “I always run \`terraform plan\` before \`apply\`, and I never apply directly to prod without a reviewed plan.”
- “State is critical – usually stored in a remote backend (S3 + DynamoDB / GCS) with locking. For this lab I’m using local state only.”
- “For real environments, I separate state per env (dev/stage/prod) and often per major system (network, compute, data).”

