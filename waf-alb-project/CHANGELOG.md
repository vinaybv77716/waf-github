# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2024-03-08

### Added
- Initial release of WAF + ALB Terraform module
- Jenkins pipeline with 5 action modes:
  - create_waf
  - delete_waf
  - associate_waf
  - disassociate_waf
  - create_and_associate
- AWS Managed Rules support:
  - Core Rule Set (OWASP Top 10)
  - SQL Injection Protection
- Rate-based blocking with configurable thresholds
- IP allowlist and blocklist support
- CloudWatch metrics and logging integration
- Comprehensive documentation:
  - README.md
  - SETUP.md
  - TESTING.md
  - ARCHITECTURE.md
- Example configurations (basic and advanced)
- Validation script for pre-deployment checks
- .gitignore for Terraform artifacts

### Configuration
- Users create their own terraform.tfvars based on provided examples
- No environment-specific files included in repository
- Flexible configuration for any environment

### Security
- Input validation for all variables
- Lifecycle protection for production resources
- State locking with DynamoDB
- Encrypted S3 backend for state storage

### Documentation
- Complete API documentation
- Architecture diagrams
- Testing procedures
- Disaster recovery procedures
- Cost optimization guidelines

## [Unreleased]

### Planned Features
- CloudFront distribution support
- Custom rule templates
- Automated rule tuning based on metrics
- Slack/Teams notifications for blocked requests
- Terraform Cloud/Enterprise support
- Multi-region deployment automation
