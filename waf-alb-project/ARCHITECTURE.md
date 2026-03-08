# Architecture Documentation

## Overview

This project implements a flexible AWS WAF (Web Application Firewall) management system with Application Load Balancer (ALB) integration, supporting multiple deployment patterns through Terraform modules and Jenkins CI/CD.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Jenkins Pipeline                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │   Create   │  │ Associate  │  │   Delete   │            │
│  │    WAF     │  │    WAF     │  │    WAF     │            │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘            │
└────────┼───────────────┼───────────────┼────────────────────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │      Terraform Module          │
         │  ┌─────────────────────────┐  │
         │  │   WAF Web ACL           │  │
         │  │  - Managed Rules        │  │
         │  │  - Custom Rules         │  │
         │  │  - IP Sets              │  │
         │  │  - Rate Limiting        │  │
         │  └──────────┬──────────────┘  │
         └─────────────┼──────────────────┘
                       │
         ┌─────────────┴──────────────┐
         │                            │
         ▼                            ▼
┌─────────────────┐          ┌─────────────────┐
│   ALB 1         │          │   ALB 2         │
│  (Production)   │          │  (Staging)      │
└────────┬────────┘          └────────┬────────┘
         │                            │
         ▼                            ▼
┌─────────────────┐          ┌─────────────────┐
│  Target Group   │          │  Target Group   │
│  (EC2/ECS/...)  │          │  (EC2/ECS/...)  │
└─────────────────┘          └─────────────────┘
```

## Component Architecture

### 1. Terraform Module Structure

```
waf-alb-project/
├── main.tf              # Root module - orchestrates WAF module
├── variables.tf         # Root input variables
├── outputs.tf           # Root outputs
├── backend.tf           # S3 backend configuration
│
├── modules/waf/         # Reusable WAF module
│   ├── main.tf          # WAF resources and logic
│   ├── variables.tf     # Module input variables
│   └── outputs.tf       # Module outputs
│
└── examples/            # Usage examples
    ├── basic/
    └── advanced/
```

### 2. WAF Rule Priority Order

Rules are evaluated in priority order (lower number = higher priority):

```
Priority 5:  IP Allowlist (ALLOW)
Priority 10: AWS Managed Core Rules (BLOCK/COUNT)
Priority 20: SQL Injection Protection (BLOCK/COUNT)
Priority 30: IP Blocklist (BLOCK)
Priority 40: Rate Limiting (BLOCK)
Default:     Allow/Block (configurable)
```

### 3. State Management

```
┌─────────────────────────────────────────────┐
│           S3 State Bucket                    │
│  ┌────────────────────────────────────────┐ │
│  │ waf-alb/dev/terraform.tfstate          │ │
│  │ waf-alb/staging/terraform.tfstate      │ │
│  │ waf-alb/prod/terraform.tfstate         │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│        DynamoDB Lock Table                   │
│  Prevents concurrent modifications           │
└─────────────────────────────────────────────┘
```

## Deployment Patterns

### Pattern 1: Create WAF Only

```hcl
create_waf    = true
associate_waf = false
```

Use case: Pre-create WAF for later association

### Pattern 2: Create and Associate

```hcl
create_waf    = true
associate_waf = true
alb_arns      = ["arn:..."]
```

Use case: Full deployment in one step

### Pattern 3: Associate Existing WAF

```hcl
create_waf           = false
associate_waf        = true
existing_web_acl_arn = "arn:..."
alb_arns             = ["arn:..."]
```

Use case: Reuse WAF across multiple ALBs

### Pattern 4: Disassociate WAF

```hcl
create_waf    = true
associate_waf = false
```

Use case: Remove ALB protection without deleting WAF

## Security Architecture

### Defense in Depth

```
Layer 1: IP Allowlist (Trusted sources bypass all rules)
         ↓
Layer 2: IP Blocklist (Known bad actors blocked immediately)
         ↓
Layer 3: AWS Managed Rules (OWASP Top 10 protection)
         ↓
Layer 4: SQL Injection Protection (Database attack prevention)
         ↓
Layer 5: Rate Limiting (DDoS mitigation)
         ↓
