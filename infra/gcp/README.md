# GCP Infrastructure Documentation

## Table of Contents

- [Overview](#overview)
- [Part 1: Manual Cleanup](#part-1-manual-cleanup-one-time)
- [Part 2: Manual Prerequisites](#part-2-manual-prerequisites-one-time)
- [Part 3: Terraform Files Structure](#part-3-terraform-files-structure)
- [Part 4: Local Terraform Commands](#part-4-local-terraform-commands)
- [Part 5: GitHub Actions Pipelines](#part-5-github-actions-pipelines)
- [Part 6: GitHub Secrets Required](#part-6-github-secrets-required)
- [Part 7: Post-Deployment Commands](#part-7-post-deployment-commands)
- [Part 8: Workflow Structure](#part-8-workflow-structure)
- [Part 9: Interview Questions & Answers](#part-9-interview-questions--answers)
- [Part 10: Troubleshooting Commands](#part-10-troubleshooting-commands)
- [Part 11: Files to NOT Commit](#part-11-files-to-not-commit)
- [Part 12: Summary](#part-12-summary)

---

## Overview

We migrated from a manually created GKE cluster to a fully IaC-managed infrastructure using Terraform and GitHub Actions pipelines.

**Resources Managed:**

| Resource | Name | Location |
|----------|------|----------|
| GKE Cluster | k8s-interview-cluster | europe-west2-b |
| Node Pool | k8s-interview-cluster-node-pool | europe-west2-b |
| Artifact Registry | flask-repo | europe-west2 |
| Terraform State | k8s-interview-lab-tfstate | europe-west2 |
| Service Account | gh-actions-deployer | - |

---

## Part 1: Manual Cleanup (One-Time)

### 1.1 Delete Existing Resources
```bash
gcloud container clusters delete k8s-interview-cluster \
  --zone europe-west2-b \
  --project k8s-interview-lab \
  --quiet

gcloud artifacts repositories delete flask-repo \
  --location europe-west2 \
  --project k8s-interview-lab \
  --quiet
```

### 1.2 Verify Cleanup
```bash
gcloud container clusters list --project k8s-interview-lab

gcloud artifacts repositories list --location europe-west2 --project k8s-interview-lab

gcloud iam service-accounts list --project k8s-interview-lab

gsutil ls -p k8s-interview-lab
```

---

## Part 2: Manual Prerequisites (One-Time)

### 2.1 Enable Required APIs
```bash
gcloud services enable cloudresourcemanager.googleapis.com --project k8s-interview-lab

gcloud services enable container.googleapis.com --project k8s-interview-lab

gcloud services enable artifactregistry.googleapis.com --project k8s-interview-lab

gcloud services enable compute.googleapis.com --project k8s-interview-lab
```

### 2.2 Create GCS Bucket for Terraform State
```bash
gsutil mb -p k8s-interview-lab -l europe-west2 gs://k8s-interview-lab-tfstate

gsutil versioning set on gs://k8s-interview-lab-tfstate
```

### 2.3 Grant IAM Roles to Service Account
```bash
gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/container.clusterAdmin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/compute.networkAdmin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/compute.viewer"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"
```

### 2.4 Grant Service Account User Role
```bash
gcloud iam service-accounts add-iam-policy-binding \
  137993611700-compute@developer.gserviceaccount.com \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --project=k8s-interview-lab
```

### 2.5 Verify SA Permissions
```bash
gcloud projects get-iam-policy k8s-interview-lab \
  --flatten="bindings[].members" \
  --filter="bindings.members:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

**Expected output:**

| ROLE |
|------|
| roles/artifactregistry.admin |
| roles/artifactregistry.writer |
| roles/compute.networkAdmin |
| roles/compute.viewer |
| roles/container.admin |
| roles/container.clusterAdmin |
| roles/iam.serviceAccountAdmin |
| roles/resourcemanager.projectIamAdmin |
| roles/storage.admin |

---

## Part 3: Terraform Files Structure
```
infra/gcp/envs/dev/
├── backend.tf
├── providers.tf
├── variables.tf
├── terraform.tfvars
├── gke.tf
├── artifact-registry.tf
├── iam.tf
└── outputs.tf
```

| File | Purpose |
|------|---------|
| backend.tf | GCS remote state configuration |
| providers.tf | Google provider with project and region |
| variables.tf | Input variables with types and defaults |
| terraform.tfvars | Actual values for variables |
| gke.tf | GKE cluster and node pool |
| artifact-registry.tf | Docker registry for container images |
| iam.tf | Service account and IAM bindings |
| outputs.tf | Cluster endpoint and connect command |

---

## Part 4: Local Terraform Commands

### 4.1 Fix Local Auth (if needed)
```bash
rm -f ~/.config/gcloud/application_default_credentials.json

gcloud auth application-default login --scopes="https://www.googleapis.com/auth/cloud-platform"
```

Or use SA key directly:
```bash
export GOOGLE_APPLICATION_CREDENTIALS=~/Desktop/gke-flask-demo/gh-actions-key.json
```

### 4.2 Initialize and Import
```bash
cd infra/gcp/envs/dev

terraform init

terraform fmt

terraform validate

terraform import google_service_account.gh_actions \
  projects/k8s-interview-lab/serviceAccounts/gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com

terraform plan
```

### 4.3 Force Unlock (if state locked)
```bash
terraform force-unlock <LOCK_ID>
```

---

## Part 5: GitHub Actions Pipelines

### 5.1 Deploy Pipeline (gcp-infra-dev.yml)

| Trigger | Action |
|---------|--------|
| Push to main on infra/gcp/envs/dev/* | Plan + Apply |
| PR to main on infra/gcp/envs/dev/* | Plan only |
| Manual workflow_dispatch | Plan + Apply |

**Jobs:**

1. Plan - Init, format check, validate, plan, upload artifact
2. Apply - Download plan, apply (only on main branch)

### 5.2 Destroy Pipeline (gcp-infra-dev-destroy.yml)

| Trigger | Action |
|---------|--------|
| Manual workflow_dispatch | Plan destroy + Apply destroy |

**Safety Guards:**

- Must type DESTROY to confirm
- Must select environment dev
- Both conditions must match for job to run

---

## Part 6: GitHub Secrets Required

| Secret | Description | Example |
|--------|-------------|---------|
| GCP_SA_KEY | JSON key for gh-actions-deployer | {"type": "service_account", ...} |
| GCP_PROJECT_ID | GCP project ID | k8s-interview-lab |
| GKE_CLUSTER_NAME | GKE cluster name | k8s-interview-cluster |
| GKE_ZONE | GKE cluster zone | europe-west2-b |

---

## Part 7: Post-Deployment Commands

### 7.1 Connect to Cluster
```bash
gcloud container clusters get-credentials k8s-interview-cluster \
  --zone europe-west2-b \
  --project k8s-interview-lab
```

### 7.2 Verify Resources
```bash
kubectl get nodes

kubectl cluster-info

kubectl get namespaces
```

### 7.3 Configure Docker for Artifact Registry
```bash
# Check Artifact Registry exists
gcloud artifacts repositories list --location europe-west2 --project k8s-interview-lab

gcloud auth configure-docker europe-west2-docker.pkg.dev
```

---

## Part 8: Workflow Structure
```
.github/workflows/
├── build.yml                    # Build + push Docker image
├── deploy-dev.yml               # Deploy app to GKE dev namespace
├── deploy-prod.yml              # Deploy app to GKE prod namespace
├── gcp-infra-dev.yml            # Terraform apply (GKE + AR)
├── gcp-infra-dev-destroy.yml    # Terraform destroy
├── aws-infra-dev.yml            # AWS Terraform apply
└── aws-infra-dev-destroy.yml    # AWS Terraform destroy
```

**Pipeline Flow:**

1. Infrastructure pipelines run on infra/* changes
2. App pipelines run on app code changes
3. build.yml triggers deploy-dev.yml triggers deploy-prod.yml

---

## Part 9: Interview Questions & Answers

### Q1: Why use remote state instead of local state?

Remote state (GCS/S3) provides:

- Team collaboration - Multiple engineers can work on same infra
- State locking - Prevents concurrent modifications
- Security - State files contain sensitive data, shouldn't be in git
- Durability - Cloud storage is more reliable than local disk
- CI/CD compatibility - Pipelines need access to state

### Q2: Why did you import the service account instead of creating it?

The SA gh-actions-deployer already existed from the manual setup. Terraform import brings existing resources under Terraform management without recreating them. This:

- Avoids destroying and recreating the SA
- Preserves the existing SA key used by GitHub Actions
- Maintains continuity of IAM bindings

### Q3: What's the difference between container.admin and container.clusterAdmin?

- container.admin - Full control over GKE resources (clusters, node pools)
- container.clusterAdmin - Kubernetes RBAC cluster-admin role inside the cluster

Both are needed: one for managing GKE infrastructure, one for kubectl operations.

### Q4: Why enable deletion_protection = false?

For a dev environment, we want the ability to easily destroy and recreate the cluster. In production, this should be true to prevent accidental deletion.

### Q5: Why separate infra and app pipelines?

- Different triggers - Infra changes are less frequent than app changes
- Different permissions - Infra needs admin access, app just needs deploy access
- Blast radius - Infra changes are higher risk, should be separate
- Speed - App deploys should be fast, not waiting for infra checks

### Q6: What happens if the pipeline fails mid-apply?

Terraform state tracks what was created. On retry:

- Already-created resources won't be recreated
- Failed resources will be retried
- State locking prevents corruption from concurrent runs

### Q7: Why use workflow_dispatch with confirmation for destroy?

Destroy is destructive and irreversible. The confirmation:

- Prevents accidental triggers
- Requires explicit intent (typing DESTROY)
- Provides audit trail of who triggered it

### Q8: How do you handle secrets in Terraform?

- Never commit secrets to git
- Use GitHub Secrets for pipeline credentials
- Mark sensitive outputs with sensitive = true
- Use remote state with encryption enabled
- SA keys stored only in GitHub Secrets, not in repo

### Q9: What's the purpose of the .terraform.lock.hcl file?

It locks provider versions to ensure consistent behavior across team members and CI/CD. Should be committed to git, unlike .terraform/ directory.

### Q10: How would you extend this to production?

- Create infra/gcp/envs/prod/ with separate tfvars
- Use different GCS state prefix (gcp/prod)
- Enable deletion_protection = true
- Add manual approval step in pipeline
- Use larger machine types and more nodes
- Enable private cluster and VPC-native networking

---

## Part 10: Troubleshooting Commands
```bash
# Check Terraform state
terraform state list

# View specific resource in state
terraform state show google_container_cluster.primary

# Refresh state from actual infrastructure
terraform refresh

# Force unlock stuck state
terraform force-unlock <LOCK_ID>

# Taint resource for recreation
terraform taint google_container_node_pool.primary_nodes

# Import existing resource
terraform import <resource_address> <resource_id>

# Check GKE cluster status
gcloud container clusters describe k8s-interview-cluster \
  --zone europe-west2-b \
  --project k8s-interview-lab

# Check SA permissions
gcloud projects get-iam-policy k8s-interview-lab \
  --flatten="bindings[].members" \
  --filter="bindings.members:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

---

## Part 11: Files to NOT Commit
```
# Terraform - DO NOT COMMIT
.terraform/
terraform.tfstate
terraform.tfstate.*
*.tfplan
crash.log

# GCP - DO NOT COMMIT
gh-actions-key.json

# Terraform - SHOULD COMMIT
.terraform.lock.hcl
```

---

## Part 12: Summary

### Manual vs IaC

| Task | Manual | IaC |
|------|--------|-----|
| Enable APIs | Yes | |
| Create GCS bucket | Yes | |
| Grant IAM roles | Yes | |
| Import existing SA | Yes | |
| Create GKE cluster | | Yes |
| Create node pool | | Yes |
| Create Artifact Registry | | Yes |
| Manage IAM bindings | | Yes |
| Day-2 changes | | Yes |
| Destroy infrastructure | | Yes |

### Key Learnings

1. Remote state first - GCS bucket must exist before terraform init
2. SA permissions first - Pipeline SA needs all required roles before running
3. Import existing resources - Use terraform import for resources created outside Terraform
4. Lock file is good - .terraform.lock.hcl should be committed
5. Separate infra and app pipelines - Infrastructure changes shouldn't trigger app deployments
