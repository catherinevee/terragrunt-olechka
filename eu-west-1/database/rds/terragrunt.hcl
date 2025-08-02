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
  identifier = "olechka-db"

  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  max_allocated_storage = 100

  db_name  = "olechkadb"
  username = "olechka_admin"
  port     = "5432"

  vpc_security_group_ids = [dependency.security_group.outputs.security_group_id]
  subnet_ids             = dependency.vpc.outputs.private_subnets

  create_db_subnet_group = true

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  performance_insights_enabled = true
  performance_insights_retention_period = 7

  create_monitoring_role = true
  monitoring_interval    = 60

  parameters = [
    {
      name  = "log_connections"
      value = "1"
    },
    {
      name  = "log_disconnections"
      value = "1"
    }
  ]

  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
  }
} 