# =============================================================================
# MODULE VARIABLES: WAF
# =============================================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# WAF Lifecycle
# -----------------------------------------------------------------------------

variable "create_waf" {
  description = "Whether to create a new WAF Web ACL"
  type        = bool
  default     = true
}

variable "existing_web_acl_arn" {
  description = "ARN of existing WAF Web ACL (used when create_waf = false)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Association
# -----------------------------------------------------------------------------

variable "associate_waf" {
  description = "Whether to associate WAF with ALBs"
  type        = bool
  default     = false
}

variable "alb_arns" {
  description = "List of ALB ARNs to associate with the WAF"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# WAF Rules
# -----------------------------------------------------------------------------

variable "default_action" {
  description = "Default action for non-matched requests (allow or block)"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "Default action must be 'allow' or 'block'."
  }
}

variable "enable_aws_managed_rules" {
  description = "Enable AWS Managed Core Rule Set"
  type        = bool
  default     = true
}

variable "managed_rule_override_action" {
  description = "Override action for managed rules (none or count)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "count"], var.managed_rule_override_action)
    error_message = "Managed rule override action must be 'none' or 'count'."
  }
}

variable "enable_sql_injection_protection" {
  description = "Enable AWS Managed SQL Injection Rule Set"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate-based blocking"
  type        = bool
  default     = false
}

variable "rate_limit_threshold" {
  description = "Maximum requests per 5-minute window per IP"
  type        = number
  default     = 2000

  validation {
    condition     = var.rate_limit_threshold >= 100 && var.rate_limit_threshold <= 20000000
    error_message = "Rate limit threshold must be between 100 and 20,000,000."
  }
}

# -----------------------------------------------------------------------------
# IP Lists
# -----------------------------------------------------------------------------

variable "allowlist_ips" {
  description = "List of IP CIDR blocks to always allow"
  type        = list(string)
  default     = []
}

variable "blocklist_ips" {
  description = "List of IP CIDR blocks to always block"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "enable_waf_logging" {
  description = "Enable WAF logging"
  type        = bool
  default     = false
}

variable "log_destination_arn" {
  description = "ARN of log destination (CloudWatch Log Group or S3 bucket)"
  type        = string
  default     = ""
}
