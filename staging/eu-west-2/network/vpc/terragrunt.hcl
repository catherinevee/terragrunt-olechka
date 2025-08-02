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
  name = "olechka-staging-vpc"
  cidr = "10.2.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  public_subnets  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
  database_subnets = ["10.2.201.0/24", "10.2.202.0/24", "10.2.203.0/24"]
  elasticache_subnets = ["10.2.211.0/24", "10.2.212.0/24", "10.2.213.0/24"]
  redshift_subnets = ["10.2.221.0/24", "10.2.222.0/24", "10.2.223.0/24"]
  intra_subnets = ["10.2.251.0/24", "10.2.252.0/24", "10.2.253.0/24"]

  # Enhanced NAT Gateway configuration for staging (high availability)
  enable_nat_gateway = true
  single_nat_gateway = false  # Multiple NATs for high availability
  one_nat_gateway_per_az = true

  # DNS and DHCP configuration
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_dhcp_options = true

  # Enhanced VPC Flow Logs for monitoring
  enable_flow_log = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role = true
  flow_log_max_aggregation_interval = 60
  flow_log_traffic_type = "ALL"

  # Enhanced security features
  enable_vpn_gateway = true  # VPN for staging access
  enable_network_address_usage_metrics = true
  
  # Security and compliance enhancements
  manage_default_security_group = true
  default_security_group_ingress = []
  default_security_group_egress = []
  
  # VPC Flow log enhancements
  flow_log_cloudwatch_log_group_kms_key_id = dependency.kms.outputs.key_arn
  flow_log_destination_type = "cloud-watch-logs"
  flow_log_log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id}"
  
  # Enhanced Network ACL rules
  manage_default_network_acl = true
  default_network_acl_ingress = [
    {
      rule_no    = 100
      action     = "deny"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    }
  ]
  default_network_acl_egress = [
    {
      rule_no    = 100
      action     = "allow"
      from_port  = 0
      to_port    = 0
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
    }
  ]

  # Enhanced subnet configurations
  private_subnet_tags = {
    Tier = "Private"
    Environment = "staging"
    AutoShutdown = "false"
    Backup = "required"
  }

  public_subnet_tags = {
    Tier = "Public"
    Environment = "staging"
    LoadBalancer = "enabled"
  }

  database_subnet_tags = {
    Tier = "Database"
    Environment = "staging"
    Backup = "required"
    Encryption = "required"
  }

  elasticache_subnet_tags = {
    Tier = "ElastiCache"
    Environment = "staging"
    Backup = "required"
  }

  redshift_subnets_tags = {
    Tier = "Redshift"
    Environment = "staging"
    Backup = "required"
  }

  intra_subnet_tags = {
    Tier = "Intra"
    Environment = "staging"
    Purpose = "internal-services"
  }

  # Enhanced DHCP options
  dhcp_options_domain_name = "staging.olechka.internal"
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  # Enhanced tagging
  tags = {
    Environment = "staging"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "staging-ops"
    DataClassification = "confidential"
    AutoShutdown = "false"
    Backup = "required"
    HighAvailability = "enabled"
    NetworkTier = "enterprise"
  }
} 