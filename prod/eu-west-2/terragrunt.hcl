locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  environment = "production"
  project     = local.common_vars.locals.project
  owner       = local.common_vars.locals.owner
  
  # Enhanced production-specific configurations
  production_config = {
    instance_types = {
      app_server = "t3.large"
      db_server  = "db.t3.medium"
      bastion    = "t3.micro"
      monitoring = "t3.medium"
      cache      = "cache.t3.micro"
    }
    scaling_config = {
      min_size = 3
      max_size = 10
      desired_capacity = 5
    }
    backup_retention = 30
    monitoring_interval = 15
    auto_scaling_enabled = true
    load_balancing_enabled = true
    multi_az_enabled = true
    disaster_recovery_enabled = true
    compliance_enabled = true
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
      CostCenter  = "production-ops"
      DataClassification = "restricted"
      AutoShutdown = "false"
      Backup = "required"
      Compliance = "enabled"
      DisasterRecovery = "enabled"
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

# Compliance provider for audit and governance
provider "aws" {
  alias  = "compliance"
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project}"
      Owner       = "${local.owner}"
      ManagedBy   = "terragrunt"
      Purpose     = "compliance"
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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
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
  # Enhanced naming convention for production environment
  name_prefix = "olechka-prod"
  
  # Environment-specific variables
  environment_vars = {
    is_production = true
    is_staging = false
    backup_enabled = true
    monitoring_enabled = true
    auto_scaling_enabled = true
    cost_optimization_enabled = false
    high_availability_enabled = true
    disaster_recovery_enabled = true
    compliance_enabled = true
    security_enabled = true
  }
  
  # Network configuration for production
  network_config = {
    vpc_cidr = "10.3.0.0/16"
    private_subnets = ["10.3.1.0/24", "10.3.2.0/24", "10.3.3.0/24"]
    public_subnets  = ["10.3.101.0/24", "10.3.102.0/24", "10.3.103.0/24"]
    database_subnets = ["10.3.201.0/24", "10.3.202.0/24", "10.3.203.0/24"]
  }
  
  # Security configuration
  security_config = {
    allowed_ssh_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]  # VPN ranges
    encryption_enabled = true
    waf_enabled = true
    inspector_enabled = true
    guardduty_enabled = true
    security_hub_enabled = true
    config_enabled = true
  }
  
  # Monitoring configuration
  monitoring_config = {
    cloudwatch_enabled = true
    xray_enabled = true
    prometheus_enabled = true
    grafana_enabled = true
    alerting_enabled = true
    dashboards_enabled = true
    log_aggregation_enabled = true
  }
  
  # Compliance configuration
  compliance_config = {
    audit_logging_enabled = true
    data_classification_enabled = true
    retention_policies_enabled = true
    access_controls_enabled = true
    encryption_at_rest_enabled = true
    encryption_in_transit_enabled = true
  }
}
EOF
} 