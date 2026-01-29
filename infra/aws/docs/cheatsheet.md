# Senior DevOps/Cloud Engineer - Interview Cheat Sheet 📋

---

## 📋 TABLE OF CONTENTS

| # | Section | Topics |
|---|---------|--------|
| 1 | [Terraform](#terraform) | State, modules, best practices, gotchas |
| 2 | [AWS Networking](#aws-networking) | VPC, security groups, load balancing |
| 3 | [AWS Compute](#aws-compute) | EC2, ASG, containers, serverless |
| 4 | [CI/CD & Deployments](#cicd--deployments) | Strategies, approvals, rollback, security |
| 5 | [AI in CI/CD](#ai-in-cicd) | Tools, integration, best practices |
| 6 | [Kubernetes](#kubernetes) | Core concepts, troubleshooting, security |
| 7 | [Multi-Cluster K8s Pipeline](#multi-cluster-kubernetes-bootstrap-pipeline) | Reusable workflow, parallel deployment, production patterns |
| 8 | [Linux](#linux) | Commands, troubleshooting, systemd |
| 9 | [Monitoring & Observability](#monitoring--observability) | Metrics, logs, traces, alerting |
| 10 | [Reliability & Incidents](#reliability--incident-management) | HA, incident response, chaos |
| 11 | [Security](#security) | IAM, secrets, containers |
| 12 | [System Design](#system-design-quick-patterns) | Architectures, scaling |
| 13 | [Python for DevOps](#python-for-devops) | Skeleton, Q&A, practical script |
| 14 | [Behavioral Tips](#behavioral-tips) | STAR format, questions to ask |

---

## TERRAFORM

### State Management
| Question | Key Points |
|----------|------------|
| **How do you manage Terraform state in a team?** | Remote backend (S3 + DynamoDB), state locking, encryption at rest, versioning enabled |
| **What happens if state is corrupted/deleted?** | `terraform import` to rebuild, or restore from S3 versioning. Never recreate blindly - causes duplicates |
| **How do you handle state drift?** | `terraform plan` detects drift, `terraform refresh` updates state, decide: apply or import |
| **How do you move resources between states?** | `terraform state mv`, `terraform state rm` + `import`, or `moved` blocks (v1.1+) |

### Modules & Structure
| Question | Key Points |
|----------|------------|
| **How do you structure Terraform for multiple environments?** | Workspaces, OR separate directories with shared modules, OR Terragrunt. I prefer separate dirs + modules for isolation |
| **What makes a good Terraform module?** | Single purpose, configurable via variables, sensible defaults, outputs for composition, versioned |
| **How do you version modules?** | Git tags, Terraform Registry, or S3. Pin versions in production: `version = "~> 2.0"` |

### Best Practices
| Question | Key Points |
|----------|------------|
| **How do you handle secrets in Terraform?** | Never in state/code. Use AWS Secrets Manager, SSM Parameter Store, Vault. Reference via data sources |
| **How do you test Terraform code?** | `terraform validate`, `terraform plan`, Terratest, Checkov/tfsec for security, sentinel policies |
| **What's your Terraform CI/CD workflow?** | PR → plan (comment on PR) → review → merge → apply. Use atlantis or TF Cloud for automation |

### Gotcha Questions
```
Q: What's the difference between count and for_each?
A: count uses index (fragile - reorders on change), for_each uses keys (stable). 
   Always prefer for_each for resources that might change.

Q: What does "terraform taint" do? (deprecated)
A: Marks resource for recreation. Now use: terraform apply -replace="aws_instance.example"

Q: How do you import existing infrastructure?
A: 1) Write the resource block first
   2) terraform import aws_instance.example i-1234567890
   3) Run plan to verify, adjust config until no changes

Q: What's a data source vs resource?
A: Resource = create/manage. Data source = read existing (lookup AMI, existing VPC, etc.)
```

---

## AWS NETWORKING

### VPC Design
| Question | Key Points |
|----------|------------|
| **Design a VPC for a 3-tier app** | Public (ALB), Private (App), Private (DB). 2+ AZs. NAT for outbound. CIDR planning for future growth |
| **Public vs Private subnet?** | Public: route to IGW, public IPs. Private: route to NAT, no public IPs |
| **When would you use VPC Peering vs Transit Gateway?** | Peering: few VPCs, simple. Transit Gateway: many VPCs, hub-spoke, centralized |
| **How do you connect on-prem to AWS?** | VPN (quick, encrypted over internet) or Direct Connect (dedicated, consistent latency) |

### Security
| Question | Key Points |
|----------|------------|
| **Security Group vs NACL?** | SG: stateful, instance-level, allow-only. NACL: stateless, subnet-level, allow+deny, numbered rules |
| **How would you secure a database?** | Private subnet, SG allows only app tier, no public IP, encryption at rest + transit, IAM auth |
| **What's defense in depth?** | Multiple security layers: SG + NACL + private subnets + WAF + encryption. If one fails, others protect |

### Load Balancing
| Question | Key Points |
|----------|------------|
| **ALB vs NLB vs CLB?** | ALB: L7/HTTP, path routing, WAF. NLB: L4/TCP, ultra-fast, static IP. CLB: legacy, avoid |
| **How does ALB health checking work?** | Configurable path/interval/threshold. Unhealthy targets removed from rotation, still checked for recovery |
| **Sticky sessions - when and why?** | When app has local state (avoid if possible). ALB uses cookies. Better: externalize state to Redis/DB |

---

## AWS COMPUTE

### EC2 & Auto Scaling
| Question | Key Points |
|----------|------------|
| **Launch Template vs Launch Config?** | Template: versioned, modifiable, more features. Config: immutable, legacy. Always use Template |
| **How does ASG decide which instance to terminate?** | Default: AZ balance → oldest launch config → closest to billing hour. Can customize with termination policies |
| **Scaling policies - which to use?** | Target Tracking (simplest, maintains metric). Step Scaling (granular control). Scheduled (predictable patterns) |
| **How do you do zero-downtime deployments with ASG?** | Rolling update, or blue/green with new ASG + ALB switch, or use CodeDeploy |

### Containers & Serverless
| Question | Key Points |
|----------|------------|
| **ECS vs EKS - when to use which?** | ECS: simpler, AWS-native, good for most cases. EKS: need K8s features, multi-cloud, existing K8s expertise |
| **Fargate vs EC2 launch type?** | Fargate: serverless, no instance management, pay per task. EC2: more control, can be cheaper at scale |
| **When Lambda vs containers?** | Lambda: short tasks (<15min), event-driven, variable load. Containers: long-running, consistent load, complex deps |

---

## CI/CD & DEPLOYMENTS

### Deployment Strategies
| Strategy | How It Works | Rollback | Best For |
|----------|--------------|----------|----------|
| **Blue-Green** | 2 identical envs, switch traffic instantly | Instant (switch back) | Critical apps, instant rollback |
| **Canary** | Route 5% → 25% → 50% → 100%, monitor at each step | Fast (route back to old) | Gradual validation, catch issues early |
| **Rolling** | Replace pods one by one (K8s default) | Slow (redeploy old) | Standard deployments |

### Pipeline Stages (Know This Flow)
```
Commit → Build → Test → SAST/SCA → Image Scan → Push → Dev → Staging → Approval → Prod → Verify
```

### Manual Approvals
| Question | Key Points |
|----------|------------|
| **How do you gate production deploys?** | GitHub: Environments + protection rules (required reviewers). Jenkins: input step. GitLab: manual jobs |
| **How do you promote images dev → prod?** | Build once, deploy many. Tag with git SHA, same image through all envs. Only config changes per env |

### Rollback
```bash
kubectl rollout undo deployment/NAME                    # Previous version
kubectl rollout undo deployment/NAME --to-revision=3   # Specific version
kubectl rollout history deployment/NAME                 # See history
```

### Pipeline Security / Hardening
| Stage | What It Does | Tools |
|-------|--------------|-------|
| **Secret Scanning** | Find leaked creds in code | gitleaks, trufflehog, GitHub secret scanning |
| **SAST** | Static code analysis | SonarQube, Semgrep, CodeQL |
| **SCA** | Scan dependencies for CVEs | Snyk, Dependabot, OWASP Dependency-Check |
| **Image Scanning** | Scan container for vulnerabilities | Trivy, Grype, Clair |
| **SBOM + Signing** | Bill of materials + verify image | Syft (SBOM), Cosign (signing) |

### Key Interview Answers
| Question | Answer |
|----------|--------|
| **Blue-green vs canary?** | Blue-green = instant rollback. Canary = validate with real traffic first, catch issues tests miss |
| **How do you secure pipelines?** | Secret scanning, dependency scanning (SCA), image scanning (Trivy), sign images, fail on HIGH/CRITICAL CVEs |
| **What's an SBOM?** | Software Bill of Materials - list of all components. Used for compliance + checking which services affected by new CVEs |
| **Secrets in pipelines?** | Never in code. GitHub encrypted secrets or Secrets Manager. Inject at runtime. Run secret scanning to catch leaks |

### Pipeline Design
| Question | Key Points |
|----------|------------|
| **Design a CI/CD pipeline for microservices** | Mono-repo or multi-repo, build on PR, test (unit/integration), security scan, build image, deploy to dev → staging → prod with gates |
| **How do you handle database migrations in CI/CD?** | Forward-compatible migrations, separate from app deploy, feature flags for breaking changes, never rollback DB |
| **How do you implement GitOps?** | Git = source of truth. Changes via PR. Automated sync (ArgoCD/Flux). Drift detection + reconciliation |

---

## AI IN CI/CD

### Core Use Cases
| Use Case | How It Works | Value |
|----------|--------------|-------|
| **Code Review** | AI analyzes PRs for bugs, security issues, best practices | Catches issues earlier, faster reviews |
| **Test Generation** | Auto-generate unit/integration tests for uncovered code | Improves coverage, saves time |
| **Security Scanning** | AI-powered vulnerability detection with fix suggestions | Actionable fixes, not just flags |
| **Deployment Intelligence** | Anomaly detection post-deploy, auto-rollback decisions | Safer deployments, faster response |
| **Documentation** | Auto-generate/update docs from code changes | Keeps docs in sync with code |

### Tools Ecosystem
| Tool | Use Case |
|------|----------|
| **GitHub Copilot/CLI** | Code suggestions, test generation |
| **Amazon CodeWhisperer** | AWS-focused code generation |
| **Snyk with AI** | Vulnerability detection + fix suggestions |
| **Codium AI** | Test generation for Python/JS |
| **Harness AI / Dynatrace Davis** | Deployment intelligence, monitoring |
| **OpenAI/Claude API** | Custom integrations |

### Pipeline Integration Example
```yaml
name: CI/CD with AI

on: [push, pull_request]

jobs:
  ai-enhanced-ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # AI code review
      - name: AI Code Analysis
        run: |
          # AI analyzes code for issues
          copilot-cli analyze --focus security,performance
      
      # Build and test
      - name: Build
        run: docker build -t myapp:${{ github.sha }} .
      
      # AI-enhanced security scanning
      - name: Security Scan
        run: |
          trivy image myapp:${{ github.sha }}
          snyk test --severity-threshold=high  # AI suggests fixes
      
      # AI analyzes test failures
      - name: Test & AI Failure Analysis
        run: |
          pytest || python ai_analyze_failures.py
          
  deploy:
    needs: ai-enhanced-ci
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to K8s
        run: kubectl apply -f manifests/
      
      # AI monitors deployment
      - name: AI Deployment Monitor
        run: |
          # Watches metrics, auto-rollback if anomalies
          ai-monitor --baseline last-7-days --threshold error-rate:5%
```

### Key Interview Q&A
| Question | Answer |
|----------|--------|
| **How would you use AI in CI/CD?** | Code review automation, test generation, security scanning with AI suggestions, deployment anomaly detection. AI augments, doesn't replace traditional tools |
| **Security concerns with AI?** | Never send secrets/PII to external APIs. Use self-hosted models for sensitive code. Always require human approval for AI-generated changes |
| **AI for rollback decisions?** | AI monitors post-deploy metrics, compares to baseline, can trigger auto-rollback. Keep humans in critical decisions |
| **Cost/performance impact?** | API rate limits, latency overhead. Use AI where it adds value - not everywhere. Start small, measure ROI |

### Best Practices
**DOs:**
- ✅ Use AI for repetitive tasks (docs, boilerplate, tests)
- ✅ Use AI for pattern recognition (anomalies, security)
- ✅ Always review AI suggestions before applying
- ✅ Start small, measure impact, expand gradually
- ✅ Keep humans in critical decision loops

**DON'Ts:**
- ❌ Send sensitive data to external AI APIs
- ❌ Auto-apply AI changes without review
- ❌ Replace all testing with AI-generated tests
- ❌ Trust AI for compliance/regulatory decisions

### Sample Answer for Interview
> "I'd integrate AI at multiple stages: **Pre-merge** for AI code review to catch issues early. **Testing** where AI generates tests for low-coverage areas that developers review. **Security** with AI-powered tools like Snyk that suggest fixes, not just flag issues. **Post-deploy** where AI monitors metrics and can trigger rollback.
> 
> Key principle: AI as force multiplier, not replacement. Always verify outputs. Start with low-risk areas, measure value, expand gradually. Never send secrets to external AI services."

---

## KUBERNETES

### Core Concepts
| Question | Key Points |
|----------|------------|
| **Pod vs Deployment vs Service?** | Pod: smallest unit (1+ containers). Deployment: manages ReplicaSets, rolling updates. Service: stable network endpoint |
| **How does a Service route traffic?** | Selects pods by labels, kube-proxy manages iptables/IPVS rules. ClusterIP (internal), NodePort, LoadBalancer |
| **What happens when a pod crashes?** | ReplicaSet detects, schedules new pod. Liveness probe failures trigger restart. Deployment maintains desired state |
| **Namespace use cases?** | Environment separation (dev/prod), team isolation, resource quotas, RBAC boundaries |
| **ConfigMap vs Secret?** | ConfigMap: non-sensitive config. Secret: base64 encoded (not encrypted by default), sensitive data |
| **StatefulSet vs Deployment?** | StatefulSet: stable network ID, ordered deployment, persistent storage. Deployment: stateless, replaceable pods |

### Troubleshooting Commands
```bash
# Pod Inspection
kubectl get pods -o wide                           # Pod status + node + IP
kubectl describe pod POD_NAME                      # Events, errors, conditions
kubectl logs POD_NAME -f                           # Follow logs
kubectl logs POD_NAME --previous                   # Logs from crashed container
kubectl exec -it POD_NAME -- /bin/sh               # Shell into pod

# Resource Inspection
kubectl top pods                                    # CPU/memory usage
kubectl top nodes                                   # Node resources
kubectl get events --sort-by='.lastTimestamp'       # Recent events
kubectl describe node NODE_NAME                     # Node capacity, conditions

# Debugging
kubectl get pvc                                     # PersistentVolumeClaims
kubectl get endpoints                               # Service endpoints
kubectl port-forward pod/POD_NAME 8080:80          # Local port forwarding

# Deployments
kubectl rollout status deployment/NAME              # Rollout status
kubectl rollout history deployment/NAME             # Rollout history
kubectl rollout undo deployment/NAME                # Rollback
kubectl scale deployment NAME --replicas=5          # Manual scaling
kubectl get hpa                                     # Autoscaler status
```

### Common Issues & Solutions
| Problem | Check | Solution |
|---------|-------|----------|
| **Pending** | `kubectl describe pod` | Insufficient resources, PVC not bound, node selectors/taints |
| **CrashLoopBackOff** | `kubectl logs --previous` | App crash, aggressive liveness probe, increase `initialDelaySeconds` |
| **ImagePullBackOff** | `kubectl describe pod` | Image doesn't exist, registry auth, typo in name |
| **OOMKilled** | `kubectl describe pod` | Increase memory limits, fix memory leak |

### Key Interview Q&A
| Question | Answer |
|----------|--------|
| **Pod stuck in Pending?** | 1) `describe pod` check Events 2) Insufficient resources? `describe node` 3) PVC bound? 4) Node selector/taint issues? |
| **Pod in CrashLoopBackOff?** | 1) `logs --previous` for crash reason 2) Liveness probe too aggressive? 3) Increase `initialDelaySeconds` 4) Resource limits too low? |
| **How does HPA work?** | Metrics Server collects CPU/memory, HPA queries every 15s, calculates: `desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]` |
| **Service not routing traffic?** | 1) Service selector matches pod labels? 2) `get endpoints` - any IPs? 3) Pods passing readiness probes? 4) NetworkPolicy blocking? |
| **NetworkPolicy?** | Default: all traffic allowed. Policy selects pods, defines ingress/egress rules. Needs CNI support (Calico, Cilium) |
| **RBAC components?** | ServiceAccount (identity), Role (permissions), RoleBinding (links them). ClusterRole/Binding for cluster-wide |
| **Explain pod lifecycle** | Pending → ContainerCreating → Running → (Succeeded/Failed). Init containers run first, then main containers |
| **What's a headless service?** | Service with `clusterIP: None`. No load balancing, returns pod IPs directly. Used for StatefulSets |

### Configuration Management
| Approach | Best For | Tools |
|----------|----------|-------|
| **Helm** | Complex apps, multiple environments | Helm charts, values.yaml files |
| **Kustomize** | Simple, GitOps-friendly | Base + overlays, no templating |
| **Both** | Helm for 3rd party, Kustomize for customization | Combined approach |

### Security Best Practices
| Area | Implementation |
|------|----------------|
| **RBAC** | ServiceAccount per app, minimal Role permissions, least privilege |
| **Network** | NetworkPolicy: default deny, allow only necessary traffic |
| **Pod Security** | Non-root user, read-only filesystem, drop capabilities, no privileged containers |
| **Image Security** | Scan in CI (Trivy/Snyk), private registry, image signing (Cosign) |
| **Secrets** | External Secrets Operator, Vault, AWS Secrets Manager. Never in Git |

**Secure Pod Example:**
```yaml
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
    resources:
      limits:
        memory: "512Mi"
        cpu: "500m"
```

### Monitoring & Scaling
| Type | Purpose | Implementation |
|------|---------|----------------|
| **Metrics** | Resource usage | Prometheus + Grafana, Metrics Server |
| **Logs** | Debugging | EFK stack, Loki |
| **Traces** | Request flow | Jaeger, Zipkin, X-Ray |
| **HPA** | Auto-scale on metrics | `kubectl autoscale deployment --cpu-percent=70 --min=2 --max=10` |
| **VPA** | Right-size resources | Recommends/applies resource changes |

---

## MULTI-CLUSTER KUBERNETES BOOTSTRAP PIPELINE

### Opening Statement (30 seconds)

> "I built a **reusable GitHub Actions workflow** for bootstrapping multiple Kubernetes clusters in parallel. It's designed for multi-cluster environments where you need to deploy the same infrastructure stack - ArgoCD, Sealed Secrets, ingress controllers, and other core components - across different clusters with cluster-specific configurations. The workflow supports both targeted deployments to a single cluster and mass deployments to all clusters simultaneously using dynamic matrix strategies."

---

### High-Level Architecture

**Structure:**
```
Parent Workflow (manual/scheduled trigger)
    ↓ (calls)
Reusable Bootstrap Workflow
    ↓
Job 1: Build Dynamic Matrix (which clusters?)
    ↓
Job 2: Deploy Software (N parallel jobs, one per cluster)
```

**Key Flow:**
1. **Accepts parameters**: Cluster name (or "all"), environment (prod/non-prod), JSON payload with cluster metadata
2. **Dynamically generates matrix**: Filters JSON based on input, creates parallel jobs
3. **Authenticates to GCP**: Uses Workload Identity Federation (no stored keys)
4. **Deploys ~15 Kubernetes components**: ArgoCD, Config Sync, ingress, secrets management, etc.
5. **Runs in parallel**: If targeting 5 clusters, spawns 5 runners simultaneously

---

### Technical Decisions & Talking Points

#### 1. Reusable Workflow Pattern
> "I used GitHub Actions' `workflow_call` to make this reusable. Other workflows can invoke this as a function, passing different parameters. This means I can trigger it manually, on a schedule, or as part of a PR preview environment workflow without duplicating code."

**Key Benefit**: DRY principle - one workflow definition, multiple trigger contexts

---

#### 2. Dynamic Matrix Strategy
> "Instead of hardcoding cluster names, I built a dynamic matrix using JSON input and `jq` filtering. The first job determines which clusters to target, then outputs a matrix that the second job uses to spawn parallel runners. This makes it flexible - I can deploy to one cluster for testing or all clusters for a production rollout."

**Implementation:**
```yaml
# Job 1: Filter clusters
jq --arg c "$CLUSTER_NAME" '[.[] | select(.cluster == $c)]'

# Job 2: Use matrix
strategy:
  matrix: ${{ fromJson(needs.set-target-clusters.outputs.matrix) }}
```

---

#### 3. Dynamic Secret Resolution
> "Each cluster needs its own TLS certificates for ArgoCD. Rather than hardcoding secret names, I store a mapping in the JSON input (e.g., `key_secret_name: "PROD_WAREHOUSE_KEY"`). The workflow then uses `secrets[matrix.key_secret_name]` to dynamically pull the correct secret at runtime. This scales cleanly as we add more clusters."

**Pattern:**
```yaml
# Input JSON
{"cluster": "prod-warehouse", "key_secret_name": "PROD_WAREHOUSE_KEY"}

# Dynamic resolution
echo "${{ secrets[matrix.key_secret_name] }}" > argo.key
```

---

#### 4. Helm Diff Before Upgrade
> "Before every Helm deployment, I run `helm diff` with `--detailed-exitcode`. If there are no changes, the upgrade is skipped. If changes are detected, it proceeds with `helm upgrade --atomic`, which auto-rolls back if the deployment fails. This prevents unnecessary deployments and ensures safe updates."

**Pattern:**
```bash
helm diff upgrade ... --detailed-exitcode || \
helm upgrade ... --atomic --timeout 15m
```

**Benefits:** 
- Avoids unnecessary deployments
- Provides change visibility
- Auto-rollback on failure

---

#### 5. Conditional Deployments
> "Not all clusters are identical. For example, only our `prod-buying` cluster needs Argo Workflows and Argo Events. I use GitHub Actions' `if: contains(fromJSON('[...]'), matrix.cluster)` to conditionally run steps based on cluster name. This keeps the workflow DRY while supporting cluster-specific requirements."

**Implementation:**
```yaml
- name: Install Argo Workflows
  if: contains(fromJSON('["prod-buying", "prod-retail"]'), matrix.cluster)
  run: ...
```

---

#### 6. Workload Identity Federation
> "For GCP authentication, I use Workload Identity Federation with OIDC tokens instead of storing service account keys in GitHub secrets. This is more secure - no key rotation needed, and tokens are short-lived."

**Security Benefits:**
- No long-lived credentials stored
- Automatic token expiry
- Native GCP integration
- Audit trail in GCP logs

---

### Problems It Solves

| Problem | Solution |
|---------|----------|
| **Multi-cluster consistency** | Ensures all 8+ GKE clusters have identical baseline infrastructure |
| **Disaster recovery** | Can rebuild a destroyed cluster in ~15 minutes |
| **New cluster onboarding** | Add JSON metadata, run workflow - fully automated setup |
| **Configuration drift** | Version-controlled infra prevents manual kubectl changes |
| **Time efficiency** | Parallel execution: 8 clusters in 15-20 min vs 2+ hours sequential |

---

### Production-Grade Features

**Why This is Production-Ready:**

1. **Idempotent operations**: `kubectl apply` and `helm upgrade --atomic` allow repeated runs without breaking things

2. **Automatic rollback**: `--atomic` flag rolls back failed Helm upgrades automatically

3. **Audit trail**: All deployments logged in GitHub Actions with full visibility

4. **Secret management**: Secrets encrypted, pulled dynamically, used once, deleted immediately

5. **Policy Controller integration**: Labels namespaces for exemptions where needed

6. **Version pinning**: Each component version in `version.txt` - independent upgrades and easy rollbacks

---

### Interview Q&A

#### Q: How do you handle failures?

> "Helm's `--atomic` flag handles deployment failures - it automatically rolls back. If the workflow itself fails (e.g., GCP auth issues), the GitHub Actions job fails and we get Slack/email alerts. For critical failures, I'd run the workflow again with just the failed cluster targeted."

---

#### Q: How do you test changes to this workflow?

> "I have a dedicated `non-prod-test` cluster. I make changes in a feature branch, then manually trigger the workflow targeting only that test cluster. Once validated, I merge to main. For breaking changes, I'd use GitHub's workflow preview feature or run it in a sandbox environment."

---

#### Q: What if you need to add a new component to all clusters?

> "I add the Helm installation steps to the workflow, commit, then run it with `cluster: all`. Because Helm is idempotent, existing components stay untouched, and only the new component gets deployed. I'd do it in non-prod first to validate."

---

#### Q: How do you handle cluster-specific configurations?

> "Each cluster has its own directory with `values.yaml` files. The workflow uses `./ArgoCD/${{ matrix.cluster }}/values.yaml`, so cluster-specific settings (like replica counts, resource limits, ingress domains) are all version-controlled and unique per cluster."

**Directory Structure:**
```
ArgoCD/
├── prod-warehouse/
│   ├── values.yaml
│   └── version.txt
├── prod-retail/
│   ├── values.yaml
│   └── version.txt
└── non-prod-ecom/
    ├── values.yaml
    └── version.txt
```

---

#### Q: Why not use Terraform or Pulumi instead?

> "Great question. We use Terraform for the cluster provisioning itself, but for in-cluster Kubernetes resources, Helm + kubectl gives us better integration with our GitOps setup. ArgoCD manages application deployments, and this workflow handles the platform layer. It's a clean separation of concerns."

**Separation of Concerns:**
- **Terraform**: GKE cluster provisioning, node pools, networking
- **This Workflow**: In-cluster platform components (ArgoCD, ingress, etc.)
- **ArgoCD**: Application deployments (managed by dev teams)

---

#### Q: What about secrets rotation?

> "GitHub secrets are rotated manually via our secrets management process. For Kubernetes secrets, we use External Secrets Operator synced to GCP Secret Manager, which supports auto-rotation. The workflow just ensures ESO is installed and configured correctly."

---

#### Q: How long does a full deployment take?

> "For a single cluster, about 10-15 minutes. For all clusters in parallel, 15-20 minutes since some steps are I/O bound (pulling Helm charts, waiting for rollouts). The matrix strategy gives us near-linear scaling."

**Timing Breakdown:**
- GCP authentication: ~30s
- Get kubeconfig: ~15s
- Helm installations: ~8-10 min (largest component)
- Config sync setup: ~2 min
- Validation: ~1 min

---

### What I Would Improve

| Improvement | Why | How |
|-------------|-----|-----|
| **Add retry logic** | Transient failures cause full job failure | Implement exponential backoff for GCP/Helm operations |
| **Pre-flight validation** | Fail fast on missing secrets/malformed JSON | Add validation job before deployment |
| **Drift detection** | Manual changes go unnoticed | Daily scheduled job comparing actual vs expected state |
| **Move cluster lists to files** | Hardcoded lists in conditionals are fragile | Use cluster metadata YAML defining required features |
| **Add smoke tests** | Deploy success doesn't guarantee functionality | Post-deploy health checks (ArgoCD reachable, ingress responds) |
| **Terraform integration** | Currently separate workflows | Trigger this after Terraform cluster creation automatically |

---

### Real-World Example

> "Last month, we needed to upgrade ArgoCD across all clusters. I bumped the version in the `version.txt` file, ran this workflow with `cluster: all`, and within 20 minutes, all 8 clusters had the new ArgoCD version deployed. Two clusters had custom configurations in their `values.yaml` files, and those were preserved automatically. No manual kubectl commands, no SSH-ing into clusters."

**What this demonstrates:**
- Version management simplicity
- Parallel execution efficiency
- Configuration preservation
- Zero manual intervention
- Full audit trail

---

### Quick Reference Card

| Aspect | Details |
|--------|---------|
| **Type** | Reusable GitHub Actions workflow |
| **Purpose** | Multi-cluster Kubernetes platform bootstrapping |
| **Key Technologies** | GitHub Actions, Helm, kubectl, GCP Workload Identity, dynamic matrices |
| **Scale** | 8+ clusters, parallel execution, ~15-20 min for all |
| **Components Deployed** | ArgoCD, Config Sync, Policy Controller, Sealed Secrets, nginx ingress, F5 CIS, External Secrets Operator, Secrets Store CSI Driver |
| **Execution Model** | Parallel jobs via dynamic matrix |
| **Safety Mechanisms** | Idempotent operations, atomic rollbacks, helm diff |
| **Security** | Workload Identity Federation, encrypted secrets, no stored keys |
| **Flexibility** | Target single cluster or all, dynamic secret mapping, conditional deployments |

---

### Key Metrics to Mention

- **Clusters managed**: 8+
- **Deployment time (single)**: 10-15 minutes
- **Deployment time (all parallel)**: 15-20 minutes
- **Components per cluster**: ~15
- **Time saved vs sequential**: 70-80% reduction
- **Manual interventions needed**: 0
- **Successful deployments**: 100+ (track this if possible)

---

### Architecture Diagram (Describe Verbally)
```
GitHub Actions Runner
    ↓
Workload Identity Federation (OIDC)
    ↓
GCP Project
    ↓
GKE Clusters (8+)
    ├── Cluster 1: [ArgoCD, ingress, secrets, ...]
    ├── Cluster 2: [ArgoCD, ingress, secrets, ...]
    └── Cluster N: [ArgoCD, ingress, secrets, ...]
```

---

### Sample STAR Story

**Situation**: "We had 8 GKE clusters across different environments with inconsistent configurations. Manual deployments were error-prone and took hours."

**Task**: "I was tasked with creating an automated, consistent way to bootstrap all clusters with platform components."

**Action**: "I built a reusable GitHub Actions workflow using dynamic matrices for parallel execution, Workload Identity for secure GCP access, and Helm with atomic rollbacks for safe deployments. I implemented conditional logic for cluster-specific components and dynamic secret resolution for TLS certificates."

**Result**: "Deployment time reduced from 2+ hours to 15 minutes. We achieved 100% consistency across clusters, zero manual interventions, and full audit trails. When we needed to upgrade ArgoCD across all clusters, it took 20 minutes instead of a full day."

---

### Technical Deep Dive (If Asked)

**How Dynamic Matrix Works:**
```yaml
# Step 1: Filter JSON
SEL='prod-warehouse'
FINAL=$(jq --arg c "$SEL" '[.[] | select(.cluster == $c)]' clusters.json)

# Step 2: Format for GitHub Actions
echo "matrix={\"include\":$FINAL}" >> $GITHUB_OUTPUT

# Step 3: Consume in next job
strategy:
  matrix: ${{ fromJson(needs.set-target-clusters.outputs.matrix) }}

# Step 4: Access in steps
${{ matrix.cluster }}
${{ matrix.key_secret_name }}
```

**Helm Diff Exit Codes:**
- **0**: No changes needed
- **1**: Error occurred
- **2**: Changes detected

Pattern: `helm diff ... --detailed-exitcode || helm upgrade ...`
- If exit code is 0 or 2, proceed with upgrade
- If exit code is 1, fail

**Workload Identity Federation Flow:**
```
GitHub Actions job starts
    ↓
Request OIDC token from GitHub
    ↓
Present token to GCP Workload Identity
    ↓
GCP validates token and issues short-lived credentials
    ↓
Use credentials to authenticate kubectl/helm
```

---

### Behavioral Interview Angle

**Collaboration:**
"I worked with the platform team to define requirements, the security team to implement Workload Identity, and dev teams to understand which components were critical. We iterated on the design over several weeks."

**Problem-Solving:**
"Initially, we had a sequencing issue where nginx ingress would deploy before cert-manager was ready. I added health checks between steps and used Helm's `--wait` flag to ensure proper ordering."

**Learning:**
"I had never used GitHub Actions' reusable workflows before this. I studied the documentation, looked at open-source examples, and experimented in a test environment before implementing in production."

---

## LINUX

### Essential Commands
```bash
# Files & Navigation
ls -la                    # List all with permissions
find /var -name "*.log" -mtime +7    # Find files older than 7 days
grep -r "error" /var/log  # Search recursively
tail -f /var/log/syslog   # Follow log in real-time
wc -l file.txt            # Count lines

# Processes
ps aux | grep nginx       # Find process
top / htop                # Real-time process monitor
kill -9 PID               # Force kill process
systemctl status nginx    # Check service status
journalctl -u nginx -f    # Follow service logs

# Disk
df -h                     # Disk usage (human readable)
du -sh /var/*             # Directory sizes
lsof +D /var/log          # What's using this directory

# Network
ss -tulnp                 # Listening ports (netstat replacement)
curl -I https://site.com  # HTTP headers only
nc -vz host 443           # Test port connectivity
dig google.com            # DNS lookup
ip addr                   # IP addresses
```

### Key Interview Q&A
| Question | Answer |
|----------|--------|
| **Server slow - how to diagnose?** | `top` (CPU/memory), `df -h` (disk), `free -m` (RAM), `iostat` (I/O), `ss -tulnp` (connections) |
| **Disk full - how to fix?** | `df -h` (which mount), `du -sh /*` (what's using it), find large files, check logs, clear old data |
| **Process using port 80?** | `ss -tulnp | grep :80` or `lsof -i :80` |
| **Check why service failed?** | `systemctl status SERVICE`, then `journalctl -u SERVICE -n 50` |
| **What's in /etc/passwd?** | User accounts. Format: `user:x:UID:GID:comment:home:shell` |
| **File permissions 755?** | Owner: rwx (7), Group: r-x (5), Others: r-x (5). `chmod 755 file` |
| **How to run command on boot?** | systemd unit file, or cron `@reboot`, or `/etc/rc.local` |

### Systemd Essentials
```bash
systemctl start|stop|restart nginx    # Control service
systemctl enable nginx                # Start on boot
systemctl status nginx                # Check status
journalctl -u nginx -f                # Follow logs
journalctl -u nginx --since "1 hour ago"  # Recent logs
```

---

## MONITORING & OBSERVABILITY

### Core Concepts
| Question | Key Points |
|----------|------------|
| **Metrics vs Logs vs Traces?** | Metrics: numeric time-series (CPU, requests). Logs: events/details. Traces: request flow across services |
| **What would you monitor for a web app?** | Latency (p50/p95/p99), error rate, throughput, saturation. Plus business metrics |
| **How do you set up alerting that doesn't cause fatigue?** | Alert on symptoms not causes, actionable alerts only, proper severity levels, runbooks for each alert |
| **Explain the USE method** | Utilization, Saturation, Errors - for every resource. Simple framework for system analysis |
| **Explain the RED method** | Rate, Errors, Duration - for services. Request-focused monitoring |

### Tools
| Question | Key Points |
|----------|------------|
| **CloudWatch vs Prometheus/Grafana?** | CloudWatch: native, easy, good enough for most. Prometheus: more powerful, better for K8s, self-managed |
| **How do you implement distributed tracing?** | X-Ray, Jaeger, or Datadog. Instrument code, propagate trace IDs, visualize request flow |

---

## RELIABILITY & INCIDENT MANAGEMENT

### High Availability
| Question | Key Points |
|----------|------------|
| **How do you design for high availability?** | Multi-AZ (99.99%), multi-region for DR. No single points of failure. Health checks + auto-recovery |
| **RTO vs RPO?** | RTO: max downtime tolerance. RPO: max data loss tolerance. Drive backup/replication strategy |
| **How do you handle an AZ failure?** | Multi-AZ already handles it. ASG replaces instances. RDS fails over. ALB routes around it |

### Incident Response
| Question | Key Points |
|----------|------------|
| **Walk me through an incident response** | Detect → Triage (severity) → Mitigate (restore service) → Root cause → Fix → Post-mortem → Prevent |
| **What's in a good post-mortem?** | Blameless, timeline, root cause, what worked, what didn't, action items with owners and dates |
| **How do you do chaos engineering?** | Start small (kill one instance), have hypothesis, measure impact, run in prod (carefully). Tools: Chaos Monkey, Litmus |

---

## SECURITY

### IAM & Access
| Question | Key Points |
|----------|------------|
| **Explain least privilege** | Grant minimum permissions needed. Start with none, add as needed. Review regularly |
| **IAM Role vs User?** | Roles: for services/apps, temporary creds, assumable. Users: for humans, permanent creds, should use SSO instead |
| **How do you audit AWS access?** | CloudTrail (API logs), IAM Access Analyzer, Config rules, regular access reviews |

### Application Security
| Question | Key Points |
|----------|------------|
| **How do you handle secrets management?** | Secrets Manager or SSM Parameter Store. Auto-rotation. Never in code/env vars. Audit access |
| **How do you secure containers?** | Minimal base image, scan for CVEs, non-root user, read-only filesystem, network policies |
| **What's shift-left security?** | Security early in SDLC. Scan in CI, security requirements in design, developer training |

---

## SYSTEM DESIGN (QUICK PATTERNS)

### Common Architectures + Repo Structure

#### 1. Web App
```
Route53 → CloudFront → ALB → ASG (EC2/ECS) → RDS + ElastiCache
```
**Repo Structure: Monorepo**
```
web-app/
├── infra/                    # Terraform
│   ├── modules/
│   │   ├── vpc/
│   │   ├── alb/
│   │   ├── asg/
│   │   └── rds/
│   └── envs/
│       ├── dev/
│       └── prod/
├── src/                      # Application code
├── Dockerfile
├── .github/workflows/
│   ├── build.yml            # Build + test + push image
│   ├── deploy-dev.yml       # Deploy to dev
│   └── deploy-prod.yml      # Deploy to prod (with approval)
└── README.md
```
**Why Monorepo:** Single app, infra tightly coupled, easier to manage.

---

#### 2. Event-Driven / Serverless
```
API GW → Lambda → SQS/SNS → Lambda → DynamoDB
```
**Repo Structure: Monorepo + SAM/Serverless Framework**
```
serverless-app/
├── infra/                    # Terraform for shared infra
│   ├── api-gateway/
│   ├── dynamodb/
│   └── sqs-sns/
├── functions/                # Lambda functions
│   ├── order-processor/
│   │   ├── handler.py
│   │   └── requirements.txt
│   ├── notification-sender/
│   └── data-transformer/
├── template.yaml             # SAM template (or serverless.yml)
├── .github/workflows/
│   └── deploy.yml           # sam build && sam deploy
└── README.md
```
**Why Monorepo:** Functions often share code/libs, deploy together, easier testing.

---

#### 3. Data Pipeline
```
Kinesis/Kafka → Lambda/EMR → S3 → Athena/Redshift
```
**Repo Structure: Monorepo with clear separation**
```
data-platform/
├── infra/                    # Terraform
│   ├── kinesis/
│   ├── s3-buckets/
│   ├── emr/
│   ├── glue/
│   └── redshift/
├── ingestion/                # Data ingestion code
│   ├── kinesis-producer/
│   └── kafka-connectors/
├── processing/               # ETL/ELT jobs
│   ├── spark-jobs/
│   ├── glue-scripts/
│   └── lambda-transforms/
├── analytics/                # SQL, dashboards
│   ├── athena-queries/
│   └── redshift-views/
├── .github/workflows/
│   ├── deploy-infra.yml
│   └── deploy-jobs.yml
└── README.md
```
**Why Monorepo:** Data pipelines are interdependent, schema changes affect multiple stages.

---

#### 4. Microservices
```
API GW → ALB → ECS/EKS → Service Mesh (App Mesh) → RDS/DynamoDB
```
**Repo Structure: Polyrepo (separate repo per service)**
```
# Organization level
org/
├── platform-infra/           # Shared infra (VPC, EKS, RDS)
│   ├── terraform/
│   └── .github/workflows/
│
├── user-service/             # Each service = own repo
│   ├── src/
│   ├── Dockerfile
│   ├── k8s/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   ├── .github/workflows/
│   │   └── build-deploy.yml
│   └── README.md
│
├── order-service/
│   └── ... (same structure)
│
├── payment-service/
│   └── ... (same structure)
│
└── shared-libs/              # Shared libraries (optional)
    ├── auth-lib/
    └── logging-lib/
```
**Why Polyrepo:** 
- Independent deployments (team autonomy)
- Different release cycles
- Blast radius isolation
- Clear ownership

**Alternative: Monorepo for Microservices** (works for smaller teams)
```
microservices-monorepo/
├── services/
│   ├── user-service/
│   ├── order-service/
│   └── payment-service/
├── libs/                     # Shared code
├── infra/
├── k8s/                      # All K8s manifests
│   ├── base/
│   └── overlays/
│       ├── dev/
│       └── prod/
└── .github/workflows/
    └── ci.yml               # Build only changed services
```

---

### Repo Strategy Decision Matrix

| Factor | Monorepo | Polyrepo |
|--------|----------|----------|
| **Team size** | Small-medium (<20 devs) | Large (20+ devs) |
| **Deploy frequency** | Deploy together | Independent releases |
| **Code sharing** | Lots of shared code | Minimal sharing |
| **Ownership** | Shared/overlapping | Clear team boundaries |
| **CI/CD complexity** | Simpler (one pipeline) | More pipelines, more flexible |
| **Examples** | Google, Meta, Uber | Netflix, Amazon, Spotify |

### Quick Answer for Interview
> "For microservices, I prefer **polyrepo** - each service has its own repo, CI/CD, and team ownership. Shared infra lives in a platform repo. This gives teams autonomy and isolates blast radius. For smaller teams or tightly coupled apps, **monorepo** with path-based CI triggers works well."

### Scaling Strategies
| Problem | Solution |
|---------|----------|
| Database bottleneck | Read replicas, caching (ElastiCache), sharding |
| Compute bottleneck | Horizontal scaling (ASG), larger instances, optimize code |
| Global latency | CloudFront, multi-region, Global Accelerator |
| Burst traffic | Queue (SQS) to decouple, Lambda for auto-scale |

---

## PYTHON FOR DEVOPS

### Quick Skeleton
```python
#!/usr/bin/env python3
"""Script to do X. Usage: python script.py --env dev --dry-run"""

import os, sys, logging, argparse, boto3, requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main(env: str, dry_run: bool = False):
    try:
        # Your logic here
        logger.info(f"Running for {env}")
        if dry_run:
            logger.info("DRY RUN - no changes made")
    except Exception as e:
        logger.error(f"Failed: {e}")
        sys.exit(1)  # Non-zero exit = CI/CD knows it failed

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--env', required=True, choices=['dev', 'staging', 'prod'])
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    main(args.env, args.dry_run)
```

### DevOps Python Interview Q&A

| Question | Answer |
|----------|--------|
| **How do you run shell commands?** | `subprocess.run(['kubectl', 'get', 'pods'], check=True, capture_output=True)` |
| **How do you handle secrets?** | `os.environ.get('API_KEY')` - never hardcode |
| **How do you make HTTP calls?** | `requests.get(url, timeout=5)` + `response.raise_for_status()` |
| **How do you parse JSON/YAML?** | `json.load(f)` / `yaml.safe_load(f)` |
| **Why logging not print?** | Configurable levels, timestamps, can send to file/external systems |
| **Why `sys.exit(1)`?** | Non-zero exit code tells CI/CD pipeline the script failed |
| **What's `if __name__ == "__main__"`?** | Only runs when executed directly, not when imported |
| **What's `--dry-run` for?** | Preview changes without executing - safety for destructive scripts |
| **How do you retry failed operations?** | Try/except in a loop with exponential backoff, or use `tenacity` library |
| **Threading vs multiprocessing?** | Threading for I/O-bound (HTTP, files), multiprocessing for CPU-bound |

### Common Libraries
| Library | Use Case |
|---------|----------|
| `boto3` | AWS SDK (EC2, S3, IAM) |
| `requests` | HTTP calls, APIs |
| `subprocess` | Run shell commands |
| `json` / `yaml` | Config files |
| `argparse` | CLI arguments |
| `logging` | Production logging |

### Practical Script: Auto-Shutdown Dev VMs at 6PM
```python
#!/usr/bin/env python3
"""
Auto-shutdown script for dev EC2 instances.
Finds all running instances tagged Environment=dev and stops them.
Designed to run via cron/EventBridge at 6PM to save costs.

Usage:
    python shutdown_dev.py --dry-run     # Preview what would stop
    python shutdown_dev.py               # Actually stop instances
    
Cron example (6PM daily):
    0 18 * * * /usr/bin/python3 /opt/scripts/shutdown_dev.py
"""

import boto3
import logging
import argparse
import sys
from datetime import datetime

# ============ LOGGING SETUP ============
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============ CONFIGURATION ============
# Tag to identify dev instances - change as needed
TARGET_TAG_KEY = 'Environment'
TARGET_TAG_VALUE = 'dev'
AWS_REGION = 'eu-west-2'


def get_running_dev_instances(ec2_client) -> list:
    """
    Find all running EC2 instances tagged as dev environment.
    
    Returns:
        List of instance dictionaries with id, name, type, launch_time
    """
    # AWS filter: running instances with Environment=dev tag
    filters = [
        {'Name': 'instance-state-name', 'Values': ['running']},
        {'Name': f'tag:{TARGET_TAG_KEY}', 'Values': [TARGET_TAG_VALUE]}
    ]
    
    response = ec2_client.describe_instances(Filters=filters)
    
    instances = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            # Extract Name tag if it exists
            name = 'No Name'
            for tag in instance.get('Tags', []):
                if tag['Key'] == 'Name':
                    name = tag['Value']
                    break
            
            instances.append({
                'id': instance['InstanceId'],
                'name': name,
                'type': instance['InstanceType'],
                'launch_time': instance['LaunchTime'].strftime('%Y-%m-%d %H:%M')
            })
    
    return instances


def stop_instances(ec2_client, instance_ids: list, dry_run: bool = False) -> bool:
    """
    Stop the specified EC2 instances.
    
    Args:
        ec2_client: boto3 EC2 client
        instance_ids: List of instance IDs to stop
        dry_run: If True, only simulate the stop
        
    Returns:
        True if successful, False otherwise
    """
    if not instance_ids:
        logger.info("No instances to stop")
        return True
    
    try:
        if dry_run:
            # AWS dry-run will raise exception but validates permissions
            try:
                ec2_client.stop_instances(InstanceIds=instance_ids, DryRun=True)
            except ec2_client.exceptions.ClientError as e:
                if 'DryRunOperation' in str(e):
                    logger.info("DRY RUN - permission check passed")
                    return True
                raise
        else:
            ec2_client.stop_instances(InstanceIds=instance_ids)
            logger.info(f"Stop command sent for {len(instance_ids)} instances")
        return True
        
    except Exception as e:
        logger.error(f"Failed to stop instances: {e}")
        return False


def main(dry_run: bool = False):
    """Main entry point."""
    logger.info(f"{'[DRY RUN] ' if dry_run else ''}Starting dev instance shutdown")
    logger.info(f"Looking for instances with tag {TARGET_TAG_KEY}={TARGET_TAG_VALUE}")
    
    # Initialize AWS client
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    
    # Find running dev instances
    instances = get_running_dev_instances(ec2)
    
    if not instances:
        logger.info("No running dev instances found - nothing to do")
        return
    
    # Log what we found
    logger.info(f"Found {len(instances)} running dev instance(s):")
    for inst in instances:
        logger.info(f"  - {inst['id']} | {inst['name']} | {inst['type']} | Started: {inst['launch_time']}")
    
    # Stop them
    instance_ids = [inst['id'] for inst in instances]
    
    if dry_run:
        logger.info(f"DRY RUN - would stop: {instance_ids}")
    else:
        success = stop_instances(ec2, instance_ids, dry_run=False)
        if success:
            logger.info(f"Successfully initiated shutdown for {len(instance_ids)} instances")
        else:
            logger.error("Failed to stop instances")
            sys.exit(1)
    
    logger.info("Shutdown script completed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Stop all running EC2 instances tagged as dev environment'
    )
    parser.add_argument(
        '--dry-run', 
        action='store_true',
        help='Preview what would be stopped without actually stopping'
    )
    
    args = parser.parse_args()
    main(dry_run=args.dry_run)
```

**Key Points to Explain:**
- Uses **tags** to identify dev instances (`Environment=dev`)
- **`--dry-run`** flag for safe testing
- **Logging** with timestamps for audit trail
- **`sys.exit(1)`** on failure so cron/CI knows it failed
- Can run via **cron** or **AWS EventBridge** at 6PM daily
- Saves **~30-40% costs** by stopping non-prod overnight/weekends

---

## BEHAVIORAL TIPS

### STAR Format for Stories
```
Situation: Brief context
Task: Your responsibility  
Action: What YOU did (specific)
Result: Quantified outcome
```

### Have Stories Ready For:
- Incident you resolved under pressure
- System you designed/improved
- Time you disagreed with team/decision
- Failure and what you learned
- Cross-team collaboration
- Mentoring/leading others

### Questions to Ask Them:
- "What does on-call look like?"
- "How do you handle tech debt?"
- "What's the team's biggest challenge right now?"
- "How are infrastructure decisions made?"
- "What does success look like in 6 months?"

---

**Remember:** It's OK to say *"I don't know, but here's how I'd figure it out..."* - shows problem-solving > memorization.

**Good luck! 🚀**
