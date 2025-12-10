# Senior DevOps/Cloud Engineer - Interview Cheat Sheet 📋

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

### Common Architectures
```
Web App:        Route53 → CloudFront → ALB → ASG (EC2/ECS) → RDS + ElastiCache

Event-Driven:   API GW → Lambda → SQS/SNS → Lambda → DynamoDB

Data Pipeline:  Kinesis/Kafka → Lambda/EMR → S3 → Athena/Redshift

Microservices:  API GW → ALB → ECS/EKS → Service Mesh (App Mesh) → RDS/DynamoDB
```

### Scaling Strategies
| Problem | Solution |
|---------|----------|
| Database bottleneck | Read replicas, caching (ElastiCache), sharding |
| Compute bottleneck | Horizontal scaling (ASG), larger instances, optimize code |
| Global latency | CloudFront, multi-region, Global Accelerator |
| Burst traffic | Queue (SQS) to decouple, Lambda for auto-scale |

---

## PYTHON FOR DEVOPS

### Quick Skeleton (Use This in Interview)

```python
#!/usr/bin/env python3
"""
Script purpose: One-line description of what it does.
Usage: python script.py --env dev --dry-run
"""

import os          # Environment variables
import sys         # Exit codes
import logging     # Production-ready logging
import argparse    # CLI argument parsing
import requests    # HTTP calls
import boto3       # AWS SDK

# ============ SETUP LOGGING (not print!) ============
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============ CONFIGURATION ============
# Never hardcode secrets - always use environment variables
API_URL = os.environ.get('API_URL', 'https://api.example.com')
AWS_REGION = os.environ.get('AWS_REGION', 'eu-west-2')

# ============ MAIN LOGIC ============
def main(environment: str, dry_run: bool = False):
    """Main entry point."""
    logger.info(f"Starting for environment: {environment}")
    
    try:
        result = do_work(environment)
        
        if dry_run:
            logger.info(f"DRY RUN - would do: {result}")
        else:
            logger.info(f"Result: {result}")
            
    except Exception as e:
        logger.error(f"Failed: {e}")
        sys.exit(1)  # Non-zero = failure (CI/CD will catch this)
    
    logger.info("Completed successfully")

def do_work(env: str) -> dict:
    """Example: AWS + HTTP call."""
    # AWS SDK call
    ec2 = boto3.client('ec2', region_name=AWS_REGION)
    instances = ec2.describe_instances()
    
    # HTTP call with timeout + error handling
    response = requests.get(f"{API_URL}/health", timeout=5)
    response.raise_for_status()  # Raises on 4xx/5xx
    
    return {"status": "ok", "count": len(instances)}

# ============ CLI ENTRYPOINT ============
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='DevOps script')
    parser.add_argument('--env', required=True, 
                        choices=['dev', 'staging', 'prod'],
                        help='Target environment')
    parser.add_argument('--dry-run', action='store_true',
                        help='Preview without executing')
    
    args = parser.parse_args()
    main(environment=args.env, dry_run=args.dry_run)
```

### Key Points to Explain
| Element | Why |
|---------|-----|
| `#!/usr/bin/env python3` | Shebang - makes script executable directly |
| `logging` not `print` | Configurable levels, timestamps, production-ready |
| `os.environ.get()` | Secrets from env vars, never hardcode |
| `argparse` | CLI with built-in help, validation |
| `--dry-run` | Safe mode for destructive scripts |
| `try/except` + `sys.exit(1)` | Proper error handling, CI/CD sees failures |
| `if __name__ == "__main__"` | Script can be imported without running |
| `timeout=5` | Never hang forever on HTTP calls |
| `raise_for_status()` | Fail fast on bad HTTP responses |

### Common Libraries
| Library | Use Case |
|---------|----------|
| `boto3` | AWS (EC2, S3, IAM) |
| `requests` | HTTP/APIs |
| `subprocess` | Shell commands |
| `json`/`yaml` | Config files |

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
