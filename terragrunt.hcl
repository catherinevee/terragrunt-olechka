# Root Terragrunt configuration for Olechka AWS Environment
# This file provides common configuration for all environments

locals {
  # Read common variables
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  
  # Extract common values
  environment = local.common_vars.locals.environment
  project     = local.common_vars.locals.project
  owner       = local.common_vars.locals.owner
  aws_account_id = local.common_vars.locals.aws_account_id
}

# Remote state configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "terragrunt-state-${local.aws_account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-1:${local.aws_account_id}:alias/terragrunt-state-key"
    dynamodb_table = "terragrunt-state-locks-${local.aws_account_id}"
  }
}

# Generate common provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "eu-west-1"
  
  assume_role {
    role_arn = "arn:aws:iam::${local.aws_account_id}:role/terragrunt-admin-role"
    session_name = "terragrunt-session"
  }
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project}"
      Owner       = "${local.owner}"
      ManagedBy   = "terragrunt"
      SecurityLevel = "high"
      LastUpdated = "$(date +%Y-%m-%d)"
    }
  }
}

# Configure AWS provider security settings
provider "aws" {
  alias = "security"
  region = "eu-west-1"
  
  assume_role {
    role_arn = "arn:aws:iam::${local.aws_account_id}:role/terragrunt-security-role"
    session_name = "terragrunt-security-session"
  }
}
EOF
}

# Generate versions configuration
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = "1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }
  }
}
EOF
}

# Include all environments
include "eu-west-1" {
  path = "./eu-west-1"
} 