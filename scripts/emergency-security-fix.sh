#!/bin/bash
# Emergency Security Hardening Script for Terragrunt Olechka
# Run this script immediately to address critical security issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}🚨 EMERGENCY SECURITY HARDENING SCRIPT${NC}"
echo "This script will fix critical security vulnerabilities in Terragrunt configuration"
echo

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    exit 1
fi

# Get actual AWS account ID
echo -e "${YELLOW}🔍 Getting AWS Account ID...${NC}"
ACTUAL_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [[ -z "$ACTUAL_ACCOUNT_ID" ]]; then
    echo -e "${RED}❌ Could not get AWS Account ID. Please configure AWS CLI credentials.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS Account ID: $ACTUAL_ACCOUNT_ID${NC}"

# Backup original files
echo -e "${YELLOW}📦 Creating backup of original files...${NC}"
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
find . -name "*.hcl" -exec cp --parents {} "$BACKUP_DIR/" \;
echo -e "${GREEN}✅ Backup created in $BACKUP_DIR${NC}"

# Fix 1: Replace placeholder AWS Account ID
echo -e "${YELLOW}🔧 Fixing placeholder AWS Account ID...${NC}"
find . -name "*.hcl" -type f -exec sed -i "s/123456789012/$ACTUAL_ACCOUNT_ID/g" {} \;
echo -e "${GREEN}✅ AWS Account ID updated in all files${NC}"

# Fix 2: Create secure security group template
echo -e "${YELLOW}🔧 Creating secure security group template...${NC}"
mkdir -p _templates
cat > _templates/secure-security-group.hcl <<'EOF'
# Secure Security Group Template
# Use this template to replace overly permissive security groups

locals {
  # Define allowed IP ranges (update these for your organization)
  vpn_cidr_blocks = [
    "10.0.0.0/8",      # Private networks
    "172.16.0.0/12",   # Private networks
    "192.168.0.0/16"   # Private networks
  ]
  
  office_cidr_blocks = [
    "203.0.113.0/24"   # Replace with your office IP range
  ]
}

inputs = {
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH from VPN and office networks only"
      cidr_blocks = join(",", concat(local.vpn_cidr_blocks, local.office_cidr_blocks))
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP from load balancer only"
      cidr_blocks = var.alb_security_group_cidr  # Reference ALB security group
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from load balancer only"
      cidr_blocks = var.alb_security_group_cidr  # Reference ALB security group
    }
  ]
}
EOF
echo -e "${GREEN}✅ Secure security group template created${NC}"

# Fix 3: Create enhanced state security configuration
echo -e "${YELLOW}🔧 Creating enhanced state security configuration...${NC}"
cat > _templates/secure-remote-state.hcl <<'EOF'
# Enhanced Remote State Security Configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "terragrunt-state-${local.aws_account_id}-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    kms_key_id     = "arn:aws:kms:${local.aws_region}:${local.aws_account_id}:alias/terragrunt-state-key"
    dynamodb_table = "terragrunt-state-locks-${local.aws_account_id}"
    
    # CRITICAL: Enable all security controls
    skip_bucket_ssencryption           = false
    skip_bucket_enforced_tls           = false
    skip_bucket_public_access_blocking = false
    skip_bucket_root_access            = false
    skip_bucket_versioning             = false
    skip_bucket_accesslogging          = false
    
    # Access logging configuration
    accesslogging_bucket_name   = "terragrunt-access-logs-${local.aws_account_id}"
    accesslogging_target_prefix = "state-access-logs/"
    
    # Enhanced tagging
    s3_bucket_tags = {
      Purpose            = "terraform-state"
      Environment        = local.environment
      DataClassification = "restricted"
      BackupRequired     = "true"
      SecurityLevel      = "maximum"
      ComplianceRequired = "true"
    }
  }
}
EOF
echo -e "${GREEN}✅ Enhanced state security configuration created${NC}"

# Fix 4: Create dependency mock outputs template
echo -e "${YELLOW}🔧 Creating dependency mock outputs template...${NC}"
cat > _templates/mock-outputs.hcl <<'EOF'
# Standard Mock Outputs Template
# Add these to all dependency blocks

# VPC Dependency Mock Outputs
dependency "vpc" {
  config_path = "../../network/vpc"
  
  mock_outputs = {
    vpc_id                     = "vpc-mock-12345678"
    vpc_cidr_block            = "10.0.0.0/16"
    private_subnets           = ["subnet-mock-private-1", "subnet-mock-private-2", "subnet-mock-private-3"]
    public_subnets            = ["subnet-mock-public-1", "subnet-mock-public-2", "subnet-mock-public-3"]
    database_subnets          = ["subnet-mock-db-1", "subnet-mock-db-2", "subnet-mock-db-3"]
    private_subnets_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets_cidr_blocks  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    nat_gateway_ids           = ["nat-mock-1", "nat-mock-2", "nat-mock-3"]
    internet_gateway_id       = "igw-mock-12345678"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# Security Group Dependency Mock Outputs
dependency "security_group" {
  config_path = "../../network/securitygroup"
  
  mock_outputs = {
    security_group_id  = "sg-mock-12345678"
    security_group_arn = "arn:aws:ec2:region:account:security-group/sg-mock-12345678"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# KMS Dependency Mock Outputs
dependency "kms" {
  config_path = "../../security/kms"
  
  mock_outputs = {
    key_arn    = "arn:aws:kms:region:account:key/mock-key-id"
    key_id     = "mock-key-id"
    alias_arn  = "arn:aws:kms:region:account:alias/mock-alias"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}
EOF
echo -e "${GREEN}✅ Mock outputs template created${NC}"

# Fix 5: Create secure RDS configuration template
echo -e "${YELLOW}🔧 Creating secure RDS configuration template...${NC}"
cat > _templates/secure-rds.hcl <<'EOF'
# Secure RDS Configuration Template
inputs = {
  # Use AWS managed master password
  manage_master_user_password   = true
  master_user_secret_kms_key_id = dependency.kms.outputs.key_arn
  
  # Enable deletion protection
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${local.project}-${local.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Enhanced backup configuration
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  copy_tags_to_snapshot  = true
  
  # Enable encryption
  storage_encrypted = true
  kms_key_id       = dependency.kms.outputs.key_arn
  
  # Enhanced monitoring
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id      = dependency.kms.outputs.key_arn
  
  # Enable enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = dependency.iam_role.outputs.arn
  
  # Enable logging
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Parameter group for security
  parameters = [
    {
      name  = "log_connections"
      value = "1"
    },
    {
      name  = "log_disconnections"
      value = "1"
    },
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"  # Log queries > 1 second
    }
  ]
}
EOF
echo -e "${GREEN}✅ Secure RDS template created${NC}"

echo
echo -e "${GREEN}🎉 Emergency security fixes completed!${NC}"
echo -e "${YELLOW}⚠️  NEXT STEPS:${NC}"
echo "1. Review and apply the templates in _templates/ directory"
echo "2. Update security groups to use the secure template"
echo "3. Add mock outputs to all dependency blocks"
echo "4. Test configurations with 'terragrunt plan'"
echo "5. Apply changes environment by environment (dev → staging → prod)"
echo
echo -e "${RED}🚨 CRITICAL: Review all changes before applying to production!${NC}"