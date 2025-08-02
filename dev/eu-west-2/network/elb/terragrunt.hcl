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
  config_path = "../vpc"
}

dependency "security_group" {
  config_path = "../securitygroup"
}

terraform {
  source = "tfr://terraform-aws-modules/alb/aws//?version=9.9.2"
}

inputs = {
  name = "olechka-dev-alb"
  load_balancer_type = "application"

  vpc_id  = dependency.vpc.outputs.vpc_id
  subnets = dependency.vpc.outputs.public_subnets

  # Enhanced security groups
  security_groups = [dependency.security_group.outputs.security_group_id]

  # Enhanced access logs
  access_logs = {
    bucket = "olechka-dev-logs-2024"
    prefix = "alb-logs"
  }

  # Enhanced target groups
  target_groups = [
    {
      name_prefix      = "app-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      }
    },
    {
      name_prefix      = "api-"
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_type      = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/api/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  ]

  # Enhanced listeners
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
      action_type        = "forward"
    }
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = "arn:aws:acm:eu-west-2:123456789012:certificate/your-certificate-id"
      target_group_index = 0
      action_type        = "forward"
    }
  ]

  # Enhanced listener rules
  https_listener_rules = [
    {
      https_listener_index = 0
      priority             = 1
      actions = [
        {
          type               = "forward"
          target_group_index = 1
        }
      ]
      conditions = [
        {
          path_patterns = ["/api/*"]
        }
      ]
    },
    {
      https_listener_index = 0
      priority             = 2
      actions = [
        {
          type = "fixed-response"
          fixed_response = {
            content_type = "text/plain"
            message_body = "Not Found"
            status_code  = "404"
          }
        }
      ]
      conditions = [
        {
          path_patterns = ["/*"]
        }
      ]
    }
  ]

  # Enhanced attributes
  load_balancer_attributes = [
    {
      name  = "idle_timeout.timeout_seconds"
      value = "60"
    },
    {
      name  = "deletion_protection.enabled"
      value = "false"  # Allow deletion in dev
    },
    {
      name  = "access_logs.s3.enabled"
      value = "true"
    },
    {
      name  = "access_logs.s3.bucket"
      value = "olechka-dev-logs-2024"
    },
    {
      name  = "access_logs.s3.prefix"
      value = "alb-logs"
    }
  ]

  # Enhanced tags
  tags = {
    Environment = "development"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "dev-ops"
    DataClassification = "internal"
    AutoShutdown = "true"
    LoadBalancerType = "application"
    AccessLogs = "enabled"
    SSL = "enabled"
  }
} 