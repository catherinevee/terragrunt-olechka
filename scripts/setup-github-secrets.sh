#!/bin/bash

# Setup GitHub Secrets for Terragrunt Deployment
# This script configures necessary secrets for GitHub Actions

set -e

echo "Setting up GitHub Secrets for Terragrunt Deployment"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it first."
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Please authenticate with GitHub CLI first: gh auth login"
    exit 1
fi

# Get current AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Unable to get AWS Account ID. Please configure AWS CLI."
    exit 1
fi

# Repository name
REPO="catherinevee/terragrunt-olechka"

echo "Configuring secrets for repository: $REPO"
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Set AWS Account ID as repository variable (not secret since it's not sensitive)
echo "Setting AWS_ACCOUNT_ID as repository variable..."
gh variable set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID" --repo "$REPO" || true

# Set GitHub Actions role ARN
AWS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-role"
echo "Setting AWS_ROLE_ARN secret..."
gh secret set AWS_ROLE_ARN --body "$AWS_ROLE_ARN" --repo "$REPO" || true

# Set default region
echo "Setting AWS_DEFAULT_REGION..."
gh variable set AWS_DEFAULT_REGION --body "eu-central-1" --repo "$REPO" || true

# Placeholder for optional secrets
echo ""
echo "Optional secrets (set these manually if you have them):"
echo "  - INFRACOST_API_KEY: For cost estimation (get from https://www.infracost.io/)"
echo "  - SLACK_WEBHOOK: For Slack notifications"
echo ""
echo "To set these manually, use:"
echo "  gh secret set INFRACOST_API_KEY --repo $REPO"
echo "  gh secret set SLACK_WEBHOOK --repo $REPO"

echo ""
echo "GitHub secrets configuration complete!"
echo ""
echo "Next steps:"
echo "1. Ensure the IAM role 'github-actions-role' exists with appropriate permissions"
echo "2. Push your changes to trigger the workflow"
echo "3. Monitor the Actions tab in GitHub for deployment status"