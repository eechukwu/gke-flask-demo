# GCP Infrastructure Documentation

## Table of Contents

- [Overview](#overview)
- [Part 1: Manual Cleanup](#part-1-manual-cleanup-one-time)
- [Part 2: Manual Prerequisites](#part-2-manual-prerequisites-one-time)
- [Part 3: Terraform Files Structure](#part-3-terraform-files-structure)
- [Part 4: Local Commands](#part-4-local-commands)
- [Part 5: GitHub Actions Pipelines](#part-5-github-actions-pipelines)
- [Part 6: GitHub Secrets Required](#part-6-github-secrets-required)
- [Part 7: Post-Deployment Commands](#part-7-post-deployment-commands)
- [Part 8: Workflow Structure](#part-8-workflow-structure)
- [Part 9: Bootstrap Resources](#part-9-bootstrap-resources-not-managed-by-terraform)

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
| Service Account | gh-actions-deployer | Manual (not Terraform) |

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

### 2.3 Create Service Account
```bash
gcloud iam service-accounts create gh-actions-deployer \
  --display-name="GitHub Actions Deployer" \
  --project k8s-interview-lab
```

### 2.4 Grant IAM Roles to Service Account
```bash
gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/container.clusterAdmin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding k8s-interview-lab \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

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

### 2.5 Grant Service Account User Role
```bash
gcloud iam service-accounts add-iam-policy-binding \
  137993611700-compute@developer.gserviceaccount.com \
  --member="serviceAccount:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --project=k8s-interview-lab
```

### 2.6 Generate Service Account Key
```bash
gcloud iam service-accounts keys create gh-actions-key.json \
  --iam-account=gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com

cat gh-actions-key.json
```

### 2.7 Verify SA Permissions
```bash
gcloud projects get-iam-policy k8s-interview-lab \
  --flatten="bindings[].members" \
  --filter="bindings.members:gh-actions-deployer@k8s-interview-lab.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

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
| outputs.tf | Cluster endpoint and connect command |

---

## Part 4: Local Commands

### 4.1 Fix Local Auth
```bash
rm -f ~/.config/gcloud/application_default_credentials.json

gcloud auth application-default login --scopes="https://www.googleapis.com/auth/cloud-platform"
```

### 4.2 Initialize Terraform
```bash
cd infra/gcp/envs/dev

terraform init
terraform fmt
terraform validate
terraform plan
```

### 4.3 Force Unlock State
```bash
terraform force-unlock <LOCK_ID>
```

### 4.4 Clear Corrupted State
```bash
gsutil rm gs://k8s-interview-lab-tfstate/gcp/dev/default.tflock
gsutil rm gs://k8s-interview-lab-tfstate/gcp/dev/default.tfstate
```

---

## Part 5: GitHub Actions Pipelines

### 5.1 Deploy Pipeline (gcp-infra-dev.yml)

| Trigger | Action |
|---------|--------|
| Push to main on infra/gcp/envs/dev/* | Plan + Apply |
| PR to main on infra/gcp/envs/dev/* | Plan only |
| Manual workflow_dispatch | Plan + Apply |

### 5.2 Destroy Pipeline (gcp-infra-dev-destroy.yml)

| Trigger | Action |
|---------|--------|
| Manual workflow_dispatch | Plan destroy + Apply destroy |

**Safety Guards:**
- Must type DESTROY to confirm
- Must select environment dev

---

## Part 6: GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| GCP_SA_KEY | JSON key for gh-actions-deployer |
| GCP_PROJECT_ID | k8s-interview-lab |
| GKE_CLUSTER_NAME | k8s-interview-cluster |
| GKE_ZONE | europe-west2-b |

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
kubectl get pods -A
```

### 7.3 Check Artifact Registry
```bash
gcloud artifacts repositories list --location europe-west2 --project k8s-interview-lab
```

### 7.4 Configure Docker
```bash
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

---

## Part 9: Bootstrap Resources (Not Managed by Terraform)

| Resource | Why Manual |
|----------|------------|
| Service Account | Terraform needs it to authenticate |
| GCS Bucket | Terraform needs it to store state |
| IAM Roles | SA needs permissions before Terraform runs |

**Lesson Learned:** Never let Terraform manage credentials it uses to run.
