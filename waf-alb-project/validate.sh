#!/bin/bash
# =============================================================================
# Terraform Validation Script
# =============================================================================

set -e

echo "=== Terraform Validation ==="
echo ""

# Check Terraform version
echo "1. Checking Terraform version..."
terraform version
echo ""

# Format check
echo "2. Checking Terraform formatting..."
if ! terraform fmt -check -recursive; then
    echo "❌ Formatting issues found. Run 'terraform fmt -recursive' to fix."
    exit 1
fi
echo "✅ Formatting OK"
echo ""

# Initialize
echo "3. Initializing Terraform..."
terraform init -backend=false
echo ""

# Validate
echo "4. Validating configuration..."
terraform validate
echo "✅ Validation passed"
echo ""

# Check for common issues
echo "5. Checking for common issues..."

# Check if backend.tf has placeholder values
if grep -q "YOUR_TERRAFORM_STATE_BUCKET" backend.tf; then
    echo "⚠️  WARNING: backend.tf contains placeholder values. Update before deployment."
fi

# Check for terraform.tfvars
if [ -f "terraform.tfvars" ]; then
    echo "  Checking terraform.tfvars..."
    
    # Check for empty ALB ARNs
    if grep -q 'alb_arns = \[\]' "terraform.tfvars"; then
        echo "  ⚠️  WARNING: No ALB ARNs configured"
    fi
else
    echo "  ⚠️  WARNING: terraform.tfvars not found. Create one before deployment."
fi

echo ""
echo "=== Validation Complete ==="
