# AWS WAF Dev Environment Configuration – Detailed Explanation

This document explains the **AWS WAF v2 Terraform configuration** line‑by‑line, including commented sections. It serves as a **learning guide and documentation** for engineers maintaining the configuration.

---

# 1. Header Comments

```
# =============================================================================
# DEV Environment Configuration - MAXIMUM GRANULARITY
# =============================================================================
```

These comments describe the **purpose of the file**.

Meaning:

* The configuration is for the **development environment**.
* "Maximum granularity" means **very detailed configuration with full control** over AWS WAF behavior.

---

# 2. Project & Infrastructure Configuration

```
project     = "myapp"
environment = "dev"
aws_region  = "us-east-1"
```

### project

Name of the application or system protected by WAF.

Example

```
myapp
```

Used for:

* naming resources
* tagging
* metrics

### environment

Defines deployment stage.

Common values:

| Value   | Meaning     |
| ------- | ----------- |
| dev     | development |
| staging | testing     |
| prod    | production  |

### aws_region

AWS region where WAF resources are created.

Example:

```
us-east-1
```

Important:

CloudFront WAF must be deployed in **us-east-1**.

---

# 3. AWS Account Configuration

```
# aws_account_id = "123456789012"
```

Commented because it is **optional reference information**.

Used when constructing ARNs manually.

Example ARN:

```
arn:aws:wafv2:us-east-1:123456789012:regional/webacl/name/id
```

---

# 4. WAF Lifecycle Management

```
create_waf = true
```

Meaning:

Terraform will **create a new WebACL**.

If false:

```
create_waf = false
existing_web_acl_arn = "arn..."
```

Then Terraform **uses an existing WAF**.

---

# 5. existing_web_acl_arn

```
existing_web_acl_arn = ""
```

Used only when:

```
create_waf = false
```

Example value

```
arn:aws:wafv2:us-east-1:123456789012:regional/webacl/my-waf/id
```

---

# 6. WAF Scope

Comment:

```
# REGIONAL: ALB, API Gateway
# CLOUDFRONT: CloudFront
```

Explanation:

AWS WAF has **two scopes**.

| Scope      | Used For                 |
| ---------- | ------------------------ |
| REGIONAL   | ALB, API Gateway         |
| CLOUDFRONT | CloudFront distributions |

---

# 7. ALB Association

```
associate_waf = true
```

Meaning:

Attach the WAF WebACL to **Application Load Balancer**.

---

# 8. alb_arns

```
alb_arns = []
```

List of ALB ARNs that should be protected by WAF.

Example

```
alb_arns = [
"arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/dev-alb/abc"
]
```

Notes:

* One WAF can protect **multiple ALBs**.
* One ALB can have **only one WAF**.

---

# 9. Default Action

```
default_action = "allow"
```

Meaning:

If request **does not match any rule**, WAF will:

```
ALLOW
```

Alternative

```
default_action = "block"
```

Used in **very strict security environments**.

---

# 10. Custom Block Response

Commented block shows **custom HTTP response** when WAF blocks a request.

Example

```
status_code = 403
body = "Access Denied"
```

Custom headers can also be added.

---

# 11. AWS Managed Rule Groups

AWS provides **prebuilt rule groups** maintained by AWS.

These protect against:

* OWASP Top 10
* SQL injection
* XSS
* RCE
* bot attacks

Each rule group consumes **WCU (WebACL Capacity Units)**.

Limit per WebACL:

```
1500 WCU
```

---

# 12. Core Rule Set

```
enable_aws_managed_rules = true
```

Enables

```
AWSManagedRulesCommonRuleSet
```

This rule group protects against:

* XSS
* command injection
* path traversal
* LFI
* RFI

---

# 13. aws_managed_rules_action

```
aws_managed_rules_action = "count"
```

Actions:

| Mode  | Behavior      |
| ----- | ------------- |
| block | block request |
| count | monitor only  |
| allow | allow request |

Best practice:

Dev → count

Production → block

---

# 14. Rule Priority

```
# aws_managed_rules_priority = 10
```

Rules are executed based on **priority order**.

Lower number = higher priority.

Example

```
IP allowlist priority = 5
managed rules = 10
```

---

# 15. Rule Exclusion

```
aws_managed_rules_excluded_rules
```

Used to disable specific sub‑rules.

Example:

```
SizeRestrictions_BODY
```

This prevents blocking large request bodies.

Common when:

* uploading files
* large JSON APIs

---

# 16. SQL Injection Rule Set

```
enable_sql_injection_protection = true
```

Enables

```
AWSManagedRulesSQLiRuleSet
```

Detects:

```
SELECT * FROM users
UNION SELECT
DROP TABLE
```

---

# 17. Known Bad Inputs

```
enable_known_bad_inputs = true
```

