locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  environment = local.common_vars.locals.environment
  project     = local.common_vars.locals.project
  owner       = local.common_vars.locals.owner
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "eu-west-1"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project}"
      Owner       = "${local.owner}"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
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