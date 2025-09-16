include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_envcommon/network.hcl"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.env_vars.locals.environment
  region      = local.region_vars.locals.region
  azs         = local.region_vars.locals.azs
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.2"
}

inputs = {
  name = "ai-tools-${local.environment}-${local.region}"
  cidr = "10.0.0.0/16"

  azs              = local.azs
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
  elasticache_subnets = ["10.0.211.0/24", "10.0.212.0/24", "10.0.213.0/24"]

  # NAT Gateway configuration based on environment
  enable_nat_gateway     = true
  enable_vpn_gateway     = false
  single_nat_gateway    = local.environment == "dev" ? true : false
  one_nat_gateway_per_az = local.environment == "production" ? true : false

  # Database subnet group
  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  create_database_internet_gateway_route = false
  database_subnet_group_name = "${local.environment}-db-subnet-group"

  # ElastiCache subnet group
  create_elasticache_subnet_group       = true
  create_elasticache_subnet_route_table = true
  elasticache_subnet_group_name = "${local.environment}-cache-subnet-group"

  # Tags
  tags = {
    Environment = local.environment
    Region      = local.region
    Terraform   = "true"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}