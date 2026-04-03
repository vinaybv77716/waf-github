# AWS WAF + ALB Terraform Project

A comprehensive Infrastructure as Code (IaC) solution for deploying and managing AWS Web Application Firewall (WAF) rules to protect Application Load Balancers (ALBs) — including cross-account deployments.

## Table of Contents

- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Project Structure](#project-structure)
- [Technologies Used](#technologies-used)
- [Prerequisites](#prerequisites)
- [Quick Start Guide](#quick-start-guide)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Creating a New WAF for a New Project](#creating-a-new-waf-for-a-new-project)
- [Cross-Account WAF Deployment](#cross-account-waf-deployment)
- [Jenkins Pipeline](#jenkins-pipeline)
- [WAF Rules Reference](#waf-rules-reference)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

---

## Project Overview

This project provides a complete Terraform-based solution for securing AWS Application Load Balancers with Web Application Firewall rules. It automates the deployment of AWS Managed Rule Groups, custom IP allow/block lists, rate limiting, and logging configurations — and supports deploying WAF into a different AWS account than the one running Jenkins.

### What It Does

- Deploys WAF Web ACLs with multiple AWS managed rule sets
- Associates WAF rules with Application Load Balancers
- Supports same-account and cross-account deployments via `sts:AssumeRole`
- Provides monitoring through CloudWatch metrics and optional logging
- Supports CI/CD via Jenkins pipelines
- Enables customization through environment-specific `.tfvars` files

---

## Key Features

- Multi-Environment Support: Dev, staging, and production configurations
- Cross-Account Deployment: Deploy WAF into any target account using IAM role assumption
- Comprehensive Rule Coverage: 10+ AWS managed rule groups
- Flexible Actions: Block, count, or allow per rule group
- Per-Rule Overrides: Fine-tune individual sub-rules
- IP Management: Allowlist and blocklist IP sets
- Rate Limiting: DDoS protection with configurable thresholds
- Automated CI/CD: Jenkins pipeline integration with `ROLE_ARN` parameter support
- Plan Analysis: Python script for readable Terraform plan output
- Cost Optimization: WCU monitoring and rule enablement controls

---

## Project Structure

```
.
├── Jenkinsfile                          # Main Jenkins CI/CD pipeline
├── waf-rules.md                         # Detailed WAF rules reference
├── waf-alb-project/
│   ├── main.tf                          # Root module — provider + WAF module call
│   ├── variables.tf                     # Root variable definitions (incl. cross-account)
│   ├── outputs.tf                       # Root outputs
│   ├── backend.tf                       # S3 remote state configuration
│   ├── jenkinsfile                      # Alternative Jenkins pipeline
│   ├── plan.py                          # Terraform plan analyzer script
│   ├── environments/
│   │   └── dev/
│   │       ├── terraform.tfvars         # biz2x dev configuration (same-account)
│   │       ├── biz2credit.tfvars        # biz2credit dev configuration (same-account)
│   │       ├── new.tfvars               # rapyder dev configuration (same-account)
│   │       └── crossaccount.tfvars      # Cross-account deployment template
│   └── modules/
│       └── waf/
│           ├── main.tf                  # WAF resource definitions
│           ├── variables.tf             # Module variables
│           └── outputs.tf              # Module outputs
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `Jenkinsfile` | CI/CD pipeline — supports `ROLE_ARN` for cross-account |
| `main.tf` | AWS provider with dynamic `assume_role` block |
| `variables.tf` | All variables including `assume_role_arn` and `assume_role_external_id` |
| `modules/waf/` | Reusable WAF module |
| `environments/dev/` | Per-project tfvars files |
| `crossaccount.tfvars` | Ready-to-use cross-account deployment template |
| `plan.py` | Plan analysis and reporting tool |

---

## Technologies Used

- Infrastructure as Code: Terraform 1.3+
- Cloud Platform: Amazon Web Services (AWS)
  - WAFv2 (Web Application Firewall)
  - ALB (Application Load Balancer)
  - S3 (remote state storage)
  - STS (cross-account role assumption)
  - CloudWatch (monitoring & logging)
- CI/CD: Jenkins
- Scripting: Python 3 (plan analysis)
- Version Control: Git

---

## Prerequisites

### 1. AWS Account & Permissions

The Jenkins EC2 instance runs with the `ecr-ssm-role` IAM instance profile in account `892669526097`. This role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "wafv2:*",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:SetWebAcl",
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

For cross-account deployments, also add:

```json
{
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::307654412330:role/TerraformWAFRole"
}
```

### 2. Required Tools

- Terraform: v1.3.0 or higher
- AWS CLI: Configured with credentials
- Python 3: For plan analysis (optional)
- Jenkins: For CI/CD (optional)

### 3. AWS Resources

- S3 Bucket: `vina-terraform-waf-bucket` (in account `892669526097`) for Terraform state
- Application Load Balancer: Already created ALB to protect
- IAM Role: `ecr-ssm-role` attached to Jenkins EC2

---

## Quick Start Guide

### Step 1: Navigate to the project

```bash
cd waf-alb-project
```

### Step 2: Configure Environment

Edit or copy an existing tfvars file under `environments/dev/`:

```hcl
project     = "myproject"
environment = "dev"
aws_region  = "us-east-1"

bucket = "vina-terraform-waf-bucket"
key    = "waf-alb/dev/myproject.tfstate"
region = "us-east-1"

create_waf    = true
associate_waf = true
alb_arns      = ["arn:aws:elasticloadbalancing:us-east-1:892669526097:loadbalancer/app/my-alb/abc123"]

# Same-account — leave empty
assume_role_arn         = ""
assume_role_external_id = ""

enable_aws_managed_rules = true
aws_managed_rules_action = "count"
```

### Step 3: Initialize Terraform

```bash
terraform init \
  -backend-config="bucket=vina-terraform-waf-bucket" \
  -backend-config="key=waf-alb/dev/myproject.tfstate" \
  -backend-config="region=us-east-1"
```

### Step 4: Plan

```bash
terraform plan -var-file="environments/dev/myproject.tfvars" -out=tfplan.binary
```

### Step 5: Apply

```bash
terraform apply tfplan.binary
```

### Step 6: Verify

```bash
terraform output
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1
```

---

## Configuration

### Root Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `us-east-1` | AWS region for deployment |
| `assume_role_arn` | string | `""` | IAM role ARN to assume (cross-account). Empty = same-account |
| `assume_role_external_id` | string | `""` | Optional external ID for the assume_role trust policy |
| `project` | string | — | Project name, used in resource naming |
| `environment` | string | — | `dev`, `staging`, or `prod` |
| `create_waf` | bool | `true` | Whether to create a new WAF Web ACL |
| `existing_web_acl_arn` | string | `""` | ARN of existing WAF (when `create_waf = false`) |
| `associate_waf` | bool | `false` | Whether to associate WAF with ALBs |
| `alb_arns` | list(string) | `[]` | ALB ARNs to associate |
| `default_action` | string | `allow` | Default action for unmatched requests |
| `enable_waf_logging` | bool | `false` | Enable WAF logging |
| `log_destination_arn` | string | `""` | CloudWatch Log Group or S3 ARN for logs |

### Rule Action Types

| Action | Behavior | Use Case |
|--------|----------|----------|
| `block` | Blocks matching requests (HTTP 403) | Production |
| `count` | Logs but allows requests | Testing, monitoring |
| `allow` | Disables the rule entirely | Rule not needed |

### tfvars Files

| File | Project | Account | Notes |
|------|---------|---------|-------|
| `terraform.tfvars` | biz2x | 892669526097 | Same-account |
| `biz2credit.tfvars` | biz2credit | 892669526097 | Same-account |
| `new.tfvars` | rapyder | 892669526097 | Same-account |
| `crossaccount.tfvars` | myproject | 307654412330 | Cross-account template |

---

## Deployment

### Via Jenkins (Recommended)

1. Open Jenkins and select the WAF pipeline
2. Click **Build with Parameters**
3. Set parameters:
   - `ENVIRONMENT`: `dev` / `staging` / `prod`
   - `ACTION`: `plan` / `apply` / `destroy`
   - `TERRAFORM_VARIABLE_FILE`: e.g. `terraform.tfvars` or `crossaccount.tfvars`
   - `ROLE_ARN`: leave empty for same-account; set to `arn:aws:iam::307654412330:role/TerraformWAFRole` for cross-account
   - `EXTERNAL_ID`: leave empty (not used with `ecr-ssm-role` trust)
4. Review plan output
5. Approve and apply

### Terraform Backend

State is stored per project in S3:

```
Bucket: vina-terraform-waf-bucket
Key:    waf-alb/{environment}/{tfvars-filename}.tfstate
Region: us-east-1
```

---

## Creating a New WAF for a New Project

No Terraform code changes needed — just create a new `.tfvars` file.

### Step 1 — Create the tfvars file

Copy an existing file:

```bash
cp environments/dev/terraform.tfvars environments/dev/myproject.tfvars
```

Update the identity fields:

```hcl
project     = "myproject"
environment = "dev"
aws_region  = "us-east-1"

bucket = "vina-terraform-waf-bucket"
key    = "waf-alb/dev/myproject.tfstate"   # unique per project
region = "us-east-1"

assume_role_arn         = ""   # same-account — leave empty
assume_role_external_id = ""

alb_arns = ["arn:aws:elasticloadbalancing:us-east-1:892669526097:loadbalancer/app/my-alb/abc123"]
```

### Step 2 — Run via Jenkins

1. Set `TERRAFORM_VARIABLE_FILE` = `myproject.tfvars`
2. Set `ACTION` = `plan`, review output
3. Re-run with `ACTION` = `apply`

### Step 3 — Verify

In AWS Console: **WAF & Shield → Web ACLs → US East (N. Virginia)** — you should see `myproject-dev-web-acl`.

---

## Cross-Account WAF Deployment

Deploy WAF into account `307654412330` while Jenkins runs in account `892669526097`.

### How it works

```
Account 892669526097 (Jenkins)          Account 307654412330 (WAF target)
  ecr-ssm-role  ──sts:AssumeRole──▶    TerraformWAFRole
       │                                      │
  vina-terraform-waf-bucket (state)    WAF Web ACL + ALB association
```

Terraform's AWS provider uses a `dynamic assume_role` block — when `assume_role_arn` is set, it calls `sts:AssumeRole` before creating any resources. When empty, it uses the Jenkins instance credentials directly.

### Step 1 — Create TerraformWAFRole in account 307654412330

Trust policy (allows `ecr-ssm-role` from account `892669526097` to assume it):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::892669526097:role/ecr-ssm-role"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Permissions policy attached to `TerraformWAFRole`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "wafv2:*",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:SetWebAcl",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

### Step 2 — Add inline policy to ecr-ssm-role in account 892669526097

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::307654412330:role/TerraformWAFRole"
    }
  ]
}
```

### Step 3 — Use crossaccount.tfvars

The file `environments/dev/crossaccount.tfvars` is pre-configured with the correct ARNs:

```hcl
assume_role_arn         = "arn:aws:iam::307654412330:role/TerraformWAFRole"
assume_role_external_id = ""

alb_arns = ["arn:aws:elasticloadbalancing:us-east-1:307654412330:loadbalancer/app/my-alb/abc123"]

bucket = "vina-terraform-waf-bucket"
key    = "waf-alb/dev/myproject-crossaccount.tfstate"
```

Update `alb_arns` with the real ALB ARN in account `307654412330`.

### Step 4 — Deploy via Jenkins

Set `TERRAFORM_VARIABLE_FILE` = `crossaccount.tfvars` and run as normal. Leave `ROLE_ARN` and `EXTERNAL_ID` Jenkins parameters empty — the values come from the tfvars file.

### Important: Do NOT pass assume_role_arn for same-account runs

The error `IAM Role cannot be assumed` occurs when `assume_role_arn` is set to a role in the same account as the caller. For same-account deployments (`terraform.tfvars`, `biz2credit.tfvars`, `new.tfvars`), always leave `assume_role_arn = ""`.

---

## Jenkins Pipeline

### Pipeline Stages

```
Validate Parameters → Terraform Init → Terraform Plan → Approval → Terraform Apply → Outputs
```

- Approval gate is skipped when `ACTION = plan`
- Plan output is archived as a Jenkins artifact
- `plan.py` generates a readable summary table after each plan

### Pipeline Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ENVIRONMENT` | `dev` | Target environment (`dev` / `staging` / `prod`) |
| `ACTION` | `plan` | Operation (`plan` / `apply` / `destroy`) |
| `TF_STATE_BUCKET` | `vina-terraform-waf-bucket` | S3 bucket for Terraform state |
| `AWS_REGION` | `us-east-1` | AWS region |
| `TERRAFORM_VARIABLE_FILE` | `terraform.tfvars` | tfvars filename under `environments/{env}/` |
| `ROLE_ARN` | _(empty)_ | Cross-account role ARN to assume. Leave empty for same-account |
| `EXTERNAL_ID` | _(empty)_ | External ID for assume_role. Leave empty when using `ecr-ssm-role` |

### Actions

| Action | What it does |
|--------|-------------|
| `plan` | Shows what Terraform will change — no changes applied |
| `apply` | Applies the plan — creates or updates WAF |
| `destroy` | Destroys all WAF resources for the environment |

---

## WAF Rules Reference

For full WAF rule and sub-rule definitions, see [waf-rules.md](./waf-rules.md).

### Rule Groups Summary

| # | Rule Group | Variable Prefix | WCU | Priority |
|---|-----------|----------------|-----|----------|
| 1 | Core Rule Set (OWASP Top 10) | `aws_managed_rules` | 700 | 9 |
| 2 | Known Bad Inputs (Log4Shell, CVEs) | `known_bad_inputs` | 200 | 15 |
| 3 | SQL Injection | `sql_injection_protection` | 200 | 20 |
| 4 | IP Reputation List | `ip_reputation` | 25 | 25 |
| 5 | Anonymous IP (VPN/Tor/Proxy) | `anonymous_ip` | 50 | 35 |
| 6 | Bot Control | `bot_control` | 50 | 36 |
| 7 | Anti-DDoS | `anti_ddos` | — | 37 |
| 8 | Linux Protection | `linux_protection` | 200 | 50 |
| 9 | Unix Protection | `unix_protection` | 100 | 55 |
| 10 | Windows Protection | `windows_protection` | 200 | 60 |
| 11 | PHP Protection | `php_protection` | 100 | 65 |
| 12 | WordPress Protection | `wordpress_protection` | 100 | 70 |
| — | Rate Limiting | `rate_limiting` | 2 | 40 |

### Priority Order (full)

| Priority | Rule |
|----------|------|
| 3 | Allow-URLS |
| 5 | Allow-IPs |
| 9 | Core Rule Set |
| 15 | Known Bad Inputs |
| 20 | SQL Injection |
| 25 | IP Reputation |
| 30 | Block-IP |
| 35 | Anonymous IP |
| 36 | Bot Control |
| 37 | Anti-DDoS |
| 40 | RateLimit |
| 50 | Linux Protection |
| 55 | Unix Protection |
| 60 | Windows Protection |
| 65 | PHP Protection |
| 70 | WordPress Protection |
| 75 | Restrict-Admin |
| 76 | block-git-access |
| 77 | BlockSpecificURL |
| 78 | BlockExtensions-UriPath |
| 80 | Block-African-Countries-1 |
| 801 | Block-African-Countries-2 |
| 81 | Block-SouthAmerica-Countries |
| 82 | BlockSelectedCountries1 |
| 83 | BlockSelectedCountries2 |
| 84 | AllowCountryUS |

### WCU Budget

Hard limit: 1,500 WCU per Web ACL.

Core + SQLi + Known Bad + IP Reputation + Rate Limit = **1,127 WCU**
Adding Linux = **1,327 WCU** — still within limit.

### Environment Progression

```
dev (count) → staging (block critical rules) → prod (all block)
```

### Rules to enable per use case

| Use case | Recommended rules |
|----------|------------------|
| Standard web app | Core, SQLi, Known Bad Inputs, IP Reputation, RateLimit |
| PHP / WordPress | + PHP Protection, WordPress Protection |
| Linux backend | + Linux Protection |
| Geo-restricted app | + AllowCountryUS or BlockSelectedCountries |
| High-security | All of the above in `block` mode |

---

## Troubleshooting

### Cannot assume IAM Role (cross-account)

```
Error: IAM Role (arn:aws:iam::...) cannot be assumed
AccessDenied: not authorized to perform: sts:AssumeRole
```

Causes and fixes:
- Passing `assume_role_arn` pointing to the same account as the caller — a role cannot assume itself. For same-account runs, set `assume_role_arn = ""`.
- `ecr-ssm-role` in account `892669526097` is missing the `sts:AssumeRole` inline policy for the target role.
- `TerraformWAFRole` in account `307654412330` trust policy does not list `ecr-ssm-role` as a principal.

Verify the caller identity first:
```bash
aws sts get-caller-identity
```

### WCU Limit Exceeded

Error: `web_acl_capacity` over 1,500. Disable unused rules:
```hcl
enable_windows_protection   = false   # saves 200 WCU
enable_linux_protection     = false   # saves 200 WCU
enable_unix_protection      = false   # saves 100 WCU
enable_php_protection       = false   # saves 100 WCU
enable_wordpress_protection = false   # saves 100 WCU
enable_anonymous_ip         = false   # saves 50 WCU
```

### WAF Not Protecting ALB

- Verify `associate_waf = true`
- Check ALB ARN is correct and in the same region
- For cross-account: ensure the ALB ARN uses account `307654412330`
- Wait 5–10 minutes post-deployment
- Check region in AWS Console: **WAF & Shield → Web ACLs → US East (N. Virginia)**

### Terraform State Issues

State locked:
```bash
terraform force-unlock LOCK_ID
```

Stale state (WAF deleted manually):
```bash
terraform state rm 'module.waf.aws_wafv2_web_acl.this[0]'
terraform plan -var-file="environments/dev/terraform.tfvars" -out=tfplan.binary
terraform apply -auto-approve tfplan.binary
```

### S3 Backend 403 Forbidden

Re-init with the correct key:
```bash
terraform init \
  -backend-config="bucket=vina-terraform-waf-bucket" \
  -backend-config="key=waf-alb/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -reconfigure
```

### Tag Value Error

AWS WAF does not allow commas in tag values. Use `+` as separator:
```hcl
# Wrong
Dependencies = "alb,s3,cloudwatch"

# Correct
Dependencies = "alb+s3+cloudwatch"
```

### HCL Syntax Error — Missing Attribute Separator

```hcl
# Wrong
{ name = "SomeRule_BODY" action = "allow" }

# Correct
{ name = "SomeRule_BODY", action = "allow" }
```

### Debugging Commands

```bash
# Check WAF status
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1

# View WAF details
aws wafv2 get-web-acl \
  --scope REGIONAL \
  --name myproject-dev-web-acl \
  --id <web-acl-id> \
  --region us-east-1

# Check ALB associations
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn <web-acl-arn> \
  --region us-east-1

# Verify cross-account role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::307654412330:role/TerraformWAFRole \
  --role-session-name test-session
```

---

## Security Best Practices

1. Start with `count` mode — monitor before switching to `block`
2. Never set `assume_role_arn` to a role in the same account as the caller
3. Use least-privilege permissions on `TerraformWAFRole` — only `wafv2:*` and `elb:SetWebAcl`
4. Enable S3 versioning on `vina-terraform-waf-bucket` for state file protection
5. Enable WAF logging in production — set `enable_waf_logging = true`
6. Review CloudWatch WAF metrics regularly for false positives
7. Use IP allowlists for known trusted CIDRs to avoid blocking legitimate traffic

### Production Checklist

- [ ] All rules in `block` mode
- [ ] `enable_waf_logging = true` with valid `log_destination_arn`
- [ ] CloudWatch alarms configured on WAF metrics
- [ ] IP allowlists populated with trusted CIDRs
- [ ] Rate limiting threshold tuned for expected traffic
- [ ] Cross-account role permissions reviewed and scoped
- [ ] Rollback plan documented

---

*State bucket: `vina-terraform-waf-bucket` | Jenkins account: `892669526097` | WAF target account: `307654412330`*
