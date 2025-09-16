locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment

  # Aurora configuration
  aurora_config = {
    dev = {
      engine_version     = "15.4"
      instance_class     = "db.t3.medium"
      min_capacity       = 0.5
      max_capacity       = 1
      backup_retention   = 7
      deletion_protection = false
    }
    staging = {
      engine_version     = "15.4"
      instance_class     = "db.r6g.large"
      min_capacity       = 1
      max_capacity       = 4
      backup_retention   = 14
      deletion_protection = false
    }
    production = {
      engine_version     = "15.4"
      instance_class     = "db.r6g.xlarge"
      min_capacity       = 2
      max_capacity       = 8
      backup_retention   = 30
      deletion_protection = true
    }
  }

  # S3 lifecycle configuration
  s3_lifecycle_rules = {
    transition_to_ia_days      = local.environment == "production" ? 90 : 30
    transition_to_glacier_days = local.environment == "production" ? 180 : 90
    expiration_days           = local.environment == "production" ? 2555 : 365
  }
}

inputs = {
  # S3 Common Configuration
  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "aws:kms"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # S3 Logging
  logging = {
    target_bucket = "logs"
    target_prefix = "s3-access-logs/"
  }

  # S3 Replication (production only)
  replication_configuration = local.environment == "production" ? {
    role = "arn:aws:iam::${local.account_id}:role/s3-replication-role"
    rules = [{
      id       = "replicate-to-secondary-region"
      status   = "Enabled"
      priority = 1

      destination = {
        bucket        = "arn:aws:s3:::backup-bucket-secondary-region"
        storage_class = "STANDARD_IA"
      }
    }]
  } : null

  # Aurora Common Configuration
  engine              = "aurora-postgresql"
  engine_mode         = "provisioned"
  database_name       = "aitools"
  master_username     = "admin"
  storage_encrypted   = true

  # Backup Configuration
  backup_window      = "03:00-04:00"
  maintenance_window = "sun:04:00-sun:05:00"

  # Performance Insights
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled     = local.environment != "dev"
  performance_insights_retention_period = local.environment == "production" ? 731 : 7

  # Auto-scaling Configuration
  auto_scaling_enabled = true
  auto_scaling_target_cpu = 70
  auto_scaling_target_connections = 70

  # ElastiCache Configuration
  elasticache_node_type = local.environment == "production" ? "cache.r6g.xlarge" : "cache.t3.micro"
  elasticache_num_cache_clusters = local.environment == "production" ? 3 : 1
  elasticache_automatic_failover_enabled = local.environment != "dev"
  elasticache_multi_az_enabled = local.environment != "dev"

  # ElastiCache Security
  elasticache_at_rest_encryption_enabled = true
  elasticache_transit_encryption_enabled = true
  elasticache_auth_token_enabled = local.environment == "production"
}