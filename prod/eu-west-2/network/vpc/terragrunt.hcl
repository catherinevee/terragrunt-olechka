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
  name = "olechka-prod-vpc"
  cidr = "10.3.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.3.1.0/24", "10.3.2.0/24", "10.3.3.0/24"]
  public_subnets  = ["10.3.101.0/24", "10.3.102.0/24", "10.3.103.0/24"]
  database_subnets = ["10.3.201.0/24", "10.3.202.0/24", "10.3.203.0/24"]
  elasticache_subnets = ["10.3.211.0/24", "10.3.212.0/24", "10.3.213.0/24"]
  redshift_subnets = ["10.3.221.0/24", "10.3.222.0/24", "10.3.223.0/24"]
  intra_subnets = ["10.3.251.0/24", "10.3.252.0/24", "10.3.253.0/24"]

  # Enterprise NAT Gateway configuration for production (maximum availability)
  enable_nat_gateway = true
  single_nat_gateway = false  # Multiple NATs for maximum availability
  one_nat_gateway_per_az = true

  # DNS and DHCP configuration
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_dhcp_options = true

  # Enhanced VPC Flow Logs for comprehensive monitoring
  enable_flow_log = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role = true
  flow_log_max_aggregation_interval = 60
  flow_log_traffic_type = "ALL"

  # Enterprise security features
  enable_vpn_gateway = true  # VPN for production access
  enable_network_address_usage_metrics = true
  enable_network_acl = true

  # Enhanced subnet configurations
  private_subnet_tags = {
    Tier = "Private"
    Environment = "production"
    AutoShutdown = "false"
    Backup = "required"
    Compliance = "enabled"
  }

  public_subnet_tags = {
    Tier = "Public"
    Environment = "production"
    LoadBalancer = "enabled"
    Compliance = "enabled"
  }

  database_subnet_tags = {
    Tier = "Database"
    Environment = "production"
    Backup = "required"
    Encryption = "required"
    Compliance = "enabled"
  }

  elasticache_subnet_tags = {
    Tier = "ElastiCache"
    Environment = "production"
    Backup = "required"
    Compliance = "enabled"
  }

  redshift_subnets_tags = {
    Tier = "Redshift"
    Environment = "production"
    Backup = "required"
    Compliance = "enabled"
  }

  intra_subnet_tags = {
    Tier = "Intra"
    Environment = "production"
    Purpose = "internal-services"
    Compliance = "enabled"
  }

  # Enhanced DHCP options
  dhcp_options_domain_name = "prod.olechka.internal"
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  # Enhanced tagging
  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "production-ops"
    DataClassification = "restricted"
    AutoShutdown = "false"
    Backup = "required"
    HighAvailability = "enabled"
    NetworkTier = "enterprise"
    Compliance = "enabled"
    DisasterRecovery = "enabled"
    SecurityLevel = "enterprise"
  }
} 