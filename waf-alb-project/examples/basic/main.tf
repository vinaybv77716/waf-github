# =============================================================================
# EXAMPLE: Basic WAF Setup
# =============================================================================

module "waf" {
  source = "../../modules/waf"

  project     = "example"
  environment = "dev"

  tags = {
    Example = "basic-waf"
  }

  # Create WAF and associate with ALB
  create_waf    = true
  associate_waf = true

  alb_arns = [
    "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/example-alb/abc123"
  ]

  # Enable basic protection
  enable_aws_managed_rules        = true
  enable_sql_injection_protection = true
  default_action                  = "allow"
}

output "web_acl_arn" {
  value = module.waf.web_acl_arn
}
