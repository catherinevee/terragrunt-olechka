include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_envcommon/compute.hcl"
}

dependency "vpc" {
  config_path = "../../network/vpc"

  mock_outputs = {
    vpc_id = "vpc-mock"
    private_subnets = ["subnet-mock-1", "subnet-mock-2"]
  }
}

dependency "ecs_cluster" {
  config_path = "../ecs-cluster"

  mock_outputs = {
    cluster_arn = "arn:aws:ecs:eu-central-1:123456789012:cluster/mock"
    cluster_id  = "mock-cluster"
  }
}

dependency "alb" {
  config_path = "../../network/alb"

  mock_outputs = {
    target_group_arns = ["arn:aws:elasticloadbalancing:eu-central-1:123456789012:targetgroup/mock/mock"]
    security_group_id = "sg-mock"
  }
}

dependency "secrets" {
  config_path = "../../security/secrets"

  mock_outputs = {
    database_url_arn = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:mock"
    api_key_arn      = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:mock"
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
  source = "tfr:///terraform-aws-modules/ecs/aws//modules/service?version=5.2.2"
}

inputs = {
  name        = "ai-tools-api"
  cluster_arn = dependency.ecs_cluster.outputs.cluster_arn

  cpu    = local.environment == "production" ? 2048 : 512
  memory = local.environment == "production" ? 4096 : 1024

  container_definitions = {
    api = {
      essential = true
      image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/ai-tools-api:latest"

      port_mappings = [
        {
          name          = "api"
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = local.environment
        },
        {
          name  = "REGION"
          value = local.region
        },
        {
          name  = "LOG_LEVEL"
          value = local.environment == "production" ? "INFO" : "DEBUG"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = dependency.secrets.outputs.database_url_arn
        },
        {
          name      = "API_KEY"
          valueFrom = dependency.secrets.outputs.api_key_arn
        }
      ]

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/ai-tools-api"
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }

      # Resource limits
      ulimits = [
        {
          name      = "nofile"
          softLimit = 65536
          hardLimit = 65536
        }
      ]

      # X-Ray sidecar configuration
      dependsOn = [
        {
          containerName = "xray-daemon"
          condition     = "START"
        }
      ]
    }

    xray-daemon = {
      essential = false
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"

      port_mappings = [
        {
          name          = "xray"
          containerPort = 2000
          protocol      = "udp"
        }
      ]

      cpu    = 32
      memory = 256

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/ai-tools-api"
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  }

  load_balancer = {
    service = {
      target_group_arn = dependency.alb.outputs.target_group_arns[0]
      container_name   = "api"
      container_port   = 8080
    }
  }

  subnet_ids = dependency.vpc.outputs.private_subnets

  security_group_rules = {
    alb_ingress = {
      type                     = "ingress"
      from_port               = 8080
      to_port                 = 8080
      protocol                = "tcp"
      source_security_group_id = dependency.alb.outputs.security_group_id
      description             = "Allow traffic from ALB"
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  }

  # Service discovery
  enable_service_discovery = true
  service_discovery_namespace_id = dependency.ecs_cluster.outputs.service_discovery_namespace_id

  # Auto-scaling
  enable_autoscaling = true
  autoscaling_min_capacity = local.environment == "production" ? 3 : 1
  autoscaling_max_capacity = local.environment == "production" ? 20 : 5

  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value = local.environment == "production" ? 70 : 75
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value = local.environment == "production" ? 75 : 80
      }
    }
  }

  # Task execution role policies
  task_exec_role_policies = {
    SecretsManager = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
    CloudWatchLogs = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
    ECRRead        = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    XRay           = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  }

  tags = {
    Environment = local.environment
    Service     = "api"
    Type        = "fargate"
  }
}