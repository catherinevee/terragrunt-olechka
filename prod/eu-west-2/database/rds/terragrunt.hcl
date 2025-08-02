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
  identifier = "olechka-prod-db"

  # Enhanced engine configuration for production
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t3.medium"
  allocated_storage    = 100
  max_allocated_storage = 500  # Higher for production

  db_name  = "olechka_prod_db"
  username = "olechka_prod_admin"
  port     = "5432"

  vpc_security_group_ids = [dependency.security_group.outputs.security_group_id]
  subnet_ids             = dependency.vpc.outputs.database_subnets

  create_db_subnet_group = true

  # Enhanced backup and maintenance configuration for production
  backup_retention_period = 30  # Longer retention for production
  backup_window          = "02:00-03:00"
  maintenance_window     = "sun:03:00-sun:04:00"

  # Production-specific settings
  skip_final_snapshot = false  # Keep final snapshot in production
  deletion_protection = true   # Protect from accidental deletion
  storage_encrypted = true

  # Enhanced monitoring for production environment
  performance_insights_enabled = true
  performance_insights_retention_period = 30
  performance_insights_monitoring_interval = 15

  create_monitoring_role = true
  monitoring_interval    = 15

  # Enhanced parameter group for production
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
      value = "pg_stat_statements,pg_audit,pg_stat_monitor"
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
    },
    {
      name  = "log_replication_commands"
      value = "on"
    },
    {
      name  = "log_parser_stats"
      value = "on"
    },
    {
      name  = "log_planner_stats"
      value = "on"
    },
    {
      name  = "log_executor_stats"
      value = "on"
    }
  ]

  # Enhanced option group for production
  option_group_name = "olechka-prod-option-group"
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
  storage_throughput = 1000
  storage_iops = 6000

  # Enhanced backup configuration
  backup_retention_period = 30
  backup_window = "02:00-03:00"
  maintenance_window = "sun:03:00-sun:04:00"
  copy_tags_to_snapshot = true

  # Enhanced deletion protection
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "olechka-prod-db-final-snapshot"

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
    DatabaseType = "postgresql"
    Monitoring = "enabled"
    HighAvailability = "enabled"
    Encryption = "enabled"
    DeletionProtection = "enabled"
    Compliance = "enabled"
    DisasterRecovery = "enabled"
    SecurityLevel = "enterprise"
  }
} 