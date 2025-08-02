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
  name        = "olechka-prod-app-sg"
  description = "Enterprise security group for production application servers"
  vpc_id      = dependency.vpc.outputs.vpc_id

  # Enhanced ingress rules for production environment
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH access from VPN ranges"
      cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP access from load balancer"
      cidr_blocks = dependency.vpc.outputs.public_subnets_cidr_blocks
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS access from load balancer"
      cidr_blocks = dependency.vpc.outputs.public_subnets_cidr_blocks
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Application port"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "Node.js application server"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL database access"
      cidr_blocks = dependency.vpc.outputs.database_subnets_cidr_blocks
    },
    {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      description = "Redis cache access"
      cidr_blocks = dependency.vpc.outputs.elasticache_subnets_cidr_blocks
    },
    {
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      description = "Prometheus metrics endpoint"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 9100
      to_port     = 9100
      protocol    = "tcp"
      description = "Node Exporter metrics"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 3001
      to_port     = 3001
      protocol    = "tcp"
      description = "Grafana dashboard"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 8086
      to_port     = 8086
      protocol    = "tcp"
      description = "InfluxDB time series database"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 8500
      to_port     = 8500
      protocol    = "tcp"
      description = "Consul service discovery"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      description = "Vault secrets management"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    },
    {
      from_port   = 9411
      to_port     = 9411
      protocol    = "tcp"
      description = "Zipkin distributed tracing"
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
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "production-ops"
    DataClassification = "restricted"
    AutoShutdown = "false"
    SecurityLevel = "enterprise"
    Backup = "required"
    HighAvailability = "enabled"
    Compliance = "enabled"
    DisasterRecovery = "enabled"
  }
} 