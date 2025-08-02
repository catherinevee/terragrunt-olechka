locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  environment = "staging"
  project     = local.common_vars.locals.project
  owner       = local.common_vars.locals.owner
  
  # Enhanced staging-specific configurations
  staging_config = {
    instance_types = {
      app_server = "t3.medium"
      db_server  = "db.t3.small"
      bastion    = "t3.micro"
      monitoring = "t3.small"
    }
    scaling_config = {
      min_size = 2
      max_size = 5
      desired_capacity = 3
    }
    backup_retention = 14
    monitoring_interval = 30
    auto_scaling_enabled = true
    load_balancing_enabled = true
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
      CostCenter  = "staging-ops"
      DataClassification = "confidential"
      AutoShutdown = "false"
      Backup = "required"
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

# Monitoring provider for centralized logging
provider "aws" {
  alias  = "monitoring"
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project}"
      Owner       = "${local.owner}"
      ManagedBy   = "terragrunt"
      Purpose     = "monitoring"
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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
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
  # Enhanced naming convention for staging environment
  name_prefix = "olechka-staging"
  
  # Environment-specific variables
  environment_vars = {
    is_production = false
    is_staging = true
    backup_enabled = true
    monitoring_enabled = true
    auto_scaling_enabled = true
    cost_optimization_enabled = false
    high_availability_enabled = true
  }
  
  # Network configuration for staging
  network_config = {
    vpc_cidr = "10.2.0.0/16"
    private_subnets = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
    public_subnets  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
    database_subnets = ["10.2.201.0/24", "10.2.202.0/24", "10.2.203.0/24"]
  }
  
  # Security configuration
  security_config = {
    allowed_ssh_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]  # VPN ranges
    encryption_enabled = true
    waf_enabled = true
    inspector_enabled = true
    guardduty_enabled = true
  }
  
  # Monitoring configuration
  monitoring_config = {
    cloudwatch_enabled = true
    xray_enabled = true
    prometheus_enabled = true
    grafana_enabled = true
    alerting_enabled = true
  }
}
EOF
} 