# =============================================================================
# MODULE: WAF (Web ACL) + ALB Association
# Supports: Create/Delete WAF | Associate/Disassociate WAF with ALB
# =============================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# -----------------------------------------------------------------------------
# IP Sets (optional - used in rules)
# -----------------------------------------------------------------------------
resource "aws_wafv2_ip_set" "allowlist" {
  count              = var.create_waf && length(var.allowlist_ips) > 0 ? 1 : 0
  name               = "${local.name_prefix}-allowlist"
  description        = "Allowlisted IPs for ${local.name_prefix}"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.allowlist_ips

  tags = merge(var.tags, { Name = "${local.name_prefix}-allowlist" })
}

resource "aws_wafv2_ip_set" "blocklist" {
  count              = var.create_waf && length(var.blocklist_ips) > 0 ? 1 : 0
  name               = "${local.name_prefix}-blocklist"
  description        = "Blocklisted IPs for ${local.name_prefix}"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.blocklist_ips

  tags = merge(var.tags, { Name = "${local.name_prefix}-blocklist" })
}

# -----------------------------------------------------------------------------
# WAF Web ACL
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "this" {
  count       = var.create_waf ? 1 : 0
  name        = "${local.name_prefix}-web-acl"
  description = "WAF Web ACL for ${local.name_prefix}"
  scope       = "REGIONAL"

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # Prevent accidental deletion in production
  lifecycle {
    prevent_destroy = false # Set to true in production
  }

  # ---- AWS Managed Rules ----
  dynamic "rule" {
    for_each = var.enable_aws_managed_rules ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 10

      override_action {
        dynamic "none" {
          for_each = var.managed_rule_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = var.managed_rule_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-common-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # ---- AWS SQL Injection Rules ----
  dynamic "rule" {
    for_each = var.enable_sql_injection_protection ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 20

      override_action {
        dynamic "none" {
          for_each = var.managed_rule_override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = var.managed_rule_override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-sqli-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # ---- IP Blocklist Rule ----
  dynamic "rule" {
    for_each = var.create_waf && length(var.blocklist_ips) > 0 ? [1] : []
    content {
      name     = "BlockListedIPs"
      priority = 30

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blocklist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-blocklist"
        sampled_requests_enabled   = true
      }
    }
  }

  # ---- IP Allowlist Rule ----
  dynamic "rule" {
    for_each = var.create_waf && length(var.allowlist_ips) > 0 ? [1] : []
    content {
      name     = "AllowListedIPs"
      priority = 5

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowlist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-allowlist"
        sampled_requests_enabled   = true
      }
    }
  }

  # ---- Rate Limiting Rule ----
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 40

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit_threshold
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-web-acl" })
}

# -----------------------------------------------------------------------------
# WAF Logging Configuration (optional)
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count                   = var.create_waf && var.enable_waf_logging && var.log_destination_arn != "" ? 1 : 0
  log_destination_configs = [var.log_destination_arn]
  resource_arn            = aws_wafv2_web_acl.this[0].arn
}

# -----------------------------------------------------------------------------
# WAF <-> ALB Association
# Controlled independently — can associate/disassociate without recreating WAF
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "this" {
  for_each = var.associate_waf ? toset(var.alb_arns) : toset([])

  resource_arn = each.value
  web_acl_arn  = var.create_waf ? aws_wafv2_web_acl.this[0].arn : var.existing_web_acl_arn

  # Ensure WAF exists before association
  depends_on = [aws_wafv2_web_acl.this]
}

# Validation: Ensure existing_web_acl_arn is provided when not creating WAF
resource "null_resource" "validate_web_acl_arn" {
  count = !var.create_waf && var.associate_waf && var.existing_web_acl_arn == "" ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: existing_web_acl_arn must be provided when create_waf=false and associate_waf=true' && exit 1"
  }
}
