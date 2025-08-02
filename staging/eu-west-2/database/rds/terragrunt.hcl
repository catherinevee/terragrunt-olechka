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
  identifier = "olechka-staging-db"

  # Enhanced engine configuration for staging
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t3.small"
  allocated_storage    = 50
  max_allocated_storage = 200  # Higher for staging

  db_name  = "olechka_staging_db"
  username = "olechka_staging_admin"
  port     = "5432"

  vpc_security_group_ids = [dependency.security_group.outputs.security_group_id]
  subnet_ids             = dependency.vpc.outputs.database_subnets

  create_db_subnet_group = true

  # Enhanced backup and maintenance configuration for staging
  backup_retention_period = 14  # Longer retention for staging
  backup_window          = "02:00-03:00"
  maintenance_window     = "sun:03:00-sun:04:00"

  # Staging-specific settings
  skip_final_snapshot = false  # Keep final snapshot in staging
  deletion_protection = true   # Protect from accidental deletion
  storage_encrypted = true

  # Enhanced monitoring for staging environment
  performance_insights_enabled = true
  performance_insights_retention_period = 14
  performance_insights_monitoring_interval = 30

  create_monitoring_role = true
  monitoring_interval    = 30

  # Enhanced parameter group for staging
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
      value = "pg_stat_statements,pg_audit"
    },
    {
      name  = "pg_stat_statements.track"
      value = "all"
    },
    {
      name  = "pg_stat_statements.max"
      value = "10000"
    },
    {
      name  = "pg_stat_statements.track_utility"
      value = "on"
    },
    {
      name  = "log_checkpoints"
      value = "on"
    },
    {
      name  = "log_lock_waits"
      value = "on"
    },
    {
      name  = "log_temp_files"
      value = "0"
    },
    {
      name  = "log_autovacuum_min_duration"
      value = "0"
    }
  ]

  # Enhanced option group for staging
  option_group_name = "olechka-staging-option-group"
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

  # Enhanced storage configuration
  storage_type = "gp3"
  storage_encrypted = true
  storage_throughput = 500
  storage_iops = 3000

  # Enhanced backup configuration
  backup_retention_period = 14
  backup_window = "02:00-03:00"
  maintenance_window = "sun:03:00-sun:04:00"
  copy_tags_to_snapshot = true

  # Enhanced deletion protection
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "olechka-staging-db-final-snapshot"

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
    DatabaseType = "postgresql"
    Monitoring = "enabled"
    HighAvailability = "enabled"
    Encryption = "enabled"
    DeletionProtection = "enabled"
  }
} 