# Testing Guide

## Pre-Deployment Testing

### 1. Syntax and Format Validation

```bash
cd waf-alb-project

# Format all files
terraform fmt -recursive

# Validate configuration
terraform validate

# Run validation script
bash validate.sh
```

### 2. Plan Review

```bash
# Review plan
terraform plan -var-file="terraform.tfvars"

# Check for:
# - Correct resource counts
# - Expected rule configurations
# - Proper ALB associations
```

## Post-Deployment Testing

### 1. Verify WAF Creation

```bash
# Get WAF details
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1

# Check specific Web ACL
aws wafv2 get-web-acl \
  --scope REGIONAL \
  --id <WEB_ACL_ID> \
  --region us-east-1
```

### 2. Verify ALB Association

```bash
# List resources associated with Web ACL
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn <WEB_ACL_ARN> \
  --region us-east-1
```

### 3. Test WAF Rules

#### Test Rate Limiting

```bash
# Send multiple requests to trigger rate limit
for i in {1..3000}; do
  curl -s https://your-alb-endpoint.com/ > /dev/null
  echo "Request $i"
done
```

#### Test SQL Injection Protection

```bash
# This should be blocked
curl "https://your-alb-endpoint.com/?id=1' OR '1'='1"

# Check WAF metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=Rule,Value=AWSManagedRulesSQLiRuleSet \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region us-east-1
```

#### Test IP Allowlist/Blocklist

```bash
# From allowed IP (should succeed)
curl -H "X-Forwarded-For: 10.0.0.1" https://your-alb-endpoint.com/

# From blocked IP (should fail)
curl -H "X-Forwarded-For: 192.0.2.1" https://your-alb-endpoint.com/
```

### 4. Monitor WAF Metrics

```bash
# View sampled requests
aws wafv2 get-sampled-requests \
  --web-acl-arn <WEB_ACL_ARN> \
  --rule-metric-name <RULE_NAME> \
  --scope REGIONAL \
  --time-window StartTime=$(date -u -d '1 hour ago' +%s),EndTime=$(date -u +%s) \
  --max-items 100 \
  --region us-east-1
```

## Jenkins Pipeline Testing

### 1. Test Create WAF Action

Parameters:
- WAF_ACTION: `create_waf`
- ENVIRONMENT: `dev`
- AUTO_APPROVE: `false`

Expected: WAF created without ALB association

### 2. Test Associate WAF Action

Parameters:
- WAF_ACTION: `associate_waf`
- ENVIRONMENT: `dev`
- ALB_ARNS: `<your-alb-arn>`
- EXISTING_WEB_ACL_ARN: `<web-acl-arn-from-step-1>`

Expected: WAF associated with ALB

### 3. Test Disassociate WAF Action

Parameters:
- WAF_ACTION: `disassociate_waf`
- ENVIRONMENT: `dev`

Expected: Association removed, WAF remains

### 4. Test Delete WAF Action

Parameters:
- WAF_ACTION: `delete_waf`
- ENVIRONMENT: `dev`

Expected: WAF and all associations deleted

### 5. Test Create and Associate Action

Parameters:
- WAF_ACTION: `create_and_associate`
- ENVIRONMENT: `dev`
- ALB_ARNS: `<your-alb-arn>`

Expected: WAF created and associated in one step

## Rollback Testing

### 1. Test State Recovery

```bash
# List state versions
aws s3api list-object-versions \
  --bucket your-terraform-state-bucket \
  --prefix waf-alb/dev/terraform.tfstate

# Restore previous version if needed
aws s3api get-object \
  --bucket your-terraform-state-bucket \
  --key waf-alb/dev/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup
```

### 2. Test Disaster Recovery

```bash
# Import existing WAF
terraform import module.waf.aws_wafv2_web_acl.this[0] <WEB_ACL_ID>

# Import ALB association
terraform import 'module.waf.aws_wafv2_web_acl_association.this["<ALB_ARN>"]' \
  <WEB_ACL_ARN>,<ALB_ARN>
```

## Common Issues and Solutions

### Issue: State Lock Error

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Issue: WAF Already Associated

Error: Resource already associated with another Web ACL

Solution: Disassociate existing WAF first:
```bash
aws wafv2 disassociate-web-acl \
  --resource-arn <ALB_ARN> \
  --region us-east-1
```

### Issue: Capacity Exceeded

Error: WAF capacity units exceeded

Solution: Reduce number of rules or increase capacity by removing less critical rules

## Performance Testing

### Load Test with WAF

```bash
# Using Apache Bench
ab -n 10000 -c 100 https://your-alb-endpoint.com/

# Using wrk
wrk -t12 -c400 -d30s https://your-alb-endpoint.com/
```

Monitor CloudWatch metrics during load test:
- AllowedRequests
- BlockedRequests
- CountedRequests
- PassedRequests
