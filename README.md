# WAF + ALB Management — Terraform Module & Jenkins Pipeline

## Overview

This project provides a **reusable Terraform module** and a **dynamic Jenkins pipeline** to manage AWS WAFv2 Web ACLs and their association with Application Load Balancers (ALBs).

---

## Directory Structure

```
waf-alb-project/
├── jenkinsfile                         ← Dynamic pipeline (all actions)
├── main.tf                             ← Root config — calls the module
├── variables.tf                        ← Root variable declarations
├── outputs.tf                          ← Root outputs
├── backend.tf                          ← S3 remote state config
├── validate.sh                         ← Validation script
├── .gitignore                          ← Git ignore patterns
│
├── modules/
│   └── waf/
│       ├── main.tf                     ← WAF resources + association logic
│       ├── variables.tf                ← Module input variables
│       └── outputs.tf                  ← Module outputs
│
└── examples/
    ├── basic/main.tf                   ← Basic usage example
    └── advanced/main.tf                ← Advanced usage example
```

---

## Supported Actions (Jenkins Pipeline)

| `WAF_ACTION`           | What it does                                          |
|------------------------|-------------------------------------------------------|
| `create_waf`           | Creates WAF Web ACL only — no ALB association         |
| `delete_waf`           | Destroys WAF Web ACL + removes all associations       |
| `associate_waf`        | Associates an existing WAF with one or more ALBs      |
| `disassociate_waf`     | Removes WAF association from ALBs (WAF itself stays)  |
| `create_and_associate` | Creates WAF **and** associates it with ALBs in one go |

---

## Jenkins Pipeline Parameters

| Parameter                        | Description                                               |
|----------------------------------|-----------------------------------------------------------|
| `WAF_ACTION`                     | One of the 5 actions above                                |
| `ENVIRONMENT`                    | `dev` / `staging` / `prod` (used for state key and credentials) |
| `AWS_REGION`                     | Target AWS region                                         |
| `ALB_ARNS`                       | Comma-separated ALB ARNs (required for assoc. actions)    |
| `EXISTING_WEB_ACL_ARN`           | Required only for `associate_waf` without creating new    |
| `ENABLE_AWS_MANAGED_RULES`       | Toggle AWS Core Rule Set                                  |
| `ENABLE_SQL_INJECTION_PROTECTION`| Toggle AWS SQLi Rule Set                                  |
| `ENABLE_RATE_LIMITING`           | Toggle rate-based blocking                                |
| `RATE_LIMIT_THRESHOLD`           | Requests per 5 min per IP before block                    |
| `DEFAULT_ACTION`                 | `allow` or `block` for unmatched requests                 |
| `MANAGED_RULE_OVERRIDE`          | `none` (enforce) or `count` (monitor only)                |
| `AUTO_APPROVE`                   | Skip manual approval gate                                 |
| `TF_STATE_BUCKET`                | S3 bucket for Terraform state                             |

**Note:** The Jenkins pipeline uses the `ENVIRONMENT` parameter for:
- Selecting AWS credentials (`aws-dev`, `aws-staging`, `aws-prod`)
- Organizing Terraform state files (`waf-alb/{environment}/terraform.tfstate`)
- All other configuration is passed via pipeline parameters (not tfvars files)

---

## Module Usage (Standalone)

```hcl
module "waf" {
  source = "./modules/waf"

  project     = "myapp"
  environment = "prod"
  tags        = { Team = "platform" }

  # Action flags
  create_waf    = true
  associate_waf = true
  alb_arns      = ["arn:aws:elasticloadbalancing:..."]

  # Rules
  enable_aws_managed_rules        = true
  enable_sql_injection_protection = true
  enable_rate_limiting            = true
  rate_limit_threshold            = 2000
  default_action                  = "allow"
  managed_rule_override_action    = "none"
}
```

---

## Action Flag Matrix

| Goal                             | `create_waf` | `associate_waf` | `destroy` |
|----------------------------------|:------------:|:---------------:|:---------:|
| Create WAF only                  | `true`       | `false`         | no        |
| Delete WAF                       | `true`       | `false`         | **yes**   |
| Associate existing WAF with ALB  | `false`      | `true`          | no        |
| Disassociate WAF from ALB        | any          | `false`         | no        |
| Create WAF + Associate           | `true`       | `true`          | no        |

---

## Deployment Methods

This project supports two deployment approaches:

1. **Manual Terraform** - Uses `terraform.tfvars` file (you create)
2. **Jenkins Pipeline** - Uses pipeline parameters (no tfvars needed)

See [DEPLOYMENT_METHODS.md](waf-alb-project/DEPLOYMENT_METHODS.md) for detailed comparison.

## Prerequisites

### For Manual Deployment
1. **Terraform** >= 1.3.0
2. **AWS CLI** configured
3. **S3 bucket** for remote state
4. Create your own `terraform.tfvars` file

### For Jenkins Pipeline
1. **Jenkins plugins**: Pipeline, Credentials Binding, AWS Credentials
2. **AWS credentials** stored in Jenkins as `aws-dev`, `aws-staging`, `aws-prod`
3. **Terraform** installed on Jenkins agent (`>= 1.3.0`)
4. **S3 bucket** created for remote state + DynamoDB table for state locking
5. Update `backend.tf` with your actual S3 bucket name

---

## WAF Rules Included

- **AWS Managed Core Rule Set** — OWASP Top 10 protection
- **AWS SQLi Rule Set** — SQL injection protection
- **IP Allowlist** — Bypass rules for trusted IPs
- **IP Blocklist** — Hard-block known bad IPs
- **Rate Limiting** — Block IPs exceeding request threshold
