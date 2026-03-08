# =============================================================================
# EXAMPLE: Advanced WAF Setup with Rate Limiting and IP Lists
# =============================================================================

module "waf" {
  source = "../../modules/waf"

  project     = "example"
  environment = "prod"

  tags = {
    Example = "advanced-waf"
  }

  # Create WAF and associate with multiple ALBs
  create_waf    = true
  associate_waf = true

  alb_arns = [
    "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/api-alb/abc123",
    "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/web-alb/def456"
  ]

  # Enable all protections
  enable_aws_managed_rules        = true
  enable_sql_injection_protection = true
  enable_rate_limiting            = true
  rate_limit_threshold            = 2000
  default_action                  = "allow"

  # IP lists
  allowlist_ips = [
    "10.0.0.0/8",    # Internal network
    "203.0.113.0/24" # Office IP range
  ]

  blocklist_ips = [
    "192.0.2.0/24" # Known malicious range
  ]

  # Enable logging
  enable_waf_logging  = true
  log_destination_arn = "arn:aws:logs:us-east-1:123456789012:log-group:aws-waf-logs-example"
}

output "web_acl_arn" {
  value = module.waf.web_acl_arn
}

output "web_acl_capacity" {
  value = module.waf.web_acl_capacity
}
