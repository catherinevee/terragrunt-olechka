include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_envcommon/storage.hcl"
}

dependency "vpc" {
  config_path = "../../network/vpc"

  mock_outputs = {
    vpc_id                = "vpc-mock"
    database_subnets      = ["subnet-mock-1", "subnet-mock-2"]
    database_subnet_group = "db-subnet-group-mock"
  }
}

dependency "kms" {
  config_path = "../../security/kms"

  mock_outputs = {
    key_arn = "arn:aws:kms:eu-central-1:123456789012:key/mock"
  }
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
  source = "tfr:///terraform-aws-modules/rds-aurora/aws?version=8.3.1"
}

inputs = {
  name           = "ai-tools-aurora-${local.environment}"
  engine         = "aurora-postgresql"
  engine_version = "15.4"
  engine_mode    = "provisioned"

  vpc_id               = dependency.vpc.outputs.vpc_id
  db_subnet_group_name = dependency.vpc.outputs.database_subnet_group
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = [dependency.vpc.outputs.vpc_cidr_block]
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Allow PostgreSQL traffic from VPC"
    }
  }

  master_username = "aitools_admin"
  database_name   = "aitools"

  # Instance configuration
  instance_class = local.environment == "production" ? "db.r6g.xlarge" : "db.t3.medium"
  instances = {
    1 = {
      instance_class          = local.environment == "production" ? "db.r6g.xlarge" : "db.t3.medium"
      publicly_accessible     = false
      db_parameter_group_name = "default.aurora-postgresql15"
      promotion_tier          = 1
    }
  }

  # Add read replicas for production
  replica_count = local.environment == "production" ? 2 : 0
  replica_scale_enabled = local.environment == "production"
  replica_scale_min     = local.environment == "production" ? 1 : 0
  replica_scale_max     = local.environment == "production" ? 4 : 0

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration = local.environment != "dev" ? {
    min_capacity = local.environment == "production" ? 2 : 0.5
    max_capacity = local.environment == "production" ? 8 : 2
  } : null

  # Storage encryption
  storage_encrypted = true
  kms_key_id       = dependency.kms.outputs.key_arn

  # Backup configuration
  backup_retention_period         = local.environment == "production" ? 30 : 7
  preferred_backup_window         = "03:00-04:00"
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  enabled_cloudwatch_logs_exports = ["postgresql"]
  skip_final_snapshot            = local.environment == "dev"
  deletion_protection            = local.environment == "production"

  # Performance Insights
  performance_insights_enabled          = local.environment != "dev"
  performance_insights_retention_period = local.environment == "production" ? 731 : 7
  performance_insights_kms_key_id      = local.environment != "dev" ? dependency.kms.outputs.key_arn : null

  # Enhanced monitoring
  create_monitoring_role          = true
  monitoring_interval            = local.environment == "production" ? 30 : 60
  monitoring_role_name          = "aurora-monitoring-${local.environment}"
  monitoring_role_description   = "IAM role for Aurora monitoring"

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = true

  # Parameter groups
  db_cluster_parameter_group_name = "default.aurora-postgresql15"
  db_parameter_group_name         = "default.aurora-postgresql15"

  tags = {
    Environment = local.environment
    Type        = "aurora-postgresql"
    Service     = "database"
  }
}