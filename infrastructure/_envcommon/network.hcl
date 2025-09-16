locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment

  # CIDR blocks per environment
  cidr_blocks = {
    dev = {
      "eu-central-1"    = "10.0.0.0/16"
      "ap-southeast-1"  = "10.1.0.0/16"
    }
    staging = {
      "eu-central-1"    = "10.10.0.0/16"
      "ap-southeast-1"  = "10.11.0.0/16"
    }
    production = {
      "eu-central-1"    = "10.20.0.0/16"
      "ap-southeast-1"  = "10.21.0.0/16"
    }
  }

  # NAT Gateway configuration per environment
  nat_gateway_config = {
    dev        = { single_nat = true, one_nat_per_az = false }
    staging    = { single_nat = false, one_nat_per_az = true }
    production = { single_nat = false, one_nat_per_az = true }
  }
}

inputs = {
  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_retention_in_days          = local.environment == "production" ? 90 : 30

  # DNS Support
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_ipv6         = true

  # VPC Endpoints for cost optimization
  enable_s3_endpoint              = true
  enable_dynamodb_endpoint        = true
  enable_secretsmanager_endpoint  = true
  enable_kms_endpoint            = true
  enable_ecs_endpoint            = true
  enable_ecs_agent_endpoint      = true
  enable_ecs_telemetry_endpoint  = true
  enable_ecr_api_endpoint        = true
  enable_ecr_dkr_endpoint        = true
  enable_logs_endpoint           = true
  enable_sns_endpoint            = true
  enable_sqs_endpoint            = true
  enable_ssm_endpoint            = true
  enable_ssmmessages_endpoint    = true
  enable_ec2_endpoint            = true
  enable_ec2messages_endpoint    = true
  enable_elasticloadbalancing_endpoint = true

  # Network ACLs
  manage_default_network_acl = true
  default_network_acl_tags = {
    Name = "${local.environment}-default-nacl"
  }

  # Security Groups
  manage_default_security_group = true
  default_security_group_tags = {
    Name = "${local.environment}-default-sg"
  }
}