locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment

  # CloudWatch Alarms configuration
  alarm_thresholds = {
    dev = {
      cpu_high           = 85
      memory_high        = 85
      error_rate_high    = 10
      latency_p99        = 2000
      db_cpu_high        = 80
      db_connections_high = 80
    }
    staging = {
      cpu_high           = 80
      memory_high        = 80
      error_rate_high    = 5
      latency_p99        = 1500
      db_cpu_high        = 75
      db_connections_high = 75
    }
    production = {
      cpu_high           = 75
      memory_high        = 75
      error_rate_high    = 2
      latency_p99        = 1000
      db_cpu_high        = 70
      db_connections_high = 70
    }
  }

  # X-Ray configuration
  xray_config = {
    sampling_rate = local.environment == "production" ? 0.1 : 0.5
    daemon_cpu    = local.environment == "production" ? 256 : 128
    daemon_memory = local.environment == "production" ? 512 : 256
  }
}

inputs = {
  # CloudWatch Log Groups
  log_group_retention_in_days = local.environment == "production" ? 90 : 30
  log_group_kms_key_id        = local.environment == "production" ? "alias/cloudwatch" : null

  # CloudWatch Dashboard
  create_dashboard = true

  # Metrics Collection
  detailed_monitoring = local.environment != "dev"

  # Alarm Actions
  alarm_actions = local.environment == "production" ? ["arn:aws:sns:${local.region}:${local.account_id}:alerts-critical"] : []
  ok_actions    = local.environment == "production" ? ["arn:aws:sns:${local.region}:${local.account_id}:alerts-resolved"] : []

  # Evaluation Periods
  evaluation_periods = local.environment == "production" ? 2 : 1
  datapoints_to_alarm = local.environment == "production" ? 2 : 1

  # X-Ray Tracing
  enable_xray_tracing = true

  # Container Insights
  enable_container_insights = true

  # CloudWatch Logs Insights
  enable_logs_insights = local.environment != "dev"

  # Custom Metrics Namespace
  metrics_namespace = "AI-Tools/${local.environment}"

  # Log Filters for Error Detection
  log_filters = [
    {
      name           = "error-filter"
      pattern        = "[ERROR]"
      metric_name    = "ErrorCount"
      metric_namespace = "AI-Tools/${local.environment}"
      metric_value   = "1"
    },
    {
      name           = "warning-filter"
      pattern        = "[WARN]"
      metric_name    = "WarningCount"
      metric_namespace = "AI-Tools/${local.environment}"
      metric_value   = "1"
    }
  ]

  # Synthetics Canaries (production only)
  enable_synthetics = local.environment == "production"
  synthetics_schedule = local.environment == "production" ? "rate(5 minutes)" : "rate(30 minutes)"

  # Enhanced Monitoring
  enhanced_monitoring_interval = local.environment == "production" ? 30 : 60
}