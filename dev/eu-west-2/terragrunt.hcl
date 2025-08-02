locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  environment = "development"
  project     = local.common_vars.locals.project
  owner       = local.common_vars.locals.owner
  
  # Enhanced dev-specific configurations
  dev_config = {
    instance_types = {
      app_server = "t3.small"
      db_server  = "t3.micro"
      bastion    = "t3.nano"
    }
    scaling_config = {
      min_size = 1
      max_size = 3
      desired_capacity = 2
    }
    backup_retention = 7
    monitoring_interval = 60
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project}"
      Owner       = "${local.owner}"
      ManagedBy   = "terragrunt"
      CostCenter  = "dev-ops"
      DataClassification = "internal"
    }
  }
}

# Additional provider for backup and disaster recovery
provider "aws" {
  alias  = "backup"
  region = "eu-west-1"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project}"
      Owner       = "${local.owner}"
      ManagedBy   = "terragrunt"
      Purpose     = "backup"
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
EOF
}

# Generate additional configuration files for enhanced functionality
generate "locals" {
  path      = "locals.tf"
  if_exists = "overwrite"
  contents  = <<EOF
locals {
  # Enhanced naming convention for dev environment
  name_prefix = "olechka-dev"
  
  # Environment-specific variables
  environment_vars = {
    is_production = false
    backup_enabled = true
    monitoring_enabled = true
    auto_scaling_enabled = true
    cost_optimization_enabled = true
  }
  
  # Network configuration for dev
  network_config = {
    vpc_cidr = "10.1.0.0/16"
    private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
    public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
    database_subnets = ["10.1.201.0/24", "10.1.202.0/24", "10.1.203.0/24"]
  }
  
  # Security configuration
  security_config = {
    allowed_ssh_ips = ["0.0.0.0/0"]  # In dev, allow broader access
    encryption_enabled = true
    waf_enabled = true
    inspector_enabled = true
  }
}
EOF
} 