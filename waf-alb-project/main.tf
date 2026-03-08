# =============================================================================
# ROOT MODULE — WAF + ALB Management
# =============================================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# -----------------------------------------------------------------------------
# WAF Module
# -----------------------------------------------------------------------------
module "waf" {
  source = "./modules/waf"

  # Project metadata
  project     = var.project
  environment = var.environment
  tags        = var.tags

  # WAF lifecycle flags
  create_waf           = var.create_waf
  existing_web_acl_arn = var.existing_web_acl_arn

  # Association control
  associate_waf = var.associate_waf
  alb_arns      = var.alb_arns

  # WAF rules configuration
  default_action                  = var.default_action
  enable_aws_managed_rules        = var.enable_aws_managed_rules
  managed_rule_override_action    = var.managed_rule_override_action
  enable_sql_injection_protection = var.enable_sql_injection_protection
  enable_rate_limiting            = var.enable_rate_limiting
  rate_limit_threshold            = var.rate_limit_threshold

  # IP lists
  allowlist_ips = var.allowlist_ips
  blocklist_ips = var.blocklist_ips

  # Logging
  enable_waf_logging  = var.enable_waf_logging
  log_destination_arn = var.log_destination_arn
}
