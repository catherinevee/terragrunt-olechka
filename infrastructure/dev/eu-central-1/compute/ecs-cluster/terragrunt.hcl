include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_envcommon/compute.hcl"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.env_vars.locals.environment
  region      = local.region_vars.locals.region
}

terraform {
  source = "tfr:///terraform-aws-modules/ecs/aws?version=5.2.2"
}

inputs = {
  cluster_name = "ai-tools-${local.environment}"

  cluster_settings = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  # Capacity providers
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = local.environment == "production" ? 3 : 1
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = local.environment == "dev" ? 50 : 10
        base   = 0
      }
    }
  }

  # Service discovery namespace
  create_cloudwatch_log_group = true
  cloudwatch_log_group_retention_in_days = local.environment == "production" ? 90 : 30
  cloudwatch_log_group_kms_key_id = local.environment == "production" ? "alias/cloudwatch" : null

  tags = {
    Environment = local.environment
    Type        = "ecs-cluster"
  }
}