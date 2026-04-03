# =============================================================================
# Cross-Account WAF Deployment Example
#
# Use this when deploying WAF into a DIFFERENT AWS account than the one
# running Terraform/Jenkins.
#
# The Jenkins EC2 instance uses the IAM instance profile role "ecr-ssm-role"
# in the SOURCE account. The TARGET account must trust this role via
# sts:AssumeRole.
#
# Prerequisites in the TARGET account:
#   1. Create an IAM role (e.g. "TerraformWAFRole") with the trust policy below.
#   2. Attach the required WAFv2 + ELB permissions to that role.
#
# Trust policy for the TARGET account role — principal is ecr-ssm-role:
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "AWS": "arn:aws:iam::892669526097:role/ecr-ssm-role"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
#
# Also ensure ecr-ssm-role in the SOURCE account (892669526097) has sts:AssumeRole permission:
# {
#   "Effect": "Allow",
#   "Action": "sts:AssumeRole",
#   "Resource": "arn:aws:iam::307654412330:role/TerraformWAFRole"
# }
# =============================================================================

project     = "myproject"
environment = "dev"
aws_region  = "us-east-1"

# -----------------------------------------------------------------------------
# Cross-Account: IAM Role in the TARGET account to assume
# Leave assume_role_arn empty ("") for same-account deployments
# -----------------------------------------------------------------------------
assume_role_arn         = "arn:aws:iam::307654412330:role/TerraformWAFRole"
assume_role_external_id = ""   # leave empty — ecr-ssm-role trust uses no external ID

# -----------------------------------------------------------------------------
# Backend — state is stored in the SOURCE account's S3 bucket
# -----------------------------------------------------------------------------
bucket = "vina-terraform-waf-bucket"
key    = "waf-alb/dev/myproject-crossaccount.tfstate"
region = "us-east-1"

# -----------------------------------------------------------------------------
# WAF Lifecycle
# -----------------------------------------------------------------------------
create_waf           = true
existing_web_acl_arn = ""

# -----------------------------------------------------------------------------
# ALB Association — ALB lives in the TARGET account
# -----------------------------------------------------------------------------
associate_waf = true
alb_arns      = ["arn:aws:elasticloadbalancing:us-east-1:307654412330:loadbalancer/app/my-alb/abc123"]

default_action = "allow"

# =============================================================================
# AWS Managed Rule Groups
# =============================================================================

enable_aws_managed_rules   = true
aws_managed_rules_action   = "count"
aws_managed_rules_priority = 9
aws_managed_rules_rule_action_overrides = []

enable_sql_injection_protection = true
sql_injection_protection_action = "count"
sql_injection_priority          = 20
sql_injection_rule_action_overrides = []

enable_known_bad_inputs   = true
known_bad_inputs_action   = "count"
known_bad_inputs_priority = 15
known_bad_inputs_rule_action_overrides = []

enable_ip_reputation   = true
ip_reputation_action   = "count"
ip_reputation_priority = 25
ip_reputation_rule_action_overrides = []

enable_anonymous_ip   = false
anonymous_ip_action   = "count"
anonymous_ip_priority = 35

enable_bot_control           = false
bot_control_action           = "count"
bot_control_priority         = 36
bot_control_inspection_level = "COMMON"
bot_control_rule_action_overrides = []

enable_anti_ddos                = false
anti_ddos_action                = "count"
anti_ddos_priority              = 37
anti_ddos_rule_action_overrides = []

enable_linux_protection   = false
linux_protection_action   = "count"
linux_protection_priority = 50
linux_protection_rule_action_overrides = []

enable_unix_protection   = false
unix_protection_action   = "count"
unix_protection_priority = 55
unix_protection_rule_action_overrides = []

enable_windows_protection   = false
windows_protection_action   = "count"
windows_protection_priority = 60
windows_protection_rule_action_overrides = []

enable_php_protection   = false
php_protection_action   = "count"
php_protection_priority = 65
php_protection_rule_action_overrides = []

enable_wordpress_protection   = false
wordpress_protection_action   = "count"
wordpress_protection_priority = 70
wordpress_protection_rule_action_overrides = []

# =============================================================================
# Custom Rules
# =============================================================================

enable_block_admin   = true
block_admin_priority = 75
block_admin_paths    = ["/admin", "/wp-admin", "/administrator", "/phpmyadmin"]

enable_block_git   = true
block_git_priority = 76

enable_block_specific_urls   = false
block_specific_urls_priority = 77
blocked_urls                 = ["/xmlrpc.php", "/.env"]

enable_block_extensions   = false
block_extensions_priority = 78
blocked_extensions        = [".env", ".bak", ".sql", ".log"]

enable_block_african_countries     = false
block_african_countries_priority   = 80
block_african_countries_priority_2 = 801
african_country_codes_1 = [
  "DZ", "AO", "BJ", "BW", "BF", "BI", "CM", "CV", "CF", "TD",
  "KM", "CG", "CD", "CI", "DJ", "EG", "GQ", "ER", "ET", "GA",
  "GM", "GH", "GN", "GW", "KE", "LS", "LR", "LY", "MG", "MW",
  "ML", "MR", "MU", "MA", "MZ", "NA", "NE", "NG", "RW", "ST",
  "SN", "SL", "SO", "ZA", "SS", "SD", "SZ", "TZ", "TG", "TN"
]
african_country_codes_2 = ["UG", "ZM", "ZW"]

enable_block_south_america   = false
block_south_america_priority = 81
south_america_country_codes  = ["AR", "BO", "BR", "CL", "CO", "EC", "GY", "PY", "PE", "SR", "UY", "VE"]

enable_block_selected_countries_1   = false
block_selected_countries_1_priority = 82
selected_country_codes_1            = []

enable_block_selected_countries_2   = false
block_selected_countries_2_priority = 83
selected_country_codes_2            = []

enable_allow_country_us   = false
allow_country_us_priority = 84

enable_allow_specific_urls   = false
allow_specific_urls_priority = 3
allowed_urls                 = ["/health", "/ping"]

# =============================================================================
# Rate Limiting
# =============================================================================
enable_rate_limiting   = true
rate_limiting_action   = "block"
rate_limiting_priority = 40
rate_limit_threshold   = 2000

# =============================================================================
# IP Allow / Block Lists
# =============================================================================
allowlist_ips      = []
blocklist_ips      = []
allowlist_priority = 5
blocklist_priority = 30

# =============================================================================
# Logging
# =============================================================================
enable_waf_logging  = false
log_destination_arn = ""

# =============================================================================
# Tags
# =============================================================================
tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
  Project     = "myproject"
}
