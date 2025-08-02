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

terraform {
  source = "tfr://terraform-aws-modules/security-group/aws//?version=5.1.2"
}

inputs = {
  name        = "olechka-dev-app-sg"
  description = "Enhanced security group for development application servers"
  vpc_id      = dependency.vpc.outputs.vpc_id

  # Enhanced ingress rules for dev environment
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH access from anywhere (dev environment)"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP access"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS access"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Application port"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "Node.js development server"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL database access"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      description = "Redis cache access"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      description = "Prometheus metrics endpoint"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    }
  ]

  # Enhanced egress rules
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "All outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  # Enhanced security group rules for internal communication
  ingress_with_source_security_group_id = [
    {
      from_port                = 0
      to_port                  = 0
      protocol                 = "-1"
      description              = "Internal communication within VPC"
      source_security_group_id = dependency.vpc.outputs.default_security_group_id
    }
  ]

  # Enhanced tagging
  tags = {
    Environment = "development"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "dev-ops"
    DataClassification = "internal"
    AutoShutdown = "true"
    SecurityLevel = "medium"
  }
} 