Layer 6: Default Action (Allow/Block unmatched traffic)
```

### Rule Override Modes

1. **Enforce Mode** (`managed_rule_override_action = "none"`)
   - Rules actively block malicious traffic
   - Recommended for production

2. **Monitor Mode** (`managed_rule_override_action = "count"`)
   - Rules count matches but don't block
   - Recommended for testing and tuning

## CI/CD Pipeline Flow

### Jenkins Pipeline Stages

```
1. Validate Parameters
   ├─ Check required inputs
   └─ Validate action compatibility

2. Checkout Code
   └─ Pull latest from SCM

3. Prepare Variables
   ├─ Parse ALB ARNs
   ├─ Set action flags
   └─ Build Terraform vars from pipeline parameters

4. Terraform Init
   └─ Configure backend with environment-specific state path

5. Terraform Plan
   ├─ Generate execution plan using -var flags
   └─ Archive for audit

6. Manual Approval (optional)
   └─ Human review gate

7. Terraform Apply
   └─ Execute changes

8. Capture Outputs
   └─ Archive WAF details
```

**Note:** The Jenkins pipeline passes all configuration via `-var` flags, not tfvars files. The `ENVIRONMENT` parameter is used for AWS credentials and state file organization only.

## High Availability

### Multi-Region Considerations

WAFv2 Regional Web ACLs are region-specific. For multi-region HA, deploy separate WAF instances per region using separate terraform.tfvars files:

```
Region 1 (us-east-1)          Region 2 (us-west-2)
┌──────────────────┐          ┌──────────────────┐
│  WAF Web ACL     │          │  WAF Web ACL     │
│  ├─ ALB 1        │          │  ├─ ALB 3        │
│  └─ ALB 2        │          │  └─ ALB 4        │
└──────────────────┘          └──────────────────┘
```

## Monitoring and Observability

### CloudWatch Metrics

```
WAF Metrics:
├─ AllowedRequests
├─ BlockedRequests
├─ CountedRequests
└─ PassedRequests

Per-Rule Metrics:
├─ AWSManagedRulesCommonRuleSet
├─ AWSManagedRulesSQLiRuleSet
├─ RateLimitRule
├─ AllowListedIPs
└─ BlockListedIPs
```

### Logging Architecture

```
WAF Web ACL
    │
    ├─ CloudWatch Logs
    │  └─ /aws/wafv2/logs/<name>
    │
    └─ S3 Bucket (optional)
       └─ waf-logs/<year>/<month>/<day>/
```

## Cost Optimization

### Pricing Components

1. **Web ACL**: $5.00/month
2. **Rules**: $1.00/month per rule
3. **Requests**: $0.60 per million requests
4. **Managed Rule Groups**: $10.00/month per group

### Cost Optimization Strategies

- Use managed rule groups instead of custom rules
- Implement IP allowlists to bypass rule evaluation
- Monitor and tune rate limits
- Use count mode during testing to avoid unnecessary blocking

## Disaster Recovery

### Backup Strategy

1. **State Files**: Versioned in S3
2. **Configuration**: Version controlled in Git
3. **WAF Rules**: Exportable via AWS CLI

### Recovery Procedures

```bash
# Export WAF configuration
aws wafv2 get-web-acl \
  --scope REGIONAL \
  --id <ID> \
  --region us-east-1 > waf-backup.json

# Import existing resources
terraform import module.waf.aws_wafv2_web_acl.this[0] <ID>
```

## Compliance and Governance

### Tagging Strategy

All resources tagged with:
- Project
- Environment
- ManagedBy
- Team
- CostCenter (optional)

### Audit Trail

- Terraform state changes logged
- Jenkins pipeline execution archived
- WAF sampled requests retained for 3 hours
- CloudWatch logs retained per retention policy

## Performance Considerations

### WAF Capacity Units (WCU)

- Web ACL base: 1 WCU
- AWS Managed Core Rules: ~700 WCU
- SQL Injection Rules: ~200 WCU
- Rate-based rule: 2 WCU
- IP set rule: 1 WCU

Maximum: 5000 WCU per Web ACL

### Latency Impact

- Average latency: 1-4ms per request
- Minimal impact on user experience
- Scales automatically with traffic
