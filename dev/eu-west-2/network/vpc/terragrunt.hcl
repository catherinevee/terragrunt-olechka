include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = "${get_terragrunt_dir()}/../_envcommon/provider.hcl"
}

include "versions" {
  path = "${get_terragrunt_dir()}/../_envcommon/versions.hcl"
}

terraform {
  source = "tfr://terraform-aws-modules/vpc/aws//?version=5.8.1"
}

inputs = {
  name = "olechka-dev-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
  database_subnets = ["10.1.201.0/24", "10.1.202.0/24", "10.1.203.0/24"]
  elasticache_subnets = ["10.1.211.0/24", "10.1.212.0/24", "10.1.213.0/24"]
  redshift_subnets = ["10.1.221.0/24", "10.1.222.0/24", "10.1.223.0/24"]

  # Enhanced NAT Gateway configuration for dev
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization for dev
  one_nat_gateway_per_az = false

  # DNS and DHCP configuration
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_dhcp_options = true

  # VPC Flow Logs for monitoring
  enable_flow_log = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role = true
  flow_log_max_aggregation_interval = 60

  # Enhanced security features
  enable_vpn_gateway = false  # Not needed for dev
  enable_network_address_usage_metrics = true

  # Subnet configurations
  private_subnet_tags = {
    Tier = "Private"
    Environment = "development"
    AutoShutdown = "true"
  }

  public_subnet_tags = {
    Tier = "Public"
    Environment = "development"
  }

  database_subnet_tags = {
    Tier = "Database"
    Environment = "development"
  }

  elasticache_subnet_tags = {
    Tier = "ElastiCache"
    Environment = "development"
  }

  redshift_subnet_tags = {
    Tier = "Redshift"
    Environment = "development"
  }

  # Enhanced tagging
  tags = {
    Environment = "development"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "dev-ops"
    DataClassification = "internal"
    AutoShutdown = "true"
    Backup = "true"
  }
} 