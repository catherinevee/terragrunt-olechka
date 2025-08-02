include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = "${get_terragrunt_dir()}/../_envcommon/provider.hcl"
}

include "versions" {
  path = "${get_terragrunt_dir()}/../_envcommon/versions.hcl"
}

dependency "vpc" {
  config_path = "../../network/vpc"
}

dependency "security_group" {
  config_path = "../../network/securitygroup"
}

terraform {
  source = "tfr://terraform-aws-modules/rds/aws//?version=6.6.0"
}

inputs = {
  identifier = "olechka-dev-db"

  # Enhanced engine configuration for dev
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  max_allocated_storage = 50  # Reduced for dev cost optimization

  db_name  = "olechka_dev_db"
  username = "olechka_dev_admin"
  port     = "5432"

  vpc_security_group_ids = [dependency.security_group.outputs.security_group_id]
  subnet_ids             = dependency.vpc.outputs.database_subnets

  create_db_subnet_group = true

  # Enhanced backup and maintenance configuration for dev
  backup_retention_period = 7
  backup_window          = "02:00-03:00"
  maintenance_window     = "sun:03:00-sun:04:00"

  # Dev-specific settings
  skip_final_snapshot = true
  deletion_protection = false  # Allow deletion in dev
  storage_encrypted = true

  # Enhanced monitoring for dev environment
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  performance_insights_monitoring_interval = 60

  create_monitoring_role = true
  monitoring_interval    = 60

  # Enhanced parameter group for dev
  parameters = [
    {
      name  = "log_connections"
      value = "1"
    },
    {
      name  = "log_disconnections"
      value = "1"
    },
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"
    },
    {
      name  = "rds.force_ssl"
      value = "1"
    },
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    }
  ]

  # Enhanced option group for dev
  option_group_name = "olechka-dev-option-group"
  create_db_option_group = true
  option_group_options = [
    {
      option_name = "pgAudit"
      option_settings = [
        {
          name  = "rds.force_ssl"
          value = "1"
        }
      ]
    }
  ]

  # Enhanced CloudWatch logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

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
    DatabaseType = "postgresql"
    Monitoring = "enabled"
  }
} 