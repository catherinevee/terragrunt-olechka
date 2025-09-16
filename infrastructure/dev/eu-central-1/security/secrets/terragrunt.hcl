include "root" {
  path = find_in_parent_folders()
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    key_arn = "arn:aws:kms:eu-central-1:123456789012:key/mock"
  }
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.env_vars.locals.environment
  region      = local.region_vars.locals.region
}

terraform {
  source = "tfr:///terraform-aws-modules/secrets-manager/aws?version=1.1.1"
}

inputs = {
  # Database credentials
  secrets = {
    database-url = {
      name        = "ai-tools-${local.environment}-database-url"
      description = "Database connection string for ${local.environment}"

      kms_key_id = dependency.kms.outputs.key_arn

      recovery_window_in_days = local.environment == "production" ? 30 : 7

      secret_string = jsonencode({
        engine   = "postgresql"
        host     = "placeholder.cluster-ro.amazonaws.com"
        port     = 5432
        database = "aitools"
        username = "aitools_admin"
        password = "CHANGEME"
      })

      rotation_enabled = local.environment == "production"
      rotation_lambda_arn = local.environment == "production" ?
        "arn:aws:lambda:${local.region}:${local.account_id}:function:SecretsManagerRotation" : null
      rotation_rules = local.environment == "production" ? {
        automatically_after_days = 30
      } : null
    }

    api-key = {
      name        = "ai-tools-${local.environment}-api-key"
      description = "API key for external services"

      kms_key_id = dependency.kms.outputs.key_arn

      recovery_window_in_days = local.environment == "production" ? 30 : 7

      secret_string = jsonencode({
        api_key    = "CHANGEME"
        api_secret = "CHANGEME"
      })
    }

    jwt-secret = {
      name        = "ai-tools-${local.environment}-jwt-secret"
      description = "JWT signing secret"

      kms_key_id = dependency.kms.outputs.key_arn

      recovery_window_in_days = local.environment == "production" ? 30 : 7

      random_password = {
        length  = 64
        special = true
      }

      rotation_enabled = local.environment == "production"
      rotation_lambda_arn = local.environment == "production" ?
        "arn:aws:lambda:${local.region}:${local.account_id}:function:SecretsManagerRotation" : null
      rotation_rules = local.environment == "production" ? {
        automatically_after_days = 90
      } : null
    }

    encryption-key = {
      name        = "ai-tools-${local.environment}-encryption-key"
      description = "Application encryption key"

      kms_key_id = dependency.kms.outputs.key_arn

      recovery_window_in_days = local.environment == "production" ? 30 : 7

      random_password = {
        length  = 32
        special = false
      }
    }
  }

  # Replica configuration for production
  replica = local.environment == "production" ? {
    kms_key_id = dependency.kms.outputs.key_arn
    region     = "ap-southeast-1"
  } : null

  tags = {
    Environment = local.environment
    Service     = "secrets-manager"
    Type        = "credentials"
  }
}