Protects against **known vulnerabilities** like:

* Log4Shell
* Spring4Shell

AWS updates rules automatically.

---

# 18. IP Reputation

```
enable_ip_reputation = true
```

Blocks IPs known for:

* scanning
* botnets
* malware

Uses AWS threat intelligence.

---

# 19. Anonymous IP List

```
enable_anonymous_ip = false
```

Detects traffic from

* VPN
* TOR
* proxies

Disabled because it can block **legitimate users**.

---

# 20. Linux Protection

```
enable_linux_protection = true
```

Protects Linux servers against

* shell injection
* file inclusion

Use when backend runs Linux.

---

# 21. Unix Protection

```
enable_unix_protection = false
```

Used mainly for BSD systems.

Disabled here to **save WCU**.

---

# 22. Windows Protection

```
enable_windows_protection = false
```

Detects

* PowerShell attacks
* cmd.exe injection

Enable only for Windows servers.

---

# 23. PHP Protection

```
enable_php_protection = false
```

Protects against

* eval()
* exec()

Used only for PHP apps.

---

# 24. WordPress Protection

```
enable_wordpress_protection = false
```

Protects WordPress against:

* plugin vulnerabilities
* wp-login attacks

---

# 25. Rate Limiting

```
enable_rate_limiting = true
```

Prevents

* DDoS
* brute force

Threshold

```
rate_limit_threshold = 2000
```

Meaning:

2000 requests per IP in **5 minutes**.

---

# 26. IP Allowlist

```
allowlist_ips = []
```

IPs that bypass all rules.

Example

```
203.0.113.42/32
```

Common use:

* office IP
* monitoring systems

---

# 27. IP Blocklist

```
blocklist_ips = []
```

List of permanently blocked IPs.

Used for

* attackers
* abusive bots

---

# 28. Geo Blocking

Commented section explaining country blocking.

Example

```
blocked_countries = ["CN","RU"]
```

Used for compliance or security.

---

# 29. Custom Rules

Custom WAF rules allow blocking based on

* strings
* regex
* headers
* query parameters

Example

```
BlockBadUserAgents
```

Blocks user agents like

```
curl
wget
python-requests
```

---

# 30. Logging

```
enable_waf_logging = false
```

When enabled logs go to

* CloudWatch
* S3
* Kinesis

Logs include

* IP
* country
* rule triggered
* request URI

---

# 31. CloudWatch Metrics

WAF automatically creates metrics:

* AllowedRequests
* BlockedRequests
* CountedRequests

Used for monitoring.

---

# 32. WCU Capacity

Maximum

```
1500 WCU
```

Example calculation

| Rule             | WCU |
| ---------------- | --- |
| Core rules       | 700 |
| SQL injection    | 200 |
| Known bad inputs | 200 |
| IP reputation    | 25  |
| Rate limit       | 2   |

Total

```
1127 WCU
```

---

# 33. Rule Priority Order

Evaluation order

```
1 Allowlist
2 Managed rules
3 Blocklist
4 Rate limiting
5 Platform rules
6 Custom rules
```

---

# 34. Custom Responses

Allows returning custom messages

Example

```
HTTP 429
Too many requests
```

---

# 35. CAPTCHA

AWS WAF supports

```
CAPTCHA
Challenge
```

Used for bot protection.

---

# 36. Logging Analysis

Common queries

Top blocked IPs

```
stats count() by httpRequest.clientIp
```

Top countries

```
stats count() by httpRequest.country
```

---

# 37. Deployment Steps

1 terraform init

2 terraform plan

3 terraform apply

4 monitor metrics

5 switch rules from count → block

---

# 38. Security Best Practices

Critical rules

* Core rule set
* SQL injection
* Known bad inputs
* IP reputation

---

# 39. Cost Estimate

Example dev cost

| Item     | Cost  |
| -------- | ----- |
| WebACL   | $5    |
| Rules    | $12   |
| Requests | $0.60 |

Total

```
~$17/month
```

---

# 40. Tags

Tags help with

* cost tracking
* ownership
* compliance

Example

```
Environment = dev
Project = myapp
Team = platform-engineering
```

---

# 41. Maintenance Tasks

Daily

* check dashboards

Weekly

* review blocked traffic

Monthly

* optimize rules

Quarterly

* security audit

---

# 42. Troubleshooting

Example issue

Legitimate traffic blocked

Solution

* check WAF logs
* identify rule
* exclude rule

---

# Conclusion

This configuration represents a **production‑grade AWS WAF architecture with full control** including:

* managed rule sets
* rate limiting
* IP reputation
* custom rules
* logging
* monitoring

It is suitable for protecting applications behind:

* ALB
* API Gateway
* CloudFront

and can be safely deployed through **Terraform infrastructure as code**.
