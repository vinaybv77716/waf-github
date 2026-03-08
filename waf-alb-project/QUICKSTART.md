# Quick Start Guide

Get up and running with WAF + ALB in 5 minutes.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.3.0 installed
- AWS CLI configured
- Existing ALB(s) to protect

## Step 1: Clone and Configure

```bash
# Navigate to project
cd waf-alb-project

# Update backend configuration
# Edit backend.tf and replace YOUR_TERRAFORM_STATE_BUCKET
```

## Step 2: Create Configuration File

Create `terraform.tfvars` in the project root:

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
  "arn:aws:elasticloadbalancing:us-east-1:YOUR_ACCOUNT:loadbalancer/app/YOUR_ALB/ID"
]

default_action                  = "allow"
enable_aws_managed_rules        = true
managed_rule_override_action    = "count"
enable_sql_injection_protection = true
enable_rate_limiting            = false

allowlist_ips = ["YOUR_OFFICE_IP/32"]
blocklist_ips = []

enable_waf_logging  = false
log_destination_arn = ""
```

## Step 3: Deploy

```bash
# Initialize Terraform
terraform init

# Review changes
terraform plan -var-file="terraform.tfvars"

# Deploy
terraform apply -var-file="terraform.tfvars"
```

## Step 4: Verify

```bash
# Check WAF was created
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1

# Verify ALB association
terraform output associated_alb_arns
```

## Step 5: Test

```bash
# Normal request (should succeed)
curl https://your-alb-endpoint.com/

# SQL injection attempt (should be blocked)
curl "https://your-alb-endpoint.com/?id=1' OR '1'='1"
```

## Common First-Time Issues

### Issue: Backend bucket doesn't exist

```bash
# Create the bucket first
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
```

### Issue: ALB not found

Verify ALB ARN format:
```
arn:aws:elasticloadbalancing:REGION:ACCOUNT:loadbalancer/app/NAME/ID
```

### Issue: Permission denied

Ensure your AWS credentials have these permissions:
- wafv2:*
- elasticloadbalancing:Describe*
- s3:* (for state bucket)

## Next Steps

- Review [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design
- Read [TESTING.md](TESTING.md) for testing procedures
- Check [SETUP.md](SETUP.md) for Jenkins integration
- Explore [examples/](examples/) for advanced configurations

## Getting Help

- Check [TESTING.md](TESTING.md) for troubleshooting
- Review CloudWatch metrics for WAF activity
- Open an issue for bugs or questions
