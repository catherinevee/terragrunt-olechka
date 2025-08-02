#!/bin/bash

# Olechka AWS Environment Deployment Script
# This script deploys the complete AWS environment in eu-west-1

set -e

echo "🚀 Starting Olechka AWS Environment Deployment"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if terragrunt is installed
    if ! command -v terragrunt &> /dev/null; then
        print_error "Terragrunt is not installed. Please install Terragrunt first."
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Validate configuration
validate_config() {
    print_status "Validating configuration..."
    
    # Check if common.hcl exists
    if [ ! -f "../common.hcl" ]; then
        print_error "common.hcl file not found. Please create it first."
        exit 1
    fi
    
    # Check if AWS account ID is set
    if grep -q "123456789012" "../common.hcl"; then
        print_warning "Please update the AWS account ID in common.hcl before deployment."
    fi
    
    print_status "Configuration validation completed!"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure..."
    
    # Deploy all modules
    print_status "Running terragrunt run-all apply..."
    terragrunt run-all apply --terragrunt-non-interactive
    
    print_status "Infrastructure deployment completed!"
}

# Show deployment summary
show_summary() {
    print_status "Deployment Summary:"
    echo "===================="
    echo "✅ VPC with public and private subnets"
    echo "✅ Security groups configured"
    echo "✅ EC2 instance with Apache web server"
    echo "✅ RDS PostgreSQL database"
    echo "✅ S3 buckets for data and logs"
    echo "✅ Application Load Balancer"
    echo "✅ IAM roles and policies"
    echo "✅ WAF, Inspector, and Macie security services"
    echo ""
    print_status "Your AWS environment is now ready!"
}

# Main deployment flow
main() {
    check_prerequisites
    validate_config
    
    echo ""
    print_warning "This will create AWS resources that may incur costs."
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_infrastructure
        show_summary
    else
        print_status "Deployment cancelled."
        exit 0
    fi
}

# Run main function
main "$@" 