# Senior DevOps/Cloud Engineer - Interview Cheat Sheet 📋

---

## 📋 TABLE OF CONTENTS

| # | Section | Topics |
|---|---------|--------|
| 1 | [Terraform](#terraform) | State, modules, best practices, gotchas |
| 2 | [AWS Networking](#aws-networking) | VPC, security groups, load balancing |
| 3 | [AWS Compute](#aws-compute) | EC2, ASG, containers, serverless |
| 4 | [CI/CD & Deployments](#cicd--deployments) | Strategies, implementation, rollback, security |
| 5 | [AI in CI/CD](#ai-in-cicd) | Tools, integration, best practices |
| 6 | [Kubernetes](#kubernetes) | Core concepts, troubleshooting, security, CronJobs |
| 7 | [Multi-Cluster K8s Pipeline](#multi-cluster-kubernetes-bootstrap-pipeline) | Reusable workflow, parallel deployment |
| 8 | [Linux](#linux) | Commands, troubleshooting, systemd |
| 9 | [Monitoring & Observability](#monitoring--observability) | Metrics, logs, traces, alerting |
| 10 | [Reliability & Incidents](#reliability--incident-management) | HA, incident response, chaos |
| 11 | [Security](#security) | IAM, secrets, containers |
| 12 | [System Design](#system-design-quick-patterns) | Architectures, scaling, repo strategies |
| 13 | [Python for DevOps](#python-for-devops) | Skeleton, Q&A, practical examples |
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

### Deployment Strategies Overview

| Strategy | How It Works | Rollback | Best For |
|----------|--------------|----------|----------|
| **Blue-Green** | 2 identical envs, switch traffic instantly | Instant (switch back) | Critical apps, instant rollback |
| **Canary** | Route 5% → 25% → 50% → 100%, monitor at each step | Fast (route back to old) | Gradual validation, catch issues early |
| **Rolling** | Replace pods one by one (K8s default) | Slow (redeploy old) | Standard deployments |

---

### 1. BLUE-GREEN DEPLOYMENT

**Concept:** Two identical environments. Switch traffic instantly between them.

**AWS Architecture:**
```
ALB → Blue Target Group (100%) → v1.0
    → Green Target Group (0%) → v2.0
```

**Key Commands:**
```bash
# Deploy green environment
aws autoscaling create-auto-scaling-group --auto-scaling-group-name green-asg ...

# Switch traffic to green
aws elbv2 modify-listener --default-actions TargetGroupArn=green-tg

# Rollback (instant)
aws elbv2 modify-listener --default-actions TargetGroupArn=blue-tg
```

**Kubernetes:**
```yaml
# Service switches between deployments via selector
selector:
  version: blue  # Change to 'green' to switch
```
```bash
# Switch traffic
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'
```

**Interview Q&A:**
| Question | Answer |
|----------|--------|
| **When to use?** | Critical apps needing instant rollback, zero downtime requirements |
| **Cost?** | 2x infrastructure during deployment |
| **Database migrations?** | Backward-compatible schema changes. Deploy DB first, never rollback DB |

---

### 2. CANARY DEPLOYMENT

**Concept:** Gradually shift traffic: 5% → 25% → 50% → 100%

**AWS Architecture:**
```
ALB → Stable TG (95% weight) → v1.0
    → Canary TG (5% weight) → v2.0
```

**Key Commands:**
```bash
# Configure 5% canary
aws elbv2 modify-listener --default-actions \
  '[{"Type":"forward","ForwardConfig":{
    "TargetGroups":[
      {"TargetGroupArn":"stable-tg","Weight":95},
      {"TargetGroupArn":"canary-tg","Weight":5}
    ]}}]'

# Increase to 25%, 50%, 100%...
# Rollback: Set weight to 0
```

**Kubernetes (Nginx Ingress):**
```yaml
# Canary ingress annotation
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-weight: "10"
```

**Kubernetes (Argo Rollouts):**
```yaml
strategy:
  canary:
    steps:
    - setWeight: 10
    - pause: {duration: 5m}
    - setWeight: 25
    ...
```

**Canary vs Route 53 (Critical):**

| Method | Rollback Speed | Use Case |
|--------|----------------|----------|
| **Route 53 Weighted** | Slow (TTL 60-300s) | ❌ NOT for canary |
| **ALB Weighted TG** | Instant | ✅ Production canary |
| **Ingress Annotations** | Instant | ✅ K8s canary |

**Interview Answer:**
> "Route 53 has DNS caching (TTL), preventing instant rollback. The correct approach is ALB weighted target groups or nginx ingress annotations for instant traffic control."

**Monitoring:**
- Error rate: must be ≤ stable version
- Latency: p95/p99 shouldn't increase
- Auto-rollback if error rate >2% higher

---

### 3. ROLLING DEPLOYMENT

**Concept:** Replace pods/instances gradually

**Kubernetes:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 2        # Extra pods during update
    maxUnavailable: 1  # Max unavailable pods
```

**How it works:**
```
10 pods v1.0 → Create 2 v2.0 → Wait for ready → 
Terminate 1 v1.0 → Create 1 v2.0 → Repeat
```

**Commands:**
```bash
kubectl set image deployment/myapp myapp=myapp:v2.0
kubectl rollout status deployment/myapp
kubectl rollout undo deployment/myapp  # Rollback (slow)
```

**Parameters:**
| Parameter | Effect |
|-----------|--------|
| `maxSurge: 2` | Up to 12 pods (10 + 2) during rollout |
| `maxUnavailable: 1` | At least 9 pods must be healthy |

---

### Deployment Strategy Comparison

| Aspect | Blue-Green | Canary | Rolling |
|--------|-----------|--------|---------|
| **Rollback** | Instant | Fast | Slow |
| **Cost** | High (2x infra) | Medium | Low |
| **Risk** | Medium | Low | Medium |
| **Validation** | Pre-switch | Real traffic | Gradual |

### Pipeline Stages
```
Commit → Build → Test → SAST/SCA → Image Scan → 
Push → Dev → Staging → Approval → Prod → Verify
```

### Rollback Commands
```bash
# Kubernetes
kubectl rollout undo deployment/NAME

# AWS ECS
aws ecs update-service --task-definition myapp:v1

# Blue-Green (ALB)
aws elbv2 modify-listener --default-actions TargetGroupArn=blue-tg

# Canary (ALB)
aws elbv2 modify-listener --default-actions Weight=0
```

### Pipeline Security
| Stage | Tools |
|-------|-------|
| **Secret Scanning** | gitleaks, trufflehog |
| **SAST** | SonarQube, CodeQL |
| **SCA** | Snyk, Dependabot |
| **Image Scanning** | Trivy, Grype |
| **SBOM + Signing** | Syft, Cosign |

---

## AI IN CI/CD

### Core Use Cases
| Use Case | Value |
|----------|-------|
| **Code Review** | AI analyzes PRs for bugs, security |
| **Test Generation** | Auto-generate tests for uncovered code |
| **Security Scanning** | AI suggests fixes, not just flags |
| **Deployment Intelligence** | Anomaly detection, auto-rollback |

### Tools
- GitHub Copilot/CLI, Amazon CodeWhisperer
- Snyk with AI, Codium AI
- Harness AI, Dynatrace Davis

### Pipeline Integration
```yaml
- name: AI Code Analysis
  run: copilot-cli analyze --focus security

- name: Security Scan
  run: snyk test --severity-threshold=high  # AI suggests fixes

- name: AI Deployment Monitor
  run: ai-monitor --baseline last-7-days --threshold error-rate:5%
```

### Best Practices
**DOs:**
- ✅ Use for repetitive tasks (docs, tests)
- ✅ Always review AI suggestions
- ✅ Start small, measure ROI

**DON'Ts:**
- ❌ Send secrets to external APIs
- ❌ Auto-apply without review
- ❌ Replace all testing with AI

### Interview Answer
> "Integrate AI at multiple stages: pre-merge code review, test generation (developers review), security with AI-suggested fixes, post-deploy monitoring. Key principle: AI augments, doesn't replace. Never send secrets to external services."

---

## KUBERNETES

### Core Concepts
| Question | Answer |
|----------|--------|
| **Pod vs Deployment vs Service?** | Pod: smallest unit. Deployment: manages ReplicaSets, rolling updates. Service: stable network endpoint |
| **ConfigMap vs Secret?** | ConfigMap: non-sensitive. Secret: base64 encoded (not encrypted by default) |
| **StatefulSet vs Deployment?** | StatefulSet: stable network ID, ordered deployment. Deployment: stateless, replaceable |

### Troubleshooting Commands
```bash
# Inspection
kubectl get pods -o wide
kubectl describe pod POD_NAME
kubectl logs POD_NAME -f
kubectl logs POD_NAME --previous  # Crashed container

# Debugging
kubectl top pods
kubectl get events --sort-by='.lastTimestamp'
kubectl exec -it POD_NAME -- /bin/sh

# Deployments
kubectl rollout status deployment/NAME
kubectl rollout undo deployment/NAME
kubectl scale deployment NAME --replicas=5
```

### Common Issues
| Problem | Check | Solution |
|---------|-------|----------|
| **Pending** | `describe pod` | Insufficient resources, PVC not bound, node selectors |
| **CrashLoopBackOff** | `logs --previous` | App crash, aggressive probe, increase `initialDelaySeconds` |
| **ImagePullBackOff** | `describe pod` | Image doesn't exist, registry auth, typo |

### Key Q&A
| Question | Answer |
|----------|--------|
| **Pod stuck Pending?** | 1) `describe pod` check Events 2) Check node resources 3) PVC bound? 4) Taints/selectors? |
| **How does HPA work?** | `desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]` |
| **NetworkPolicy?** | Default: all allowed. Policy defines ingress/egress rules. Needs CNI support |
| **Headless service?** | `clusterIP: None`. Returns pod IPs directly, no load balancing |

### Security Best Practices
```yaml
# Secure pod template
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
containers:
- securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop: [ALL]
```

---

### Exposing CronJobs

**Manual Trigger:**
```bash
# Trigger immediately
kubectl create job manual-run --from=cronjob/my-cronjob

# Get status
kubectl get cronjobs
kubectl describe cronjob my-cronjob

# View logs
kubectl logs job/manual-run
```

**HTTP API Trigger (Production):**

**Architecture:** `User/Webhook → API Service → K8s API → Create Job`

**RBAC Setup:**
```yaml
# ServiceAccount needs batch/jobs:create permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
rules:
- apiGroups: ["batch"]
  resources: ["cronjobs", "jobs"]
  verbs: ["get", "create"]
```

**API Endpoint (Python):**
```python
@app.route('/trigger/<cronjob_name>', methods=['POST'])
def trigger_cronjob(cronjob_name):
    cronjob = batch_v1.read_namespaced_cron_job(name=cronjob_name)
    job_name = f"{cronjob_name}-manual-{timestamp}"
    job = create_job_from_template(cronjob.spec.job_template)
    batch_v1.create_namespaced_job(body=job)
    return {"job_name": job_name}
```

**Expose Output:**
```yaml
# CronJob writes to PVC, nginx serves it
volumeMounts:
- name: reports
  mountPath: /reports

# Nginx deployment mounts same PVC
```

**Interview Answer:**
> "Can't directly expose a CronJob (it's batch, not a service). Options: (1) Manual trigger via `kubectl create job --from=cronjob/name`, (2) HTTP API with RBAC that creates Jobs from CronJob template, (3) CronJob writes to S3/PVC, serve via nginx, (4) Monitor via Prometheus."

---

## MULTI-CLUSTER KUBERNETES BOOTSTRAP PIPELINE

### Overview
> "Reusable GitHub Actions workflow that bootstraps multiple K8s clusters in parallel. Deploys ArgoCD, Sealed Secrets, ingress, and platform components across clusters with cluster-specific configurations."

### Architecture
```
Parent Workflow → Reusable Bootstrap Workflow
  → Job 1: Build Dynamic Matrix
  → Job 2: Deploy (N parallel jobs)
```

### Key Technical Decisions

**1. Reusable Workflow Pattern**
```yaml
workflow_call:  # Can be invoked by other workflows
  inputs:
    cluster: prod-warehouse | all
```

**2. Dynamic Matrix Strategy**
```bash
# Filter clusters with jq
jq --arg c "$CLUSTER" '[.[] | select(.cluster == $c)]'

# Output matrix for parallel jobs
echo "matrix={\"include\":$FILTERED}" >> $GITHUB_OUTPUT
```

**3. Dynamic Secret Resolution**
```yaml
# Secrets mapped per cluster in JSON
echo "${{ secrets[matrix.key_secret_name] }}" > argo.key
```

**4. Helm Diff Before Upgrade**
```bash
helm diff upgrade ... --detailed-exitcode || \
helm upgrade ... --atomic  # Auto-rollback on failure
```

**5. Workload Identity Federation**
- No stored service account keys
- OIDC tokens from GitHub
- Short-lived credentials

### Problems It Solves
- Multi-cluster consistency
- Disaster recovery (rebuild in 15 min)
- New cluster onboarding (automated)
- Configuration drift prevention
- Time efficiency (8 clusters in 15 min vs 2+ hours)

### Interview Q&A
| Question | Answer |
|----------|--------|
| **How handle failures?** | `--atomic` auto-rollbacks. Job failure triggers alerts. Re-run with failed cluster |
| **Test changes?** | Feature branch → test cluster → validate → merge |
| **Cluster-specific config?** | Each cluster has `values.yaml` directory, workflow uses `./ArgoCD/${{matrix.cluster}}/values.yaml` |
| **Why not Terraform?** | TF for cluster provisioning. This for in-cluster K8s resources (better GitOps integration) |

### What to Improve
- Add retry logic (exponential backoff)
- Pre-flight validation (check secrets exist)
- Drift detection (daily job)
- Move hardcoded cluster lists to files
- Add smoke tests post-deploy

---

## LINUX

### Essential Commands
```bash
# Files
ls -la
find /var -name "*.log" -mtime +7
tail -f /var/log/syslog

# Processes
ps aux | grep nginx
top / htop
systemctl status nginx
journalctl -u nginx -f

# Disk
df -h
du -sh /var/*

# Network
ss -tulnp
curl -I https://site.com
dig google.com
```

### Key Interview Q&A
| Question | Answer |
|----------|--------|
| **Server slow?** | `top` (CPU/memory), `df -h` (disk), `iostat` (I/O), `ss -tulnp` (connections) |
| **Disk full?** | `df -h` (which mount), `du -sh /*` (what's using), find/delete large files |
| **Process on port 80?** | `ss -tulnp | grep :80` or `lsof -i :80` |
| **Service failed?** | `systemctl status SERVICE`, then `journalctl -u SERVICE -n 50` |

---

## MONITORING & OBSERVABILITY

### Core Concepts
| Question | Answer |
|----------|--------|
| **Metrics vs Logs vs Traces?** | Metrics: time-series numbers. Logs: events/details. Traces: request flow across services |
| **What to monitor?** | Latency (p50/p95/p99), error rate, throughput, saturation. Plus business metrics |
| **Avoid alert fatigue?** | Alert on symptoms not causes, actionable only, proper severity, runbooks |
| **USE method** | Utilization, Saturation, Errors - for every resource |
| **RED method** | Rate, Errors, Duration - for services |

---

## RELIABILITY & INCIDENT MANAGEMENT

### High Availability
| Question | Answer |
|----------|--------|
| **Design for HA?** | Multi-AZ (99.99%), multi-region for DR. No single points of failure. Auto-recovery |
| **RTO vs RPO?** | RTO: max downtime. RPO: max data loss. Drives backup strategy |

### Incident Response
| Question | Answer |
|----------|--------|
| **Incident process?** | Detect → Triage → Mitigate → Root cause → Fix → Post-mortem → Prevent |
| **Good post-mortem?** | Blameless, timeline, root cause, action items with owners/dates |

---

## SECURITY

### IAM & Access
| Question | Answer |
|----------|--------|
| **Least privilege?** | Grant minimum permissions. Start with none, add as needed |
| **Role vs User?** | Roles: for services, temporary creds. Users: for humans, use SSO |
| **Audit access?** | CloudTrail (API logs), IAM Access Analyzer, Config rules |

### Application Security
| Question | Answer |
|----------|--------|
| **Secrets management?** | Secrets Manager/SSM Parameter Store. Auto-rotation. Never in code |
| **Secure containers?** | Minimal base image, scan for CVEs, non-root, read-only filesystem |
| **Shift-left security?** | Security early in SDLC. Scan in CI, security in design |

---

## SYSTEM DESIGN (QUICK PATTERNS)

### Common Architectures

**1. Web App**
```
Route53 → CloudFront → ALB → ASG → RDS + ElastiCache
```
**Repo:** Monorepo (single app, infra tightly coupled)

**2. Serverless**
```
API GW → Lambda → SQS/SNS → Lambda → DynamoDB
```
**Repo:** Monorepo (functions share code/libs)

**3. Microservices**
```
API GW → ALB → ECS/EKS → Service Mesh → RDS/DynamoDB
```
**Repo:** Polyrepo (each service = own repo, team autonomy)

### Repo Strategy Decision

| Factor | Monorepo | Polyrepo |
|--------|----------|----------|
| **Team size** | <20 devs | 20+ devs |
| **Deploy** | Together | Independent |
| **Sharing** | Lots of shared code | Minimal |
| **Ownership** | Shared | Clear boundaries |
| **Examples** | Google, Meta | Netflix, Amazon |

### Scaling Strategies
| Problem | Solution |
|---------|----------|
| Database bottleneck | Read replicas, caching, sharding |
| Compute bottleneck | Horizontal scaling (ASG), optimize code |
| Global latency | CloudFront, multi-region |
| Burst traffic | Queue (SQS) to decouple |

---

## PYTHON FOR DEVOPS

### Quick Skeleton
```python
#!/usr/bin/env python3
import logging, argparse, boto3

logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

def main(env: str, dry_run: bool = False):
    try:
        logger.info(f"Running for {env}")
        if dry_run:
            logger.info("DRY RUN - no changes")
        # Your logic here
    except Exception as e:
        logger.error(f"Failed: {e}")
        sys.exit(1)  # Non-zero = CI/CD knows it failed

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--env', required=True, 
                       choices=['dev', 'staging', 'prod'])
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    main(args.env, args.dry_run)
```

### Key Q&A
| Question | Answer |
|----------|--------|
| **Run shell commands?** | `subprocess.run(['kubectl', 'get', 'pods'], check=True, capture_output=True)` |
| **Handle secrets?** | `os.environ.get('API_KEY')` - never hardcode |
| **HTTP calls?** | `requests.get(url, timeout=5)` + `response.raise_for_status()` |
| **Why `sys.exit(1)`?** | Non-zero exit tells CI/CD the script failed |
| **Why `--dry-run`?** | Preview changes without executing - safety for destructive scripts |

### Practical Example: Auto-Shutdown Dev VMs
```python
# Find running dev instances (tag: Environment=dev)
filters = [
    {'Name': 'instance-state-name', 'Values': ['running']},
    {'Name': 'tag:Environment', 'Values': ['dev']}
]
instances = ec2.describe_instances(Filters=filters)

# Stop them
ec2.stop_instances(InstanceIds=instance_ids)

# Run via cron at 6PM daily
# 0 18 * * * /usr/bin/python3 /opt/scripts/shutdown_dev.py
```

---

## BEHAVIORAL TIPS

### STAR Format
```
Situation: Brief context
Task: Your responsibility  
Action: What YOU did (specific)
Result: Quantified outcome
```

### Have Stories Ready For:
- Incident resolved under pressure
- System designed/improved
- Disagreement with team
- Failure and learning
- Cross-team collaboration

### Questions to Ask Them:
- "What does on-call look like?"
- "How do you handle tech debt?"
- "What's the team's biggest challenge?"
- "How are infrastructure decisions made?"
- "What does success look like in 6 months?"

---

**Remember:** It's OK to say *"I don't know, but here's how I'd figure it out..."* - shows problem-solving > memorization.

**Good luck! 🚀**
