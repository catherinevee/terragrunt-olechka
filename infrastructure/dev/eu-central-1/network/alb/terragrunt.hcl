include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-mock"
    public_subnets  = ["subnet-mock-1", "subnet-mock-2"]
    vpc_cidr_block  = "10.0.0.0/16"
  }
}

dependency "security_groups" {
  config_path = "../security-groups"

  mock_outputs = {
    security_group_id = "sg-mock"
  }
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.env_vars.locals.environment
  region      = local.region_vars.locals.region
}

terraform {
  source = "tfr:///terraform-aws-modules/alb/aws?version=8.7.0"
}

inputs = {
  name = "ai-tools-alb-${local.environment}"

  load_balancer_type = "application"
  vpc_id            = dependency.vpc.outputs.vpc_id
  subnets           = dependency.vpc.outputs.public_subnets
  security_groups   = [dependency.security_groups.outputs.security_group_id]

  # Access logs
  access_logs = {
    enabled = local.environment == "production"
    bucket  = "ai-tools-alb-logs-${local.environment}"
    prefix  = "alb"
  }

  # Target groups
  target_groups = [
    {
      name             = "api-tg-${local.environment}"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"

      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }

      deregistration_delay = local.environment == "production" ? 300 : 10

      stickiness = {
        enabled         = true
        type           = "app_cookie"
        cookie_name    = "AWSALBAPP"
        cookie_duration = 86400
      }
    },
    {
      name             = "worker-tg-${local.environment}"
      backend_protocol = "HTTP"
      backend_port     = 8081
      target_type      = "ip"

      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }

      deregistration_delay = local.environment == "production" ? 300 : 10
    }
  ]

  # HTTP Listener
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      action_type        = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  # HTTPS Listener (requires ACM certificate)
  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = "arn:aws:acm:${local.region}:${local.account_id}:certificate/placeholder" # Replace with actual certificate
      action_type        = "fixed-response"

      fixed_response = {
        content_type = "text/plain"
        message_body = "Service Healthy"
        status_code  = "200"
      }
    }
  ]

  # Listener rules
  https_listener_rules = [
    {
      https_listener_index = 0
      priority            = 100

      actions = [{
        type               = "forward"
        target_group_index = 0
      }]

      conditions = [{
        path_patterns = ["/api/*", "/v1/*"]
      }]
    },
    {
      https_listener_index = 0
      priority            = 200

      actions = [{
        type               = "forward"
        target_group_index = 1
      }]

      conditions = [{
        path_patterns = ["/worker/*", "/jobs/*"]
      }]
    }
  ]

  # Enable deletion protection for production
  enable_deletion_protection = local.environment == "production"
  enable_http2              = true
  enable_cross_zone_load_balancing = true
  idle_timeout              = 60

  tags = {
    Environment = local.environment
    Type        = "application"
  }
}