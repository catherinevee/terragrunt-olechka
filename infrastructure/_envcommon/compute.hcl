locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment

  # ECS Fargate capacity configuration
  fargate_capacity = {
    dev = {
      cpu_min    = 256
      cpu_max    = 2048
      memory_min = 512
      memory_max = 4096
      min_capacity = 1
      max_capacity = 5
    }
    staging = {
      cpu_min    = 512
      cpu_max    = 4096
      memory_min = 1024
      memory_max = 8192
      min_capacity = 2
      max_capacity = 10
    }
    production = {
      cpu_min    = 1024
      cpu_max    = 8192
      memory_min = 2048
      memory_max = 16384
      min_capacity = 3
      max_capacity = 20
    }
  }

  # Auto-scaling targets
  autoscaling_targets = {
    cpu_target    = local.environment == "production" ? 70 : 75
    memory_target = local.environment == "production" ? 75 : 80
  }
}

inputs = {
  # ECS Configuration
  container_insights = true

  # Logging
  log_retention_in_days = local.environment == "production" ? 90 : 30

  # Service Discovery
  enable_service_discovery = true

  # Deployment Configuration
  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  deployment_configuration = {
    maximum_percent         = 200
    minimum_healthy_percent = local.environment == "production" ? 100 : 50
  }

  # Health Check Configuration
  health_check_grace_period_seconds = 60

  # Task Definition
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"

  # Platform Configuration
  platform_version = "LATEST"

  # Capacity Provider Strategy
  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight           = 1
      base             = local.environment == "production" ? 3 : 1
    },
    {
      capacity_provider = "FARGATE_SPOT"
      weight           = local.environment == "dev" ? 4 : 1
      base             = 0
    }
  ]
}