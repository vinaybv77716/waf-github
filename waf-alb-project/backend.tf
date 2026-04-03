# =============================================================================
# REMOTE STATE BACKEND
# Update bucket/key/region before use
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "vina-terraform-waf-bucket"
    key            = "wafalb/"
    region         = "us-east-1"
  }
}
