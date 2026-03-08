# =============================================================================
# REMOTE STATE BACKEND
# Update bucket/key/region before use
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "elasticbeanstalk-us-east-1-307654412330"
    key            = "waf-alb/terraform.tfstate"
    region         = "us-east-1"
   # dynamodb_table = "terraform-state-lock"
    #encrypt        = true
  }
}
