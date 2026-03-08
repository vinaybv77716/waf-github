# Deployment Methods

This project supports two deployment approaches with different configuration methods.

## Method 1: Manual Terraform Deployment

### Configuration
Uses `terraform.tfvars` file that you create in the project root.

### Steps

1. Create `terraform.tfvars`:
```hcl
aws_region  = "us-east-1"
project     = "myapp"
environment = "dev"

tags = {
  Project     = "myapp"
  Environment = "dev"
  ManagedBy   = "terraform"
}

create_waf    = true
associate_waf = true

alb_arns = [
  "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/abc123"
]

default_action                  = "allow"
enable_aws_managed_rules        = true
managed_rule_override_action    = "count"
enable_sql_injection_protection = true
enable_rate_limiting            = false
rate_limit_threshold            = 5000

allowlist_ips = []
blocklist_ips = []

enable_waf_logging  = false
log_destination_arn = ""
```

2. Deploy:
```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Pros
- Full control over configuration
- Easy to version control (if desired)
- Simple local development
- Can create multiple .tfvars for different scenarios

### Cons
- Manual process
- Need to manage tfvars files
- No built-in approval workflow

---

## Method 2: Jenkins Pipeline Deployment

### Configuration
Uses Jenkins pipeline parameters - NO terraform.tfvars files needed.

### How It Works

The Jenkins pipeline:
1. Takes all configuration as pipeline parameters
2. Dynamically builds Terraform `-var` flags from parameters
3. Uses `ENVIRONMENT` parameter only for:
   - AWS credentials selection (`aws-dev`, `aws-staging`, `aws-prod`)
   - State file organization (`waf-alb/{environment}/terraform.tfstate`)

### Pipeline Parameters

All WAF configuration is passed via these parameters:

| Parameter | Purpose |
|-----------|---------|
| `WAF_ACTION` | What operation to perform |
| `ENVIRONMENT` | AWS credentials + state file path |
| `AWS_REGION` | Target region |
| `ALB_ARNS` | Comma-separated ALB ARNs |
| `EXISTING_WEB_ACL_ARN` | For associating existing WAF |
| `ENABLE_AWS_MANAGED_RULES` | Toggle Core Rule Set |
| `ENABLE_SQL_INJECTION_PROTECTION` | Toggle SQLi protection |
| `ENABLE_RATE_LIMITING` | Toggle rate limiting |
| `RATE_LIMIT_THRESHOLD` | Rate limit value |
| `DEFAULT_ACTION` | Allow or block |
| `MANAGED_RULE_OVERRIDE` | None or count |
| `AUTO_APPROVE` | Skip approval gate |
| `TF_STATE_BUCKET` | S3 bucket for state |

### Example Pipeline Execution

```groovy
// Jenkins builds this command:
terraform plan \
  -var='project=myapp' \
  -var='environment=dev' \
  -var='aws_region=us-east-1' \
  -var='create_waf=true' \
  -var='associate_waf=true' \
  -var='alb_arns=["arn:aws:..."]' \
  -var='default_action=allow' \
  -var='enable_aws_managed_rules=true' \
  ...
```

### Pros
- No tfvars files to manage
- Built-in approval workflow
- Audit trail in Jenkins
- Easy to trigger from UI
- Consistent deployment process
- Parameter validation

### Cons
- Requires Jenkins setup
- Less flexible than tfvars
- Parameters can be verbose

---

## Comparison

| Feature | Manual (tfvars) | Jenkins (parameters) |
|---------|----------------|---------------------|
| Configuration | terraform.tfvars file | Pipeline parameters |
| Approval | Manual review | Built-in approval stage |
| Audit | Git history | Jenkins build history |
| Flexibility | High | Medium |
| Setup Complexity | Low | High |
| Best For | Development, testing | Production, CI/CD |

---

## Recommendations

### Use Manual Deployment When:
- Developing locally
- Testing configurations
- One-off deployments
- Learning the module
- Need maximum flexibility

### Use Jenkins Pipeline When:
- Production deployments
- Need approval workflows
- Want audit trails
- Multiple team members deploying
- Standardized process required

---

## Hybrid Approach

You can use both methods:

1. **Development**: Use manual deployment with terraform.tfvars
2. **Production**: Use Jenkins pipeline with parameters

This gives you flexibility during development and control in production.

---

## Important Notes

### State Management

Both methods use the same backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "YOUR_TERRAFORM_STATE_BUCKET"
    key            = "waf-alb/terraform.tfstate"  # Manual
    # OR
    key            = "waf-alb/{environment}/terraform.tfstate"  # Jenkins
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Jenkins uses environment-specific state paths** to separate dev/staging/prod states.

### No Conflict

The two methods don't conflict because:
- Manual deployment: You control everything
- Jenkins deployment: Parameters override any local files
- Different state file paths can be used

### Migration

To migrate from manual to Jenkins:
1. Note your current terraform.tfvars values
2. Create Jenkins pipeline
3. Set pipeline parameters to match tfvars values
4. Test in dev environment first
5. Update state file path if needed
