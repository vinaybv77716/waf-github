# Setup Guide

## Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.3.0
3. Jenkins with required plugins (if using CI/CD)
4. S3 bucket for Terraform state
5. DynamoDB table for state locking (optional but recommended)

## Initial Setup

### 1. Configure Backend

Edit `backend.tf` and replace placeholder values:

```hcl
bucket         = "your-actual-terraform-state-bucket"
region         = "your-aws-region"
dynamodb_table = "your-lock-table-name"
```

### 2. Create Your Configuration File

Create a `terraform.tfvars` file with your configuration:

```hcl
aws_region  = "us-east-1"
project     = "myapp"
environment = "dev"

tags = {
  Project     = "myapp"
  Environment = "dev"
  ManagedBy   = "terraform"
  Team        = "platform"
}

create_waf           = true
existing_web_acl_arn = ""
associate_waf        = true

alb_arns = [
  "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/abc123"
]

default_action                  = "allow"
enable_aws_managed_rules        = true
managed_rule_override_action    = "count"
enable_sql_injection_protection = true
enable_rate_limiting            = true
rate_limit_threshold            = 5000

allowlist_ips = []
blocklist_ips = []

enable_waf_logging  = false
log_destination_arn = ""
```

### 3. Initialize Terraform

```bash
cd waf-alb-project
terraform init
```

### 4. Validate Configuration

```bash
terraform validate
terraform fmt -recursive
```

## Manual Deployment

### Create WAF and Associate with ALB

```bash
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Disassociate WAF from ALB

Update `terraform.tfvars`:
```hcl
associate_waf = false
```

Then apply:
```bash
terraform apply -var-file="terraform.tfvars"
```

### Delete WAF

```bash
terraform destroy -var-file="terraform.tfvars"
```

## Jenkins Setup

### 1. Configure AWS Credentials

Create Jenkins credentials with IDs:
- `aws-dev`
- `aws-staging`
- `aws-prod`

### 2. Create S3 State Bucket

```bash
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

### 3. Create DynamoDB Lock Table

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 4. Create Jenkins Pipeline

1. Create new Pipeline job in Jenkins
2. Configure SCM to point to your repository
3. Set Script Path to `waf-alb-project/jenkinsfile`
4. Save and run with parameters

**Important:** The Jenkins pipeline does NOT use terraform.tfvars files. Instead:
- All configuration is passed via Jenkins pipeline parameters
- The `ENVIRONMENT` parameter is used only for:
  - AWS credentials selection (`aws-dev`, `aws-staging`, `aws-prod`)
  - Terraform state file organization (`waf-alb/{environment}/terraform.tfstate`)
- WAF configuration (rules, ALB ARNs, etc.) is set through pipeline parameters

## Troubleshooting

### State Lock Issues

If you encounter state lock errors:

```bash
terraform force-unlock <LOCK_ID>
```

### WAF Association Errors

Ensure ALB ARNs are correct and in the same region as the WAF.

### Permission Issues

Required IAM permissions:
- `wafv2:*`
- `elasticloadbalancing:DescribeLoadBalancers`
- `elasticloadbalancing:DescribeTags`
- `logs:CreateLogDelivery` (if logging enabled)
- `s3:*` (for state bucket)
- `dynamodb:*` (for lock table)
