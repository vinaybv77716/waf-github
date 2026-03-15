# AWS WAF v2 Configuration Reference Guide
> **Environment:** `dev` · **Project:** `myapp` · **Region:** `us-east-1`  
> **Config Version:** `2.0.0` · **Last Updated:** 2024-03-13 · **Maintained By:** DevOps Team

---

## Table of Contents

1. [Project & Infrastructure Configuration](#1-project--infrastructure-configuration)
2. [WAF Lifecycle Management](#2-waf-lifecycle-management)
3. [ALB Association Configuration](#3-alb-association-configuration)
4. [WAF Default Action](#4-waf-default-action)
5. [AWS Managed Rule Groups](#5-aws-managed-rule-groups)
   - 5.1 [Core Rule Set](#51-core-rule-set-awsmanagedrulescommonruleset)
   - 5.2 [SQL Injection Protection](#52-sql-injection-protection-awsmanagedrulessqliruleset)
   - 5.3 [Known Bad Inputs](#53-known-bad-inputs-awsmanagedrulesknownbadinputsruleset)
   - 5.4 [IP Reputation List](#54-ip-reputation-list-awsmanagedrulesamazonipreputation list)
   - 5.5 [Anonymous IP List](#55-anonymous-ip-list-awsmanagedrulesanonymousiplist)
   - 5.6 [Linux OS Protection](#56-linux-os-protection-awsmanagedruleslinuxruleset)
   - 5.7 [Unix OS Protection](#57-unix-os-protection-awsmanagedrulesunixruleset)
   - 5.8 [Windows OS Protection](#58-windows-os-protection-awsmanagedruleswindowsruleset)
   - 5.9 [PHP Application Protection](#59-php-application-protection-awsmanagedrulesphpruleset)
   - 5.10 [WordPress Protection](#510-wordpress-application-protection-awsmanagedruleswordpressruleset)
6. [Rate-Based Rules](#6-rate-based-rules-ddos--brute-force-protection)
7. [IP Allow / Block Lists](#7-ip-allow--block-lists)
8. [Geo-Blocking](#8-geo-blocking)
9. [Custom Rules](#9-custom-rules)
10. [Logging & Monitoring](#10-logging--monitoring)
11. [Advanced Configurations](#11-advanced-configurations)
12. [Resource Tagging](#12-resource-tagging)
13. [Deployment Guide](#13-deployment-guide)
14. [Security Recommendations by Priority](#14-security-recommendations-by-priority)
15. [Performance & Cost Considerations](#15-performance--cost-considerations)
16. [Compliance & Audit](#16-compliance--audit)
17. [Incident Response](#17-incident-response)
18. [Troubleshooting Guide](#18-troubleshooting-guide)
19. [WCU Budget Summary](#19-wcu-budget-summary)
20. [Pre & Post Deployment Checklists](#20-pre--post-deployment-checklists)

---

## 1. Project & Infrastructure Configuration

```hcl
project     = "myapp"
environment = "dev"
aws_region  = "us-east-1"
# aws_account_id = "123456789012"
```

| Variable | Value | Notes |
|---|---|---|
| `project` | `myapp` | Used as a prefix on all resource names and metric names |
| `environment` | `dev` | Drives tagging and naming conventions |
| `aws_region` | `us-east-1` | CloudFront WAFs **must** be in `us-east-1`; regional WAFs match your ALB region |
| `aws_account_id` | *(commented)* | Provided for reference only; not consumed by the module directly |

---

## 2. WAF Lifecycle Management

```hcl
create_waf           = true
existing_web_acl_arn = ""
```

| Variable | Value | Meaning |
|---|---|---|
| `create_waf` | `true` | The module **creates** a new WebACL. Set `false` to attach an existing one. |
| `existing_web_acl_arn` | `""` | Required **only** when `create_waf = false`. Full ARN format: `arn:aws:wafv2:REGION:ACCOUNT:regional/webacl/NAME/ID` |

### WAF Scope (auto-derived)

| Scope | When used |
|---|---|
| `REGIONAL` | ALB, API Gateway, App Runner, Cognito |
| `CLOUDFRONT` | CloudFront distributions (must deploy in `us-east-1`) |

---

## 3. ALB Association Configuration

```hcl
associate_waf = true
alb_arns      = []
```

| Variable | Value | Notes |
|---|---|---|
| `associate_waf` | `true` | Whether to associate the WebACL with the listed ALBs |
| `alb_arns` | `[]` | List of ALB ARNs. Format: `arn:aws:elasticloadbalancing:REGION:ACCOUNT:loadbalancer/app/NAME/ID` |

### Key Association Rules

- One WAF → many ALBs ✅
- One ALB → only one WAF ✅
- Association is **region-specific**
- Changes take effect **immediately**

### Example — multiple ALBs

```hcl
alb_arns = [
  "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/dev-alb-1/abc123",
  "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/dev-alb-2/def456",
]
```

---

## 4. WAF Default Action

```hcl
default_action = "allow"
```

| Option | Description |
|---|---|
| `"allow"` | ✅ Recommended — pass requests that don't match any rule |
| `"block"` | High-security mode — block everything not explicitly allowed (requires careful rule tuning) |

### Optional: Custom Block Response (commented out)

```hcl
# default_block_response = {
#   status_code = 403
#   body        = "Access Denied"
#   headers = {
#     "Content-Type" = "text/plain"
#     "X-WAF-Block"  = "default-action"
#   }
# }
```

Customize the HTTP response body and headers returned when the default action is `"block"`.

---

## 5. AWS Managed Rule Groups

> **Total WebACL WCU Limit:** `1500`  
> Managed rule groups are pre-built, AWS-maintained rulesets. Each has a fixed WCU cost.

### WCU Quick Reference

| Rule Group | WCU | Enabled (dev) |
|---|---|---|
| Core Rule Set | 700 | ✅ |
| SQL Injection | 200 | ✅ |
| Known Bad Inputs | 200 | ✅ |
| IP Reputation | 25 | ✅ |
| Anonymous IP | 50 | ❌ |
| Linux | 200 | ✅ |
| Unix | 100 | ❌ |
| Windows | 200 | ❌ |
| PHP | 100 | ❌ |
| WordPress | 100 | ❌ |
| **Estimated Total** | **~1127** | *(~373 WCU remaining)* |

---

### 5.1 Core Rule Set (`AWSManagedRulesCommonRuleSet`)

```hcl
enable_aws_managed_rules = true
aws_managed_rules_action = "count"
# aws_managed_rules_priority = 10
```

| Property | Detail |
|---|---|
| **WCU Cost** | 700 |
| **Priority** | 10 |
| **Action (dev)** | `count` → switch to `block` in production |
| **False Positive Risk** | Low–Medium |
| **Recommendation** | **Always enable** |

**Protects against:** OWASP Top 10, XSS, Path Traversal, LFI, RFI, Command Injection, Size Restrictions.

#### Excluded Rules Reference (all commented out)

| Rule Name | What it blocks |
|---|---|
| `SizeRestrictions_QUERYSTRING` | Query string > 2 KB |
| `SizeRestrictions_Cookie_HEADER` | Cookie header > 10 KB |
| `SizeRestrictions_BODY` | Body > 8 KB |
| `SizeRestrictions_URIPATH` | URI path > 1 KB |
| `EC2MetaDataSSRF_BODY` | `169.254.169.254` in body |
| `EC2MetaDataSSRF_COOKIE` | `169.254.169.254` in cookies |
| `EC2MetaDataSSRF_URIPATH` | `169.254.169.254` in URI |
| `EC2MetaDataSSRF_QUERYARGUMENTS` | `169.254.169.254` in query |
| `GenericLFI_QUERYARGUMENTS` | `../`, `/etc/` in query |
| `GenericLFI_URIPATH` | `../`, `/etc/` in URI |
| `GenericLFI_BODY` | `../`, `/etc/` in body |
| `RestrictedExtensions_URIPATH` | `.log`, `.ini`, `.conf` in URI |
| `RestrictedExtensions_QUERYARGUMENTS` | Restricted extensions in query |
| `GenericRFI_QUERYARGUMENTS` | `http://`, `ftp://` in query |
| `GenericRFI_BODY` | `http://`, `ftp://` in body |
| `GenericRFI_URIPATH` | `http://`, `ftp://` in URI |
| `CrossSiteScripting_COOKIE` | `<script>`, `javascript:` in cookies |
| `CrossSiteScripting_QUERYARGUMENTS` | `<script>`, `javascript:` in query |
| `CrossSiteScripting_BODY` | `<script>`, `javascript:` in body |
| `CrossSiteScripting_URIPATH` | `<script>`, `javascript:` in URI |
| `NoUserAgent_HEADER` | Requests with no `User-Agent` header |
| `UserAgent_BadBots_HEADER` | Known bad-bot user agents |
| `GenericRCE_QUERYARGUMENTS` | RCE patterns in query |
| `GenericRCE_BODY` | RCE patterns in body |
| `GenericRCE_URIPATH` | RCE patterns in URI |

> ℹ️ Uncomment only the rules that cause **verified false positives** in your application.

#### Advanced Options (commented out)

- **`aws_managed_rules_rule_overrides`** — per-rule action override (e.g., change `SizeRestrictions_BODY` from `block` → `count`)
- **`aws_managed_rules_scope_down`** — apply the rule group only to requests matching a specific condition (e.g., URI starts with `/api/`)

---

### 5.2 SQL Injection Protection (`AWSManagedRulesSQLiRuleSet`)

```hcl
enable_sql_injection_protection = true
sql_injection_protection_action = "count"
# sql_injection_priority = 20
```

| Property | Detail |
|---|---|
| **WCU Cost** | 200 |
| **Priority** | 20 |
| **Action (dev)** | `count` |
| **False Positive Risk** | Low |
| **Recommendation** | Always enable if app uses a database |

**Covers:** MySQL, PostgreSQL, MSSQL, Oracle, and other SQL dialects.

#### Excluded Rules Reference

| Rule Name | What it blocks |
|---|---|
| `SQLiExtendedPatterns_QUERYARGUMENTS` | UNION, SELECT, etc. in query |
| `SQLi_QUERYARGUMENTS` | Basic SQL injection in query args |
| `SQLi_BODY` | SQL injection in request body |
| `SQLi_COOKIE` | SQL injection in cookies |
| `SQLi_URIPATH` | SQL injection in URI path |

#### Advanced Option: Sensitivity Level

```hcl
# sql_injection_sensitivity = "HIGH"  # "LOW" | "HIGH"
```

| Level | Behaviour |
|---|---|
| `LOW` | Fewer false positives, may miss some attacks |
| `HIGH` | More comprehensive detection, higher false-positive chance |

#### Scope Down Option

```hcl
# sql_injection_scope_down = {
#   byte_match_statement = {
#     field_to_match        = "URI"
#     positional_constraint = "STARTS_WITH"
#     search_string         = "/api/db/"
#   }
# }
```

---

### 5.3 Known Bad Inputs (`AWSManagedRulesKnownBadInputsRuleSet`)

```hcl
enable_known_bad_inputs = true
known_bad_inputs_action = "count"
# known_bad_inputs_priority = 15
```

| Property | Detail |
|---|---|
| **WCU Cost** | 200 |
| **Priority** | 15 |
| **Action (dev)** | `count` |
| **False Positive Risk** | Very Low |
| **Update Frequency** | AWS updates automatically on new CVEs |
| **Recommendation** | Always enable |

**Includes protection against:** Log4Shell (CVE-2021-44228), Spring4Shell, Java deserialization, and other known exploits.

#### Excluded Rules Reference

| Rule Name | What it blocks |
|---|---|
| `Host_localhost_HEADER` | `localhost` in Host header |
| `PROPFIND_METHOD` | WebDAV PROPFIND HTTP method |
| `ExploitablePaths_URIPATH` | Known exploitable URI paths |
| `Log4JRCE` | Log4j RCE (CVE-2021-44228) |
| `JavaDeserializationRCE` | Java deserialization attacks |
| `Log4JRCE_HEADER` | Log4j patterns in headers |
| `Log4JRCE_QUERYSTRING` | Log4j patterns in query string |
| `Log4JRCE_BODY` | Log4j patterns in body |
| `Log4JRCE_URIPATH` | Log4j patterns in URI |

> ✅ No configuration needed — AWS continuously adds rules as new vulnerabilities emerge.

---

### 5.4 IP Reputation List (`AWSManagedRulesAmazonIpReputationList`)

```hcl
enable_ip_reputation = true
ip_reputation_action = "count"
# ip_reputation_priority = 25
```

| Property | Detail |
|---|---|
| **WCU Cost** | 25 |
| **Priority** | 25 |
| **Action (dev)** | `count` |
| **False Positive Risk** | Very Low |
| **Update Frequency** | Continuous |
| **Recommendation** | Always enable |

**Sources:** AWS threat intelligence, bot networks, scanners, known attackers.

#### Excluded Rules Reference

| Rule Name | What it blocks |
|---|---|
| `AWSManagedIPReputationList` | Main IP reputation database |
| `AWSManagedReconnaissanceList` | IPs performing reconnaissance scans |
| `AWSManagedIPDDoSList` | IPs involved in DDoS attacks |

---

### 5.5 Anonymous IP List (`AWSManagedRulesAnonymousIpList`)

```hcl
enable_anonymous_ip = false   # disabled — saves 50 WCU
anonymous_ip_action = "count"
# anonymous_ip_priority = 35
```

| Property | Detail |
|---|---|
| **WCU Cost** | 50 |
| **Priority** | 35 |
| **Action (dev)** | `count` |
| **False Positive Risk** | ⚠️ HIGH — many legitimate users use VPNs |
| **Recommendation** | Start with `count`, analyze before enabling `block` |

**Covers:** VPNs, proxies, Tor exit nodes, AWS/GCP/Azure hosting provider IPs.

**Use cases:** Prevent account sharing, block automated scraping, high-security apps (banking, healthcare), credential stuffing prevention.

#### 4 Strategy Options

| Option | Config | Effect |
|---|---|---|
| Block all anonymous IPs | `enable=true`, `action=block`, no exclusions | Strictest |
| Block only hosting providers (allow VPNs) | exclude `AnonymousIPList` | Block cloud IPs only |
| Block only VPNs/Tor (allow hosting) | exclude `HostingProviderIPList` | Block VPN/Tor only |
| Monitor only *(recommended first)* | `enable=true`, `action=count` | No blocking, full visibility |

#### Excluded Rules

| Rule Name | Covers |
|---|---|
| `AnonymousIPList` | All anonymous IPs (VPN, Tor, proxies) |
| `HostingProviderIPList` | Cloud hosting providers (AWS, GCP, Azure) |

---

### 5.6 Linux OS Protection (`AWSManagedRulesLinuxRuleSet`)

```hcl
enable_linux_protection = true
linux_protection_action = "count"
# linux_protection_priority = 50
```

| Property | Detail |
|---|---|
| **WCU Cost** | 200 |
| **Priority** | 50 |
| **Action (dev)** | `count` |
| **False Positive Risk** | Low–Medium |
| **When to enable** | Backend runs on Linux (most common) |

**Protects against:** LFI, command injection, shell code, path traversal.

#### Excluded Rules

| Rule Name | What it blocks |
|---|---|
| `LFI_URIPATH` | `/etc/passwd`, `../` in URI |
| `LFI_QUERYSTRING` | LFI patterns in query string |
| `LFI_HEADER` | LFI patterns in headers |
| `LFI_BODY` | LFI patterns in body |
| `LFI_COOKIE` | LFI patterns in cookies |

> ⚠️ Common false positives: file download/upload features, legitimate `../` paths, file browser features.

---

### 5.7 Unix OS Protection (`AWSManagedRulesUnixRuleSet`)

```hcl
enable_unix_protection = false   # disabled — saves 100 WCU
unix_protection_action = "count"
# unix_protection_priority = 55
```

| Property | Detail |
|---|---|
| **WCU Cost** | 100 |
| **Priority** | 55 |
| **False Positive Risk** | Low |
| **When to enable** | Backend runs on Unix/BSD |

**Protects against:** Shell command injection, Unix shell metacharacters.

#### Excluded Rules

| Rule Name | What it blocks |
|---|---|
| `UNIXShellCommandsVariables_QUERYARGUMENTS` | Shell cmds in query (`;`, `\|`, `&&`) |
| `UNIXShellCommandsVariables_BODY` | Shell cmds in body |
| `UNIXShellCommandsVariables_COOKIE` | Shell cmds in cookies |
| `UNIXShellCommandsVariables_URIPATH` | Shell cmds in URI |

> ⚠️ Common false positives: URLs or data legitimately containing `;`, `|`, `&`, `` ` ``, `$`.

---

### 5.8 Windows OS Protection (`AWSManagedRulesWindowsRuleSet`)

```hcl
enable_windows_protection = false   # disabled — saves 200 WCU
windows_protection_action = "count"
# windows_protection_priority = 60
```

| Property | Detail |
|---|---|
| **WCU Cost** | 200 |
| **Priority** | 60 |
| **False Positive Risk** | Low–Medium |
| **When to enable** | Backend runs on Windows |

**Protects against:** PowerShell injection, `cmd.exe` commands, Windows path traversal.

#### Excluded Rules

| Rule Name | What it blocks |
|---|---|
| `WindowsShellCommands_COOKIE` | `cmd`, `dir` etc. in cookies |
| `WindowsShellCommands_QUERYARGUMENTS` | Windows shell cmds in query |
| `WindowsShellCommands_BODY` | Windows shell cmds in body |
| `WindowsShellCommands_URIPATH` | Windows shell cmds in URI |
| `PowerShellCommands_COOKIE` | PowerShell cmds in cookies |
| `PowerShellCommands_QUERYARGUMENTS` | `Get-`, `Set-`, `Invoke-` in query |
| `PowerShellCommands_BODY` | PowerShell cmds in body |
| `PowerShellCommands_URIPATH` | PowerShell cmds in URI |
| `PowerShellCommands_Set_COOKIE` | PowerShell `Set-` cmdlets in cookies |
| `PowerShellCommands_Set_QUERYARGUMENTS` | PowerShell `Set-` in query |
| `PowerShellCommands_Set_BODY` | PowerShell `Set-` in body |

> ⚠️ Common false positives: `C:\` and `\\server\share` paths, PowerShell-like syntax in docs/code samples.

---

### 5.9 PHP Application Protection (`AWSManagedRulesPHPRuleSet`)

```hcl
enable_php_protection = false   # disabled — saves 100 WCU
php_protection_action = "count"
# php_protection_priority = 65
```

| Property | Detail |
|---|---|
| **WCU Cost** | 100 |
| **Priority** | 65 |
| **False Positive Risk** | Low |
| **When to enable** | App uses PHP (WordPress, Laravel, Symfony…) |

**Protects against:** PHP code injection, dangerous functions (`eval`, `exec`, `system`, `passthru`), PHP object injection, PHP-specific file inclusion.

#### Excluded Rules

| Rule Name | What it blocks |
|---|---|
| `PHPHighRiskMethodsVariables_QUERYARGUMENTS` | `eval`, `exec`, `system` in query |
| `PHPHighRiskMethodsVariables_BODY` | Dangerous PHP functions in body |
| `PHPHighRiskMethodsVariables_COOKIE` | Dangerous PHP functions in cookies |

---

### 5.10 WordPress Application Protection (`AWSManagedRulesWordPressRuleSet`)

```hcl
enable_wordpress_protection = false   # disabled — saves 100 WCU
wordpress_protection_action = "count"
# wordpress_protection_priority = 70
```

| Property | Detail |
|---|---|
| **WCU Cost** | 100 |
| **Priority** | 70 |
| **False Positive Risk** | Very Low |
| **When to enable** | App is WordPress |
| **Recommendation** | Always enable for WordPress — switch to `block` in production |

**Protects against:** Plugin vulnerabilities, theme exploits, `wp-admin` brute force, `xmlrpc.php` attacks, `wp-login.php` attacks, known WordPress CVEs.

#### Excluded Rules

| Rule Name | What it blocks |
|---|---|
| `WordPressExploitableCommands_QUERYSTRING` | WP exploitable commands in query |
| `WordPressExploitablePaths_URIPATH` | Known vulnerable WP paths |

#### WordPress-Specific Recommendations

1. Enable in `block` mode for production
2. Combine with rate limiting on `/wp-login.php`
3. Consider IP allowlist for `/wp-admin/` access
4. Keep WordPress core, plugins, and themes updated

---

## 6. Rate-Based Rules (DDoS & Brute Force Protection)

```hcl
enable_rate_limiting  = true
rate_limiting_action  = "count"
rate_limit_threshold  = 2000
# rate_limiting_priority = 40
```

| Property | Detail |
|---|---|
| **WCU Cost** | 2 per rule |
| **Priority** | 40 |
| **Action (dev)** | `count` |
| **Window** | Rolling 5-minute window per IP |
| **False Positive Risk** | Medium |
| **Recommendation** | Always enable |

### Threshold Recommendations by Application Type

| Application Type | Suggested Threshold (req / 5 min) |
|---|---|
| Login endpoints | 10–20 |
| Admin panels | 50–100 |
| REST API | 100–500 |
| GraphQL | 50–200 |
| Web applications | 2,000–10,000 |
| Public websites | 10,000–20,000 |
| Static content | 20,000–50,000 |

### Advanced Options (commented out)

#### Aggregation Key Types

```hcl
# rate_limit_aggregate_key_type = "IP"
```

| Type | Description |
|---|---|
| `IP` | Count per source IP *(default)* |
| `FORWARDED_IP` | Use `X-Forwarded-For` header (for CDN/proxy setups) |
| `CUSTOM_KEYS` | Custom aggregation (advanced) |

#### Forwarded IP Configuration

```hcl
# rate_limit_forwarded_ip_config = {
#   header_name       = "X-Forwarded-For"
#   fallback_behavior = "MATCH"   # MATCH | NO_MATCH
# }
```

| `fallback_behavior` | Meaning |
|---|---|
| `MATCH` | If header missing, use source IP |
| `NO_MATCH` | If header missing, skip rate limit |

#### Custom Response (when action = `block`)

```hcl
# rate_limit_custom_response = {
#   response_code = 429
#   response_headers = { "Retry-After" = "300" }
# }
```

Returns HTTP `429 Too Many Requests` with a `Retry-After: 300` header.

#### Multiple Rate Limit Rules Example

```hcl
# rate_limit_rules = [
#   { name = "api-rate-limit",   priority = 40, threshold = 500,  scope_down = { uri_path_starts_with = "/api/" }   },
#   { name = "login-rate-limit", priority = 41, threshold = 10,   scope_down = { uri_path_equals = "/login" }       },
#   { name = "admin-rate-limit", priority = 42, threshold = 100,  scope_down = { uri_path_starts_with = "/admin/" } },
# ]
```

### Rate Limiting Best Practices

1. Start with `count` mode to establish baseline
2. Monitor CloudWatch to determine appropriate threshold
3. Set threshold **2–3× higher** than normal peak traffic
4. Use different thresholds per endpoint type
5. Implement exponential backoff in client applications
6. Return proper HTTP `429` with `Retry-After` header
7. Use `FORWARDED_IP` if behind CloudFront/CDN
8. Allowlist monitoring services and known partners
9. Log rate limit violations for security analysis

---

## 7. IP Allow / Block Lists

> **WCU Cost:** 1 WCU per 1,000 IP addresses  
> **Maximum:** 10,000 IPs per IP set

### 7.1 IP Allowlist

```hcl
allowlist_ips = []
# Priority: 5  — evaluated FIRST, before all other rules
# Allowlisted IPs bypass ALL WAF rules
```

**Use cases:** Office/corporate networks, trusted partners, monitoring services (Pingdom, UptimeRobot), CI/CD pipeline IPs, admin access, third-party integrations.

#### Example Entries (commented out)

```hcl
# "203.0.113.0/24",     # Main office network
# "198.51.100.0/24",    # Branch office
# "198.51.100.42/32",   # CEO's home IP
# "1.2.3.4/32",         # Pingdom
# "5.6.7.8/32",         # UptimeRobot
# "13.14.15.16/32",     # Jenkins server
# "10.0.0.0/8",         # Private network Class A
# "172.16.0.0/12",      # Private network Class B
# "192.168.0.0/16",     # Private network Class C
```

#### Allowlist Management Best Practices

1. Document the purpose and owner of each IP/range
2. Include contact information in comments
3. Quarterly audit to remove unused entries
4. Use `/32` (single IP) instead of ranges where possible
5. Implement change management for additions
6. Log all changes with justification
7. Never allowlist entire cloud provider ranges
8. Use VPN or bastion host instead of allowlisting many IPs
9. Monitor allowlisted IP activity for anomalies

### 7.2 IP Blocklist

```hcl
blocklist_ips = []
# Priority: 30  — evaluated after allowlist and managed rules
```

**Use cases:** Known attackers from security incidents, abusive scrapers, banned users, spam sources.

#### Example Entries (commented out)

```hcl
# "192.168.1.100/32",   # Attacker from incident #12345
# "172.16.50.0/24",     # Bot network identified 2024-01-15
# "203.0.113.200/32",   # Aggressive scraper, ticket #67890
```

#### Blocklist Management Best Practices

1. Document reason, date, and incident/ticket reference for each entry
2. Set expiration dates for temporary blocks
3. Monthly review to remove outdated blocks
4. Use AWS IP Reputation List for known threats (less manual work)
5. Implement automated updates from SIEM/SOC tools
6. Use threat intelligence feeds for proactive blocking
7. Consider rate limiting before permanent blocking

### Advanced IP Set Options (commented out)

| Option | Description |
|---|---|
| `ip_set_version` | Increment when making changes (for versioning) |
| `ip_set_scope` | `REGIONAL` or `CLOUDFRONT` |
| `ip_address_version` | `IPV4` or `IPV6` |
| `allowlist_ips_v6` | IPv6 allowlist entries |
| `blocklist_ips_v6` | IPv6 blocklist entries |
| `ip_set_update_source` | Dynamic updates from S3 bucket or Lambda |

---

## 8. Geo-Blocking

```hcl
# enable_geo_blocking = false
# geo_blocking_action = "block"
# geo_blocking_priority = 80
```

> **WCU Cost:** 1 per geo match rule · **Maximum:** 50 countries per rule  
> ⚠️ VPNs can bypass geo-blocking. Combine with other security measures.

**Use cases:** GDPR / data sovereignty compliance, reducing attack surface, licensing restrictions, regional business operations.

### 3 Blocking Strategies

#### Strategy 1 — Blocklist (block specific countries)

Best for global applications with known threat regions.

```hcl
# blocked_countries = ["CN", "RU", "KP", "IR", "SY", "CU", "SD", "BY"]
```

#### Strategy 2 — Allowlist (allow only specific countries)

Best for regional applications or strict compliance requirements.

```hcl
# allowed_countries = ["US", "CA", "GB", "DE", "FR", "JP", "AU", ...]
```

#### Strategy 3 — Hybrid (allow all, block specific)

```hcl
# geo_blocking_mode = "hybrid"
# allowed_countries = ["*"]
# blocked_countries = ["CN", "RU", "KP", "IR"]
```

### Scope Down Option

```hcl
# geo_blocking_scope_down = { uri_path_starts_with = "/admin/" }
```

Apply geo-blocking only to specific paths (e.g., admin panel).

### Custom Response for Geo-Blocked Users

```hcl
# geo_blocking_custom_response = {
#   response_code = 403
#   response_headers = { "X-Geo-Block-Reason" = "country-restricted" }
# }
```

### ISO 3166-1 Country Code Quick Reference

| Region | Notable Codes |
|---|---|
| North America | `US`, `CA`, `MX` |
| Europe | `GB`, `DE`, `FR`, `IT`, `ES`, `NL`, `SE`, `CH` |
| Asia-Pacific | `JP`, `AU`, `NZ`, `SG`, `KR`, `IN` |
| Middle East | `IL`, `AE`, `SA` |
| South America | `BR`, `AR`, `CL` |
| High-risk (common blocks) | `CN`, `RU`, `KP`, `IR`, `SY` |

### Geo-Blocking Best Practices

1. Start with `count` mode — measure impact before blocking
2. Analyze traffic patterns and business impact
3. Provide clear messaging to blocked users
4. Implement an exception process for legitimate users
5. Combine with IP allowlist for known good IPs
6. Monitor VPN/proxy bypass attempts
7. Consider CloudFront geo-restriction as an alternative

---

## 9. Custom Rules

> ⚠️ All custom rules require custom Terraform implementation. The sections below document the commented-out patterns.

### 9.1 Custom String Match Rules

**WCU Cost:** 10 per rule  
**Use for:** Blocking specific strings, user agents, headers, query parameters.

#### Available Field Types

| Field Type | Description |
|---|---|
| `URI_PATH` | The URI path (e.g., `/api/users`) |
| `QUERY_STRING` | The full query string |
| `HEADER` | Specific HTTP header (requires `name`) |
| `METHOD` | HTTP method (GET, POST, etc.) |
| `BODY` | Request body content |
| `SINGLE_QUERY_ARG` | Specific query parameter |
| `ALL_QUERY_ARGS` | All query parameters |
| `COOKIES` | Cookie header |

#### Positional Constraint Options

`EXACTLY` · `STARTS_WITH` · `ENDS_WITH` · `CONTAINS` · `CONTAINS_WORD`

#### Available Text Transformations

| Transformation | Effect |
|---|---|
| `NONE` | No change |
| `LOWERCASE` | Convert to lowercase |
| `URL_DECODE` | Decode URL encoding |
| `HTML_ENTITY_DECODE` | Decode HTML entities |
| `BASE64_DECODE` | Decode base64 |
| `CMD_LINE` | Decode command line obfuscation |
| `COMPRESS_WHITE_SPACE` | Collapse multiple spaces |
| `NORMALIZE_PATH` | Normalize file paths |
| `REMOVE_NULLS` | Remove null bytes |
| `SQL_HEX_DECODE` | Decode SQL hex |
| `JS_DECODE` | Decode JavaScript escapes |
| `CSS_DECODE` | Decode CSS escapes |

#### Example Rules (commented out)

**Block bad user agents:**
```hcl
# { name = "BlockBadUserAgents", field = "user-agent", match = "CONTAINS",
#   strings = ["BadBot", "Scraper", "curl", "wget", "python-requests"] }
```

**Block suspicious query params:**
```hcl
# { name = "BlockSuspiciousQueryParams", field = "QUERY_STRING",
#   strings = ["admin=true", "debug=1", "__proto__", "constructor"] }
```

**Block malicious paths:**
```hcl
# { name = "BlockMaliciousPaths", field = "URI_PATH",
#   strings = ["/.env", "/.git", "/phpMyAdmin", "/.aws", "/config.php"] }
```

**Require API key header:**
```hcl
# { name = "RequireAPIKey", field = "x-api-key header", not_statement = true,
#   scope_down = { uri_path_starts_with = "/api/" } }
```

---

### 9.2 Custom Regex Pattern Rules

**WCU Cost:** 25+ per rule (depends on regex complexity)  
⚠️ Complex regex is expensive in WCUs and can slow evaluation.

#### Example Patterns (commented out)

| Rule Name | Pattern | Purpose |
|---|---|---|
| `BlockSQLInjectionPatterns` | `(?i)(union.*select\|insert.*into\|...)` | Custom SQL injection detection |
| `ValidateEmailFormat` | `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$` | Validate email query param format |
| `BlockCreditCardNumbers` | `\b(?:\d{4}[- ]?){3}\d{4}\b` | PCI compliance — detect CC numbers |
| `BlockSSNPatterns` | `\b\d{3}-\d{2}-\d{4}\b` | Privacy compliance — detect SSNs |

#### Regex Best Practices

1. Keep patterns simple — complex = expensive WCU
2. Use anchors (`^`, `$`) where appropriate
3. Avoid catastrophic backtracking patterns
4. Prefer string match over regex when possible
5. Use case-insensitive flag `(?i)` when needed
6. Test with various encodings (URL, base64, etc.)

---

### 9.3 Custom Size Constraint Rules

**WCU Cost:** 1 per rule  
**Use for:** Preventing oversized requests, DoS protection.

**Comparison operators:** `EQ` · `NE` · `LE` · `LT` · `GE` · `GT`

#### Size Limits Reference

| Component | Typical Limit | WAF Inspection Limit |
|---|---|---|
| Request body | — | 8 KB (regional), 16 KB (CloudFront) |
| URI path | 2 KB (browser) | 8 KB |
| Query string | 2–8 KB | 8 KB |
| Single header | 8 KB (HTTP spec) | 8 KB |
| Cookies (total) | 4 KB (browser) | 8 KB |

#### Example Rules (commented out)

```hcl
# LimitBodySize:       > 8192 bytes  → block (HTTP 413)
# LimitURILength:      > 2048 bytes  → block
# LimitQueryStringSize:> 4096 bytes  → block
# LimitHeaderSize:     user-agent > 512 bytes → block
# LimitCookieSize:     cookie header > 4096 bytes → block
```

---

### 9.4 Custom IP Set Rules

**WCU Cost:** 1 per 1,000 IPs

```hcl
# { name = "RestrictAdminByIP", ip_set_arn = "...", not_statement = true,
#   scope_down = { uri_path_starts_with = "/admin/" } }

# { name = "AllowInternalAPIs", ip_set_arn = "...", action = "allow",
#   scope_down = { uri_path_starts_with = "/internal/" } }
```

---

### 9.5 Custom Label-Based Rules

**WCU Cost:** Varies  
**Use for:** Multi-stage rule evaluation, complex AND/OR logic.

Labels allow one rule to "tag" a request for evaluation by a later rule.

```hcl
# Rule 1: Label suspicious paths (action = count, non-terminating)
# Rule 2: Block requests that have the label AND come from a suspicious IP
```

---

### Custom Rules Best Practices

1. Start with `count` action to test rules
2. Monitor CloudWatch metrics for rule effectiveness
3. Document the business reason for each custom rule
4. Use descriptive rule names
5. Assign priorities logically — group related rules
6. Test in dev/staging before production
7. Keep total WCU under 1,500
8. Use `scope_down` to limit rule application
9. Implement custom responses for better UX
10. Regular review and cleanup of unused rules
11. Version-control your WAF configuration
12. Prefer managed rules over custom when possible
13. Monitor false positive rates

---

## 10. Logging & Monitoring

```hcl
enable_waf_logging  = false
log_destination_arn = ""
```

### Log Destination Options

| Destination | Best For | ARN Format | Cost |
|---|---|---|---|
| **CloudWatch Logs** | Real-time monitoring & alerting | `arn:aws:logs:REGION:ACCOUNT:log-group:LOG_GROUP` | $0.50/GB ingested + $0.03/GB stored |
| **S3 Bucket** | Long-term retention, compliance | `arn:aws:s3:::BUCKET_NAME` | $0.023/GB (Standard) |
| **Kinesis Firehose** | Streaming to analytics tools (Splunk, ES) | `arn:aws:firehose:REGION:ACCOUNT:deliverystream/STREAM` | $0.029/GB |

> ℹ️ S3 bucket name **must start with** `aws-waf-logs-`

### Redacted Fields (PII Protection)

```hcl
# log_redacted_fields = [
#   { type = "HEADER", name = "authorization" },
#   { type = "HEADER", name = "cookie" },
#   { type = "HEADER", name = "x-api-key" },
#   { type = "QUERY_STRING", name = "password" },
#   { type = "SINGLE_QUERY_ARG", name = "ssn" },
#   { type = "SINGLE_QUERY_ARG", name = "credit_card" },
# ]
```

### Log Sampling Rate Options

| Rate | Use Case |
|---|---|
| `100%` | Security-critical applications (recommended) |
| `50%` | Balance between cost and visibility |
| `10%` | Cost optimization for very high traffic |
| `1%` | Minimal logging for cost savings |

### Logging Filter Strategies (commented out)

| Strategy | Description |
|---|---|
| Log only BLOCK actions | Minimal logs, only blocked traffic |
| Log only specific rule matches | Focus on rules of interest |
| Log only high-severity events | BLOCK + known bad inputs labels |

### WAF Log Fields Reference

| Field | Description |
|---|---|
| `timestamp` | Request timestamp |
| `webaclId` | Web ACL identifier |
| `terminatingRuleId` | Rule that made the final decision |
| `terminatingRuleType` | Type of the terminating rule |
| `action` | `ALLOW`, `BLOCK`, or `COUNT` |
| `httpRequest.clientIp` | Source IP address |
| `httpRequest.country` | Country code |
| `httpRequest.uri` | Request URI |
| `httpRequest.httpMethod` | HTTP method |
| `ruleGroupList` | All evaluated rule groups |
| `labels` | Labels applied to the request |
| `responseCodeSent` | HTTP response code sent |

---

### 10.1 CloudWatch Metrics

> Metrics are **automatically enabled** for all rules at no additional cost.  
> Namespace: `AWS/WAFV2`

**Metric Names Pattern:** `{project}-{environment}-{rule-name}`  
Examples: `myapp-dev-common-rules`, `myapp-dev-sqli-rules`, `myapp-dev-rate-limit`

#### Available Metrics per Rule

| Metric | Description |
|---|---|
| `AllowedRequests` | Count of allowed requests |
| `BlockedRequests` | Count of blocked requests |
| `CountedRequests` | Requests matched in count mode |
| `PassedRequests` | Requests that passed all rules |

---

### 10.2 CloudWatch Alarms (commented out)

| Alarm | Metric | Threshold | Action |
|---|---|---|---|
| High block rate | `BlockedRequests` | > 100 in 5 min | SNS alert |
| SQL injection | `myapp-dev-sqli-rules` | > 10 in 1 min | SNS alert |
| Rate limit triggered | `myapp-dev-rate-limit` | > 50 in 5 min | SNS ops alert |
| Anomaly detection | `AllowedRequests` | > 10,000 in 5 min | SNS ops alert |

---

### 10.3 CloudWatch Insights Queries

Copy these directly into the CloudWatch Logs Insights console:

**Top blocked IPs:**
```
fields httpRequest.clientIp, action
| filter action = "BLOCK"
| stats count() as blockCount by httpRequest.clientIp
| sort blockCount desc | limit 20
```

**Top blocked countries:**
```
fields httpRequest.country, action
| filter action = "BLOCK"
| stats count() as blockCount by httpRequest.country
| sort blockCount desc | limit 20
```

**Top triggered rules:**
```
fields terminatingRuleId, action
| filter action = "BLOCK"
| stats count() as ruleCount by terminatingRuleId
| sort ruleCount desc | limit 20
```

**SQL injection attempts:**
```
fields @timestamp, httpRequest.clientIp, httpRequest.uri, httpRequest.country
| filter terminatingRuleId like /SQLi/
| sort @timestamp desc | limit 100
```

**Rate limit violations:**
```
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| filter terminatingRuleId like /RateLimit/
| sort @timestamp desc | limit 100
```

**Requests by HTTP method:**
```
fields httpRequest.httpMethod
| stats count() as requestCount by httpRequest.httpMethod
| sort requestCount desc
```

**Blocked requests timeline (5-min bins):**
```
fields @timestamp, action
| filter action = "BLOCK"
| stats count() as blockCount by bin(@timestamp, 5m)
| sort @timestamp desc
```

---

### 10.4 Security Tool Integrations (commented out)

| Integration | Purpose |
|---|---|
| AWS Security Hub | Sends WAF findings to centralized security console |
| Amazon GuardDuty | Analyzes WAF logs for threat detection |
| AWS CloudTrail | Audits all WAF API configuration calls |
| Splunk / Datadog / Elasticsearch | Real-time streaming via Kinesis Firehose |

---

### Monitoring Best Practices

1. Enable logging in production (required for compliance)
2. Use S3 for cost-effective long-term storage
3. Use CloudWatch Logs for real-time analysis and alerting
4. Redact sensitive fields (PII, credentials, tokens)
5. Set appropriate log retention (30–365 days per compliance needs)
6. Create CloudWatch alarms for security events
7. Weekly review of blocked requests
8. Monitor false positive rates
9. Use CloudWatch Insights for log analysis
10. Integrate with SIEM for centralized monitoring
11. Monitor WCU usage to avoid hitting the 1,500 limit
12. Implement log analysis automation with Lambda

---

## 11. Advanced Configurations

### 11.1 Request Inspection Limits

| Component | Regional WAF | CloudFront WAF |
|---|---|---|
| Request body | 8 KB | 16 KB |
| Headers (total) | 8 KB | 8 KB |
| Cookies (total) | 8 KB | 8 KB |
| Query string | 8 KB | 8 KB |
| URI path | 8 KB | 8 KB |

#### Oversize Handling Options

```hcl
# oversize_handling = "CONTINUE"   # Inspect up to limit, continue eval
# oversize_handling = "MATCH"      # Treat oversized as match → trigger rule
# oversize_handling = "NO_MATCH"   # Treat oversized as no match → skip rule
```

#### JSON Body Inspection (API endpoints)

```hcl
# json_body_inspection = {
#   match_scope               = "ALL"       # ALL | KEY | VALUE
#   invalid_fallback_behavior = "EVALUATE_AS_STRING"
# }
```

---

### 11.2 WCU Management

> **WebACL limit:** `1500 WCUs`. Monitor via CloudWatch.

#### WCU Optimization Strategies

1. Disable unused platform-specific rules (Linux/Windows/PHP)
2. Combine IPs into CIDR ranges for IP sets
3. Prefer string match (10 WCU) over regex (25+ WCU)
4. Use `scope_down` to limit rule evaluation scope
5. Combine multiple conditions into single rules
6. Remove unused custom rules
7. Consider multiple WebACLs if hitting the limit

---

### 11.3 Rule Priority Evaluation Order

Rules are evaluated **lowest priority number first**. Evaluation stops when a terminating action (`ALLOW` or `BLOCK`) is taken. `COUNT` is non-terminating — evaluation continues.

| Priority | Rule |
|---|---|
| **5** | IP Allowlist *(always allow trusted IPs first)* |
| **10** | AWS Managed Core Rules |
| **15** | Known Bad Inputs |
| **20** | SQL Injection Protection |
| **25** | IP Reputation List |
| **30** | IP Blocklist |
| **35** | Anonymous IP List |
| **40** | Rate Limiting |
| **50** | Linux Protection |
| **55** | Unix Protection |
| **60** | Windows Protection |
| **65** | PHP Protection |
| **70** | WordPress Protection |
| **80** | Geo-Blocking |
| **100+** | Custom Rules |

> ✅ Leave gaps between priorities to allow future rule insertions without reordering.

---

### 11.4 Available AWS Managed Rule Groups (Full List)

| Rule Group Name | Identifier |
|---|---|
| Core Rule Set | `AWS#AWSManagedRulesCommonRuleSet` |
| SQL Injection | `AWS#AWSManagedRulesSQLiRuleSet` |
| Known Bad Inputs | `AWS#AWSManagedRulesKnownBadInputsRuleSet` |
| IP Reputation | `AWS#AWSManagedRulesAmazonIpReputationList` |
| Anonymous IP | `AWS#AWSManagedRulesAnonymousIpList` |
| Linux | `AWS#AWSManagedRulesLinuxRuleSet` |
| Unix | `AWS#AWSManagedRulesUnixRuleSet` |
| Windows | `AWS#AWSManagedRulesWindowsRuleSet` |
| PHP | `AWS#AWSManagedRulesPHPRuleSet` |
| WordPress | `AWS#AWSManagedRulesWordPressRuleSet` |

**Third-Party (Marketplace):** F5, Fortinet, Imperva, Trend Micro *(require subscription)*

---

### 11.5 Custom Response Configuration (commented out)

| Response Type | Content Type | HTTP Code |
|---|---|---|
| Generic block | `TEXT_HTML` | 403 |
| Rate limited | `APPLICATION_JSON` | 429 |
| Geo blocked | `TEXT_PLAIN` | 403 |
| SQL injection | `APPLICATION_JSON` | 400 |

---

### 11.6 CAPTCHA & JavaScript Challenge (commented out)

```hcl
# captcha_config  = { immunity_time = 300 }   # seconds (300–259200)
# challenge_config = { immunity_time = 300 }
```

| Type | Description |
|---|---|
| **CAPTCHA** | Visual challenge for humans |
| **Challenge** | JavaScript-based bot detection (silent) |

**Use cases:** Login page brute force protection, bot detection, reducing false-positive blocks (challenge instead of block).

---

### 11.7 Association Best Practices

1. One WebACL per environment (dev / staging / prod)
2. Share WebACL across similar resources (multiple ALBs)
3. Use separate WebACLs for different security requirements
4. Test association changes in non-production first
5. Document which resources are associated

---

## 12. Resource Tagging

```hcl
tags = {
  Environment         = "dev"
  ManagedBy           = "Terraform"
  Project             = "myapp"
  Team                = "platform-engineering"
  CostCenter          = "engineering"
  Owner               = "devops-team"
  Compliance          = "pci-dss"
  DataClass           = "confidential"
  SecurityLevel       = "high"
  BackupPolicy        = "daily"
  MaintenanceWindow   = "sun:03:00-sun:04:00"
  MonitoringLevel     = "enhanced"
  ApplicationRole     = "security"
  ServiceTier         = "critical"
  TerraformWorkspace  = "dev"
  ConfigVersion       = "2.0.0"
  TechnicalContact    = "devops@example.com"
}
```

### Tag Categories

| Category | Tags | Purpose |
|---|---|---|
| Core Identification | `Environment`, `ManagedBy`, `Project` | Required on all resources |
| Organizational | `Team`, `CostCenter`, `Owner` | Cost allocation and ownership |
| Compliance & Security | `Compliance`, `DataClass`, `SecurityLevel` | Audit and governance |
| Operational | `BackupPolicy`, `MaintenanceWindow`, `MonitoringLevel` | Automation triggers |
| Technical | `TerraformWorkspace`, `ConfigVersion` | IaC management |
| Contact | `TechnicalContact` | Incident response routing |

### AWS Tag Limits

| Limit | Value |
|---|---|
| Max tags per resource | 50 |
| Tag key max length | 128 characters |
| Tag value max length | 256 characters |
| Case sensitivity | Case-sensitive |

### Cost Allocation Tags to Enable in Billing Console

`Project` · `Environment` · `CostCenter` · `Team` · `ApplicationName` · `BusinessUnit`

### Tagging Best Practices

1. Use consistent key names across all resources
2. Implement AWS Tag Policies to enforce required tags
3. Use lowercase for keys (except acronyms)
4. Use hyphens for multi-word keys
5. Quarterly tag audit to catch drift
6. Automate tag application via Terraform
7. Use tags for automation (start/stop, backup schedules)
8. Include contact info for incident response

---

## 13. Deployment Guide

### Initial Deployment Steps

```bash
# 1. Review and customize all configuration values
# 2. Set project, environment, aws_region
# 3. Add your ALB ARNs to alb_arns
# 4. Keep all rules in "count" mode initially

terraform init
terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars

# 5. Monitor CloudWatch metrics for 24–48 hours
# 6. Gradually switch rules from "count" to "block"
# 7. Enable logging for production
# 8. Set up CloudWatch alarms
```

### Dev Environment Configuration Strategy

| Concern | Approach |
|---|---|
| Rule actions | Use `count` for all rules initially |
| Logging | Enable — essential for debugging |
| Rate limits | Set higher than production (allow load testing) |
| Platform rules | Enable only what matches your stack |
| IP allowlist | Include office, CI/CD, and developer IPs |
| Before promoting | Verify zero false positives |

---

## 14. Security Recommendations by Priority

### 🔴 Critical (Must Enable)

| # | Rule | Action (prod) | Action (dev) |
|---|---|---|---|
| 1 | AWS Managed Core Rule Set | `block` | `count` |
| 2 | SQL Injection Protection | `block` | `count` |
| 3 | Known Bad Inputs | `block` | `block` |
| 4 | IP Reputation List | `block` | `block` |
| 5 | Rate Limiting | `block` | `count` |

### 🟡 High Priority (Strongly Recommended)

| # | Action |
|---|---|
| 6 | IP Allowlist for trusted sources (priority 5) |
| 7 | Logging enabled in production |
| 8 | CloudWatch alarms for security events |

### 🟢 Medium Priority (Recommended)

| # | Action |
|---|---|
| 9 | Platform-specific rules matching your stack |
| 10 | WordPress rules (if applicable) |
| 11 | IP Blocklist for known attackers |

### ⚪ Low Priority (Optional)

| # | Action | Caution |
|---|---|---|
| 12 | Anonymous IP blocking | High false positive risk |
| 13 | Geo-blocking | Assess business impact first |
| 14 | Custom application-specific rules | Test thoroughly |

---

## 15. Performance & Cost Considerations

### WAF Performance Impact

| Metric | Typical Value |
|---|---|
| Added latency per request | 1–5 ms |
| Throughput impact on ALB | Negligible |
| WCU limit per WebACL | 1,500 |
| Body inspection limit (regional) | 8 KB |

### Performance Optimization

1. Use `scope_down` to limit rule evaluation to relevant paths
2. Disable rules not applicable to your stack
3. Order priorities so common-block rules run early
4. Prefer string match (10 WCU) over regex (25+ WCU)
5. Combine IP addresses into CIDR ranges
6. Monitor CloudWatch for slow or expensive rules

---

### WAF Pricing (2024)

| Component | Cost |
|---|---|
| WebACL | $5.00 / month |
| Per rule | $1.00 / month |
| Requests | $0.60 / 1M requests |
| CloudWatch Logs ingestion | $0.50 / GB |
| S3 log storage (Standard) | $0.023 / GB |
| Kinesis Firehose | $0.029 / GB |

### Estimated Monthly Costs

| Environment | WebACL | Rules | Requests | Logging | **Total** |
|---|---|---|---|---|---|
| **Dev** | $5.00 | $12.00 (12 rules) | $0.60 (1M) | $0.00 | **~$17.60** |
| **Production** | $5.00 | $15.00 (15 rules) | $60.00 (100M) | $0.23 (10 GB S3) | **~$80.23** |

### Cost Optimization Strategies

1. Disable unused rules ($1/rule/month saved)
2. Use S3 instead of CloudWatch Logs for long-term storage
3. Implement log sampling (10–50% for high-traffic apps)
4. Use log filtering (log only BLOCK actions — reduces volume 90%+)
5. Share one WebACL across multiple ALBs
6. Set AWS Budget alerts for WAF cost anomalies

---

## 16. Compliance & Audit

### Compliance Requirements Summary

| Framework | Key Requirements |
|---|---|
| **PCI-DSS** | WAF required (Req 6.6), log 90+ days, real-time alerts, quarterly reviews |
| **HIPAA** | Logging for audit trail, S3 encryption, access controls, incident procedures |
| **GDPR** | Redact PII from logs, 30–90 day retention, right-to-erasure process |
| **SOC 2** | Change management, access controls, monitoring, alerting, regular audits |

### Quarterly Audit Checklist

- [ ] Review all enabled rules
- [ ] Analyze blocked request patterns
- [ ] Identify and fix false positives
- [ ] Update IP allowlist / blocklist
- [ ] Review rate limit thresholds
- [ ] Check WCU usage
- [ ] Verify logging is working
- [ ] Test CloudWatch alarms
- [ ] Review access controls
- [ ] Update documentation
- [ ] Security team sign-off
- [ ] Compliance verification

---

## 17. Incident Response

### Response Phases

| Phase | Steps |
|---|---|
| **1. Detection** | CloudWatch alarm triggers → security team notified → review WAF logs |
| **2. Analysis** | Identify attack pattern, determine scope and impact, check if blocked/allowed |
| **3. Containment** | Add attacker IPs to blocklist, adjust rate limits, enable additional rules |
| **4. Eradication** | Block all attack vectors, update rules to prevent recurrence, deploy config |
| **5. Recovery** | Monitor for continued attacks, verify legitimate traffic unaffected, document |
| **6. Post-Incident** | Root cause analysis, update runbooks, improve detection, team training |

### Emergency Contacts

| Role | Contact |
|---|---|
| Security Team | security@example.com |
| On-Call | oncall@example.com |
| Technical Owner | devops@example.com |

---

## 18. Troubleshooting Guide

| Issue | Diagnosis | Solution |
|---|---|---|
| **Legitimate traffic blocked** | Check CloudWatch Logs for the terminating rule | Add rule to `excluded_rules` or change to `count` mode |
| **High false positive rate** | Review rule configurations and metrics | Use `scope_down`, exclude specific sub-rules, tune gradually |
| **WAF not blocking attacks** | Verify rule is in `block` mode (not `count`) | Check rule is enabled, check priority order, verify ALB association |
| **High latency** | Check WCU usage (must be < 1,500) | Disable unused rules, simplify regex, use `scope_down` |
| **Logs not appearing** | Confirm `enable_waf_logging = true` | Verify `log_destination_arn`, check IAM permissions, verify log group exists |
| **Rate limiting too aggressive** | Analyze baseline traffic patterns | Increase `rate_limit_threshold`, use `FORWARDED_IP`, add IPs to allowlist |

### Maintenance Cadence

| Frequency | Tasks |
|---|---|
| **Daily** | Monitor CloudWatch dashboards, review high-priority alarms |
| **Weekly** | Review blocked logs, analyze false positives, update blocklist |
| **Monthly** | Review rule effectiveness, analyze security metrics, update docs |
| **Quarterly** | Full audit, rule optimization, cost analysis, DR test, training |
| **Annual** | Full security assessment, penetration testing, architecture review |

---

## 19. WCU Budget Summary

| Rule Group | WCU | Status |
|---|---|---|
| Core Rule Set | 700 | ✅ Enabled |
| SQL Injection | 200 | ✅ Enabled |
| Known Bad Inputs | 200 | ✅ Enabled |
| IP Reputation | 25 | ✅ Enabled |
| Linux Protection | 200 | ✅ Enabled |
| Anonymous IP | 50 | ❌ Disabled |
| Unix Protection | 100 | ❌ Disabled |
| Windows Protection | 200 | ❌ Disabled |
| PHP Protection | 100 | ❌ Disabled |
| WordPress Protection | 100 | ❌ Disabled |
| Rate Limiting | 2 | ✅ Enabled |
| IP Sets | ~1 | ✅ Enabled |
| **Total Used** | **~1,328** | |
| **Remaining Budget** | **~172** | *(for custom rules)* |

> ⚠️ If adding custom regex rules (25+ WCU each), re-evaluate the budget. Consider disabling additional managed rule groups.

---

## 20. Pre & Post Deployment Checklists

### ✅ Before Deployment

- [ ] Project name and environment set correctly
- [ ] AWS region matches your infrastructure
- [ ] ALB ARNs are correct and accessible
- [ ] Backend S3 bucket exists and accessible
- [ ] All required rules are enabled
- [ ] Rule actions appropriate for environment (`count` / `block`)
- [ ] Rate limit threshold is appropriate
- [ ] IP allowlist includes necessary IPs
- [ ] Logging configured (if required)
- [ ] Tags are complete and accurate
- [ ] Documentation updated
- [ ] Team notified of deployment
- [ ] Rollback plan documented
- [ ] Monitoring and alerts configured

### ✅ After Deployment

- [ ] `terraform apply` completed successfully
- [ ] WebACL is visible in AWS Console
- [ ] ALB association confirmed
- [ ] CloudWatch metrics are appearing
- [ ] Logs are flowing (if enabled)
- [ ] Test requests work as expected
- [ ] No unexpected blocks
- [ ] CloudWatch alarms configured and working
- [ ] Team trained on monitoring
- [ ] Documentation updated with actual deployed values
- [ ] Runbook updated
- [ ] Stakeholders notified of successful deployment

---

## Additional Resources

| Resource | URL |
|---|---|
| AWS WAF Developer Guide | https://docs.aws.amazon.com/waf/ |
| AWS Managed Rule Groups | https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups.html |
| AWS WAF Best Practices | https://docs.aws.amazon.com/waf/latest/developerguide/waf-best-practices.html |
| OWASP Top 10 | https://owasp.org/www-project-top-ten/ |
| CWE Top 25 | https://cwe.mitre.org/top25/ |
| AWS Security Blog | https://aws.amazon.com/blogs/security/ |
| Terraform AWS WAF Docs | https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl |
| AWS WAF Security Automations | https://aws.amazon.com/solutions/implementations/aws-waf-security-automations/ |

---

*Generated from `environments/dev/terraform.tfvars` · Config Version 2.0.0 · March 2024*
