locals {
  # Parse account and region from path
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl", "account.hcl"), {})
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl", "region.hcl"), {})
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl", "env.hcl"), {})

  account_id   = local.account_vars.locals.account_id
  region       = local.region_vars.locals.region
  environment  = local.env_vars.locals.environment
}

# Remote state configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "terraform-state-${local.account_id}-${local.region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks-${local.account_id}"

    s3_bucket_tags = {
      Environment = local.environment
      ManagedBy   = "Terragrunt"
      Project     = "ai-tools"
    }
  }
}

# Generate provider configuration with version constraint
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = "= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.31.0"
    }
  }
}

provider "aws" {
  region = "${local.region}"

  default_tags {
    tags = {
      Environment = "${local.environment}"
      Region      = "${local.region}"
      ManagedBy   = "Terragrunt"
      Project     = "ai-tools"
    }
  }
}
EOF
}

# Version constraints
terraform_version_constraint  = "= 1.5.7"
terragrunt_version_constraint = "= 0.50.17"

# Retry configuration for handling transient errors
retry_configuration {
  retry_max_attempts       = 3
  retry_sleep_interval_sec = 5
}

# Input validation
inputs = {
  project_name = "ai-tools"
  environment  = local.environment
  region       = local.region
}