# Senior DevOps/Cloud Engineer - Interview Cheat Sheet 📋

---

## 📋 TABLE OF CONTENTS

| # | Section | Topics |
|---|---------|--------|
| 1 | [Terraform](#terraform) | State, modules, best practices, gotchas |
| 2 | [AWS Networking](#aws-networking) | VPC, security groups, load balancing |
| 3 | [AWS Compute](#aws-compute) | EC2, ASG, containers, serverless |
| 4 | [CI/CD & Deployments](#cicd--deployments) | Strategies, approvals, rollback, security, implementation |
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

### Deployment Strategies Overview

| Strategy | How It Works | Rollback | Best For |
|----------|--------------|----------|----------|
| **Blue-Green** | 2 identical envs, switch traffic instantly | Instant (switch back) | Critical apps, instant rollback |
| **Canary** | Route 5% → 25% → 50% → 100%, monitor at each step | Fast (route back to old) | Gradual validation, catch issues early |
| **Rolling** | Replace pods one by one (K8s default) | Slow (redeploy old) | Standard deployments |

---

## DEPLOYMENT STRATEGIES - IMPLEMENTATION GUIDE

### 1. BLUE-GREEN DEPLOYMENT

#### Concept
Two identical production environments (Blue = current, Green = new). Switch traffic instantly between them.

#### AWS Implementation (ALB + Target Groups)

**Architecture:**
```
Internet
    ↓
ALB (Listener Rules)
    ├─ Blue Target Group (100% traffic) → ASG v1.0
    └─ Green Target Group (0% traffic) → ASG v2.0
```

**Step-by-Step:**

1. **Initial State**: Blue environment serves 100% traffic
```bash
# Blue ASG running v1.0
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names blue-asg
```

2. **Deploy Green Environment**
```bash
# Create new ASG with v2.0
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name green-asg \
  --launch-template LaunchTemplateName=app-v2 \
  --min-size 2 --max-size 10 --desired-capacity 2 \
  --target-group-arns arn:aws:elasticloadbalancing:...:targetgroup/green-tg

# Wait for instances to be healthy
aws elbv2 describe-target-health --target-group-arn arn:aws:...green-tg
```

3. **Test Green Environment** (Before switching traffic)
```bash
# Direct test via internal endpoint or specific routing
curl https://green-internal.example.com/health
```

4. **Switch Traffic to Green**
```bash
# Update ALB listener to point to green target group
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:...:listener/... \
  --default-actions Type=forward,TargetGroupArn=arn:aws:...green-tg
```

5. **Monitor & Verify**
```bash
# Watch CloudWatch metrics for 5-10 minutes
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=TargetGroup,Value=green-tg
```

6. **Rollback (if needed)** - Just switch back
```bash
# Point ALB back to blue
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:...:listener/... \
  --default-actions Type=forward,TargetGroupArn=arn:aws:...blue-tg
```

7. **Cleanup Blue** (after successful deployment)
```bash
# Terminate blue ASG
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name blue-asg --force-delete
```

---

#### Kubernetes Implementation

**Using Services + Deployments:**
```yaml
# Blue deployment (current)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: myapp
        image: myapp:v1.0
---
# Green deployment (new)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0
---
# Service (switch by changing selector)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue  # Change to 'green' to switch traffic
  ports:
  - port: 80
    targetPort: 8080
```

**Switching Traffic:**
```bash
# Deploy green
kubectl apply -f myapp-green-deployment.yaml

# Verify green is healthy
kubectl get pods -l version=green
kubectl logs -l version=green

# Switch traffic (update service selector)
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'

# Instant switch! Monitor for 10 minutes

# Rollback if needed (instant)
kubectl patch service myapp -p '{"spec":{"selector":{"version":"blue"}}}'

# Delete blue after success
kubectl delete deployment myapp-blue
```

---

#### Blue-Green Interview Q&A

| Question | Answer |
|----------|--------|
| **When to use blue-green?** | Critical apps needing instant rollback, regulatory requirements for zero downtime, when you can afford duplicate infrastructure |
| **Cost implications?** | 2x infrastructure during deployment (expensive). Mitigate: use smaller green initially, scale up after testing |
| **How to test green before switch?** | Internal endpoint, specific route (header-based), smoke tests in staging that mirrors prod |
| **Database migrations?** | Use backward-compatible schema changes. Deploy DB changes first, then app. Never rollback DB |
| **What if green fails after switch?** | Instant rollback - switch ALB/Service back to blue. This is the main advantage of blue-green |

---

### 2. CANARY DEPLOYMENT

#### Concept
Gradually shift traffic from stable to new version in increments (5% → 25% → 50% → 100%), monitoring at each step.

#### AWS Implementation (ALB Weighted Target Groups)

**Architecture:**
```
Internet
    ↓
ALB
    ├─ Stable Target Group (95% weight) → ASG v1.0
    └─ Canary Target Group (5% weight)  → ASG v2.0
```

**Step-by-Step:**

1. **Deploy Canary Target Group**
```bash
# Create canary target group
aws elbv2 create-target-group \
  --name myapp-canary-tg \
  --protocol HTTP --port 80 \
  --vpc-id vpc-xxxxx

# Create ASG for canary
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name canary-asg \
  --launch-template LaunchTemplateName=app-v2 \
  --min-size 1 --max-size 3 \
  --target-group-arns arn:aws:...canary-tg
```

2. **Configure Weighted Routing (5% to canary)**
```bash
# Modify listener to use weighted target groups
aws elbv2 modify-listener \
  --listener-arn arn:aws:...listener/... \
  --default-actions \
    '[
      {
        "Type": "forward",
        "ForwardConfig": {
          "TargetGroups": [
            {"TargetGroupArn": "arn:aws:...stable-tg", "Weight": 95},
            {"TargetGroupArn": "arn:aws:...canary-tg", "Weight": 5}
          ]
        }
      }
    ]'
```

3. **Monitor Canary (5-10 minutes)**
```bash
# Compare error rates
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=TargetGroup,Value=canary-tg

# If error rate acceptable, proceed to next step
```

4. **Increase to 25%**
```bash
aws elbv2 modify-listener \
  --listener-arn arn:aws:...listener/... \
  --default-actions \
    '[{"Type": "forward", "ForwardConfig": {
      "TargetGroups": [
        {"TargetGroupArn": "arn:aws:...stable-tg", "Weight": 75},
        {"TargetGroupArn": "arn:aws:...canary-tg", "Weight": 25}
      ]}}]'

# Monitor again for 10 minutes
```

5. **Continue: 50% → 100%**
```bash
# 50%
aws elbv2 modify-listener ... --default-actions '[...Weight: 50...]'

# Monitor for 15 minutes

# 100% (full rollout)
aws elbv2 modify-listener ... --default-actions '[...Weight: 100...]'
```

6. **Cleanup Stable**
```bash
# After successful 100% canary, remove stable target group
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name stable-asg
```

---

#### Kubernetes Implementation (Argo Rollouts)

**Install Argo Rollouts:**
```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

**Rollout Manifest:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10       # 10% traffic to canary
      - pause: {duration: 5m}
      - setWeight: 25       # 25% traffic
      - pause: {duration: 10m}
      - setWeight: 50       # 50% traffic
      - pause: {duration: 10m}
      - setWeight: 100      # Full rollout
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0
        ports:
        - containerPort: 8080
```

**Kubernetes Nginx Ingress Canary:**
```yaml
# Stable service
apiVersion: v1
kind: Service
metadata:
  name: myapp-stable
spec:
  selector:
    app: myapp
    version: stable
  ports:
  - port: 80
---
# Canary service
apiVersion: v1
kind: Service
metadata:
  name: myapp-canary
spec:
  selector:
    app: myapp
    version: canary
  ports:
  - port: 80
---
# Main ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-stable
            port:
              number: 80
---
# Canary ingress (10% traffic)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% traffic
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-canary
            port:
              number: 80
```

**Canary Deployment Commands:**
```bash
# Deploy canary
kubectl apply -f myapp-canary-deployment.yaml
kubectl apply -f myapp-canary-ingress.yaml

# Monitor metrics
kubectl top pods -l version=canary
kubectl logs -l version=canary --tail=100

# Increase weight gradually
kubectl patch ingress myapp-canary -p \
  '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"25"}}}'

# Continue: 50%, then 100%

# Promote (remove canary annotation)
kubectl patch ingress myapp-canary -p \
  '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary":"false"}}}'
```

---

#### Canary with Istio (Service Mesh)
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp.example.com
  http:
  - match:
    - headers:
        user-agent:
          regex: ".*Chrome.*"  # Optional: target specific users
    route:
    - destination:
        host: myapp
        subset: stable
      weight: 90
    - destination:
        host: myapp
        subset: canary
      weight: 10
```

---

#### Canary vs Route 53 - Critical Distinction

| Method | Traffic Control | Rollback Speed | Use Case |
|--------|----------------|----------------|----------|
| **Route 53 Weighted** | DNS level, TTL delay (60-300s) | Slow (minutes) | ❌ NOT for canary deployments |
| **ALB Weighted Target Groups** | Load balancer level | Instant (seconds) | ✅ Production canary |
| **Ingress Canary Annotations** | Ingress level | Instant (seconds) | ✅ Kubernetes canary |
| **Service Mesh (Istio)** | Service mesh level | Instant (seconds) | ✅ Advanced canary with headers |

**Route 53 Problem:**
```
User → DNS Cache (TTL: 300s) → Route 53 → ALB
         ↑
         This cache prevents instant traffic shifts!
```

**Interview Answer for Route 53 Question:**
> "Route 53 weighted routing CAN technically work for canary-style rollouts, but it has a critical flaw: DNS caching (TTL). Once a client caches the DNS response, they're stuck with that version for 60-300 seconds. This means if I detect an issue and want to rollback, users continue hitting the bad version until their DNS cache expires. That's unacceptable for production.
>
> **The correct approach is weighted routing at the load balancer or ingress layer** - ALB weighted target groups for AWS, or nginx ingress canary annotations for Kubernetes. These provide instant traffic control with no DNS delays. If the canary shows problems, I can rollback in seconds by changing the weight back to zero."

---

#### Canary Interview Q&A

| Question | Answer |
|----------|--------|
| **When to use canary?** | When you want to validate with real production traffic before full rollout. Catches issues that tests miss (load, edge cases, real user behavior) |
| **How to monitor canary?** | Error rate (must be ≤ stable), latency (p95/p99), throughput. Set alerts: if error rate >2% higher than stable, auto-rollback |
| **Canary schedule?** | Typical: 5% (5min) → 25% (10min) → 50% (15min) → 100%. Adjust based on risk tolerance and traffic volume |
| **What if canary fails at 50%?** | Rollback by setting weight to 0. This is why incremental steps matter - validates at scale before full commit |
| **Canary vs Blue-Green?** | Canary: gradual, validates with real traffic, slower. Blue-Green: instant switch, fast rollback, no real-traffic validation before switch |

---

### 3. ROLLING DEPLOYMENT

#### Concept
Replace instances/pods one at a time (or in small batches) until all are updated. Default strategy for Kubernetes.

#### Kubernetes Rolling Update (Default)

**Deployment with Rolling Update Strategy:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Max 2 extra pods during update
      maxUnavailable: 1  # Max 1 pod can be unavailable
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2.0
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
```

**How Rolling Update Works:**
```
Initial: 10 pods running v1.0

Step 1: Create 2 new pods (v2.0)        [v1: 10, v2: 2]  maxSurge
Step 2: Wait for readiness probes
Step 3: Terminate 1 old pod (v1.0)      [v1: 9, v2: 2]   maxUnavailable
Step 4: Create 1 new pod (v2.0)         [v1: 9, v2: 3]
Step 5: Terminate 1 old pod             [v1: 8, v2: 3]
...
Final: 10 pods running v2.0             [v1: 0, v2: 10]
```

**Deploy Rolling Update:**
```bash
# Update image
kubectl set image deployment/myapp myapp=myapp:v2.0

# Watch rollout
kubectl rollout status deployment/myapp

# Check rollout history
kubectl rollout history deployment/myapp

# Rollback if needed (slow - redeploys old version)
kubectl rollout undo deployment/myapp
```

---

#### AWS ECS Rolling Update
```json
{
  "serviceName": "myapp",
  "taskDefinition": "myapp:v2",
  "desiredCount": 10,
  "deploymentConfiguration": {
    "maximumPercent": 200,         // maxSurge (can go up to 20 tasks)
    "minimumHealthyPercent": 90    // maxUnavailable (must keep ≥9 healthy)
  },
  "deploymentController": {
    "type": "ECS"  // ECS rolling update
  }
}
```

**Update Service:**
```bash
# Update ECS service with new task definition
aws ecs update-service \
  --cluster my-cluster \
  --service myapp \
  --task-definition myapp:v2 \
  --deployment-configuration \
    maximumPercent=200,minimumHealthyPercent=90

# Monitor deployment
aws ecs describe-services --cluster my-cluster --services myapp
```

---

#### Rolling Update Parameters Explained

| Parameter | Effect | Example |
|-----------|--------|---------|
| **maxSurge** | Max extra pods during update | `maxSurge: 2` means up to 12 pods (10 + 2) during rollout |
| **maxUnavailable** | Max pods that can be down | `maxUnavailable: 1` means at least 9 pods must be healthy |
| **Fast rollout** | `maxSurge: 50%`, `maxUnavailable: 25%` | Aggressive, higher resource usage |
| **Conservative** | `maxSurge: 25%`, `maxUnavailable: 0` | Slower, zero downtime guaranteed |

---

#### Rolling Update Interview Q&A

| Question | Answer |
|----------|--------|
| **When to use rolling?** | Standard deployments, when you can tolerate gradual rollout and don't need instant rollback. Default for Kubernetes |
| **Rollback speed?** | Slow - must redeploy old version pod by pod. If you need fast rollback, use blue-green or canary |
| **maxSurge vs maxUnavailable?** | maxSurge: extra capacity during update. maxUnavailable: how many can be down. Tune based on resource constraints and risk tolerance |
| **What if a pod fails during rollout?** | Rollout pauses if readiness probes fail. Fix the issue or rollback manually with `kubectl rollout undo` |
| **Zero downtime guarantee?** | Only if `maxUnavailable: 0` AND readiness probes are configured correctly. Otherwise, brief downtime possible |

---

### Deployment Strategy Comparison

| Aspect | Blue-Green | Canary | Rolling |
|--------|-----------|--------|---------|
| **Traffic Switch** | Instant (100%) | Gradual (5% → 100%) | Pod by pod |
| **Rollback Speed** | Instant | Fast (change weight) | Slow (redeploy) |
| **Infrastructure Cost** | High (2x during deploy) | Medium (small canary) | Low (incremental) |
| **Risk** | Medium (all traffic at once) | Low (validate incrementally) | Medium (gradual exposure) |
| **Complexity** | Low | Medium (needs monitoring) | Low (K8s default) |
| **Validation** | Pre-switch testing | Real traffic validation | Gradual exposure |
| **Database Migrations** | Complex (need compatibility) | Must be backward compatible | Must be backward compatible |
| **Best For** | Critical apps, instant rollback | Gradual validation, catch edge cases | Standard deployments |

---

### Strategy Selection Decision Tree
```
Need instant rollback?
├─ YES → Blue-Green
└─ NO
    ├─ Need real-traffic validation before full rollout?
    │  └─ YES → Canary
    └─ NO → Rolling Update (K8s default)

High-risk deployment?
└─ YES → Canary (validate incrementally)

Tight budget?
└─ YES → Avoid Blue-Green (2x infrastructure)

Critical production system?
└─ YES → Blue-Green OR Canary (both offer fast rollback)
```

---

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
# Kubernetes
kubectl rollout undo deployment/NAME                    # Previous version
kubectl rollout undo deployment/NAME --to-revision=3   # Specific version
kubectl rollout history deployment/NAME                 # See history

# AWS ECS
aws ecs update-service --service myapp --task-definition myapp:v1

# Blue-Green (ALB)
aws elbv2 modify-listener --listener-arn ... --default-actions TargetGroupArn=blue-tg

# Canary (ALB)
aws elbv2 modify-listener ... --default-actions Weight=0  # Set canary weight to 0
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
| **Blue-green vs canary?** | Blue-green = instant rollback, all traffic switches at once. Canary = validate with real traffic first (5% → 100%), catch issues tests miss |
| **How do you secure pipelines?** | Secret scanning, dependency scanning (SCA), image scanning (Trivy), sign images, fail on HIGH/CRITICAL CVEs |
| **What's an SBOM?** | Software Bill of Materials - list of all components. Used for compliance + checking which services affected by new CVEs |
| **Secrets in pipelines?** | Never in code. GitHub encrypted secrets or Secrets Manager. Inject at runtime. Run secret scanning to catch leaks |
| **How to implement canary?** | ALB weighted target groups (AWS) or nginx ingress canary annotations (K8s). NOT Route 53 - DNS caching prevents instant rollback |

### Pipeline Design
| Question | Key Points |
|----------|------------|
| **Design a CI/CD pipeline for microservices** | Mono-repo or multi-repo, build on PR, test (unit/integration), security scan, build image, deploy to dev → staging → prod with gates |
| **How do you handle database migrations in CI/CD?** | Forward-compatible migrations, separate from app deploy, feature flags for breaking changes, never rollback DB |
| **How do you implement GitOps?** | Git = source of truth. Changes via PR. Automated sync (ArgoCD/Flux). Drift detection + reconciliation |

---

## AI IN CI/CD

[... rest of the document remains the same ...]

---

**Remember:** It's OK to say *"I don't know, but here's how I'd figure it out..."* - shows problem-solving > memorization.

**Good luck! 🚀**
