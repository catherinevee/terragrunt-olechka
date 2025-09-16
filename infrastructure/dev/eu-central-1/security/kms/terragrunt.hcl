include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  environment = local.env_vars.locals.environment
  region      = local.region_vars.locals.region
  account_id  = local.account_vars.locals.account_id
}

terraform {
  source = "tfr:///terraform-aws-modules/kms/aws?version=2.0.1"
}

inputs = {
  description = "KMS key for AI Tools ${local.environment} environment"

  # Key configuration
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = local.environment == "production" ? 30 : 7
  is_enabled              = true
  enable_key_rotation     = true
  multi_region            = local.environment == "production"

  # Key policy
  enable_default_policy = true
  key_owners           = ["arn:aws:iam::${local.account_id}:root"]
  key_administrators   = ["arn:aws:iam::${local.account_id}:role/terraform-admin"]

  key_users = [
    "arn:aws:iam::${local.account_id}:role/ecs-task-execution-role",
    "arn:aws:iam::${local.account_id}:role/aurora-role"
  ]

  key_service_users = [
    "arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  ]

  # Aliases
  aliases = [
    "ai-tools-${local.environment}",
    "ai-tools-${local.environment}-${local.region}"
  ]

  # Grants for services
  grants = {
    lambda = {
      grantee_principal = "arn:aws:iam::${local.account_id}:role/lambda-role"
      operations = [
        "Encrypt",
        "Decrypt",
        "GenerateDataKey"
      ]
    }
    rds = {
      grantee_principal = "arn:aws:iam::${local.account_id}:role/rds-monitoring-role"
      operations = [
        "Encrypt",
        "Decrypt",
        "DescribeKey",
        "CreateGrant",
        "RetireGrant"
      ]
    }
  }

  tags = {
    Environment = local.environment
    Service     = "kms"
    Type        = "encryption"
  }
}