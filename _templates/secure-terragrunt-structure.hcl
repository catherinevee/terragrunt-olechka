# Secure Terragrunt Configuration Structure Template
# Use this as a reference for implementing secure Terragrunt patterns

# =============================================================================
# ROOT CONFIGURATION (terragrunt.hcl)
# =============================================================================

locals {
  # Read common variables with validation
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  
  # Environment detection with fallback
  environment = get_env("TG_ENVIRONMENT", "development")
  region      = get_env("AWS_DEFAULT_REGION", "eu-west-1")
  
  # Extract and validate common values
  project        = local.common_vars.locals.project
  owner          = local.common_vars.locals.owner
  aws_account_id = get_env("AWS_ACCOUNT_ID", run_cmd("aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text"))
  
  # Validation
  _validate_account_id = regex("^[0-9]{12}$", local.aws_account_id)
}

# Enhanced remote state with comprehensive security
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    # Dynamic bucket naming with environment isolation
    bucket         = "terragrunt-state-${local.aws_account_id}-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    
    # Encryption configuration
    encrypt    = true
    kms_key_id = "arn:aws:kms:${local.region}:${local.aws_account_id}:alias/terragrunt-state-key-${local.environment}"
    
    # State locking
    dynamodb_table = "terragrunt-state-locks-${local.aws_account_id}-${local.environment}"
    
    # CRITICAL: Security flags (all must be false for security)
    skip_bucket_ssencryption           = false
    skip_bucket_enforced_tls           = false
    skip_bucket_public_access_blocking = false
    skip_bucket_root_access            = false
    skip_bucket_versioning             = false
    skip_bucket_accesslogging          = false
    
    # Access logging configuration
    accesslogging_bucket_name   = "terragrunt-access-logs-${local.aws_account_id}"
    accesslogging_target_prefix = "state-access-logs/${local.environment}/"
    
    # Enhanced bucket configuration
    s3_bucket_tags = {
      Purpose            = "terraform-state"
      Environment        = local.environment
      Project            = local.project
      DataClassification = local.environment == "prod" ? "restricted" : "confidential"
      BackupRequired     = "true"
      SecurityLevel      = "maximum"
      ComplianceRequired = "true"
      ManagedBy          = "terragrunt"
      Owner              = local.owner
    }
  }
}

# Secure provider generation with assume role
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = "~> 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
    }
  }
}

provider "aws" {
  region = "${local.region}"
  
  # Secure assume role configuration
  assume_role {
    role_arn     = "arn:aws:iam::${local.aws_account_id}:role/terragrunt-${local.environment}-role"
    session_name = "terragrunt-${local.environment}-session"
    # Add MFA requirement for production
    %{if local.environment == "prod"}
    external_id = "$${var.external_id}"
    %{endif}
  }
  
  # Comprehensive default tags
  default_tags {
    tags = {
      Environment        = "${local.environment}"
      Project            = "${local.project}"
      Owner              = "${local.owner}"
      ManagedBy          = "terragrunt"
      SecurityLevel      = "${local.environment == "prod" ? "maximum" : "high"}"
      DataClassification = "${local.environment == "prod" ? "restricted" : "confidential"}"
      BackupRequired     = "true"
      MonitoringEnabled  = "true"
      ComplianceRequired = "${local.environment == "prod" ? "true" : "false"}"
      CostCenter         = "${local.environment}-ops"
      LastUpdated        = "$${formatdate("YYYY-MM-DD", timestamp())}"
    }
  }
}

# Security-focused provider for sensitive operations
provider "aws" {
  alias  = "security"
  region = "${local.region}"
  
  assume_role {
    role_arn     = "arn:aws:iam::${local.aws_account_id}:role/terragrunt-security-role"
    session_name = "terragrunt-security-session"
  }
  
  default_tags {
    tags = {
      Purpose     = "security-operations"
      Environment = "${local.environment}"
      Project     = "${local.project}"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

# Enhanced error handling and hooks
terraform {
  # Pre-deployment validation
  before_hook "security_scan" {
    commands = ["plan", "apply"]
    execute  = ["python3", "${get_repo_root()}/scripts/pre-deploy-security-check.py", get_terragrunt_dir()]
  }
  
  before_hook "validate" {
    commands = ["plan", "apply"]
    execute  = ["terraform", "validate"]
  }
  
  # Post-deployment actions
  after_hook "security_report" {
    commands = ["apply"]
    execute  = ["python3", "${get_repo_root()}/scripts/post-deploy-security-report.py", get_terragrunt_dir()]
  }
  
  # Error handling
  error_hook "failure_notification" {
    commands     = ["apply"]
    execute      = ["python3", "${get_repo_root()}/scripts/deployment-failure-handler.py", get_terragrunt_dir()]
    run_on_error = true
  }
}

# Retry configuration for resilience
retry_max_attempts       = 3
retry_sleep_interval_sec = 5

# =============================================================================
# ENVIRONMENT-SPECIFIC CONFIGURATION TEMPLATE
# =============================================================================

# Template for environment-specific terragrunt.hcl files
locals {
  # Inherit from parent
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  
  # Environment-specific overrides
  environment_config = {
    dev = {
      instance_types = {
        app_server = "t3.small"
        db_server  = "db.t3.micro"
      }
      backup_retention = 7
      deletion_protection = false  # Only for dev
      auto_scaling_max = 3
    }
    staging = {
      instance_types = {
        app_server = "t3.medium"
        db_server  = "db.t3.small"
      }
      backup_retention = 14
      deletion_protection = true
      auto_scaling_max = 5
    }
    prod = {
      instance_types = {
        app_server = "t3.large"
        db_server  = "db.t3.medium"
      }
      backup_retention = 30
      deletion_protection = true
      auto_scaling_max = 10
      mfa_required = true
    }
  }
  
  # Current environment config
  current_config = local.environment_config[local.environment]
}

# =============================================================================
# SECURE DEPENDENCY TEMPLATE
# =============================================================================

# VPC Dependency with comprehensive mock outputs
dependency "vpc" {
  config_path = "../network/vpc"
  
  mock_outputs = {
    vpc_id                      = "vpc-mock-12345678"
    vpc_arn                     = "arn:aws:ec2:region:account:vpc/vpc-mock-12345678"
    vpc_cidr_block             = "10.0.0.0/16"
    private_subnets            = ["subnet-mock-private-1", "subnet-mock-private-2", "subnet-mock-private-3"]
    public_subnets             = ["subnet-mock-public-1", "subnet-mock-public-2", "subnet-mock-public-3"]
    database_subnets           = ["subnet-mock-db-1", "subnet-mock-db-2", "subnet-mock-db-3"]
    private_subnets_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets_cidr_blocks  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    database_subnets_cidr_blocks = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
    nat_gateway_ids            = ["nat-mock-1", "nat-mock-2", "nat-mock-3"]
    internet_gateway_id        = "igw-mock-12345678"
    route_table_ids            = ["rt-mock-private-1", "rt-mock-private-2", "rt-mock-private-3"]
  }
  
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers", "state"]
  mock_outputs_merge_strategy_with_state  = "shallow"
  
  # Skip outputs validation in mock mode
  skip_outputs = false
}

# Security Group Dependency
dependency "security_group" {
  config_path = "../network/securitygroup"
  
  mock_outputs = {
    security_group_id   = "sg-mock-12345678"
    security_group_arn  = "arn:aws:ec2:region:account:security-group/sg-mock-12345678"
    security_group_name = "mock-security-group"
  }
  
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers", "state"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# KMS Dependency for encryption
dependency "kms" {
  config_path = "../security/kms"
  
  mock_outputs = {
    key_arn           = "arn:aws:kms:region:account:key/mock-key-id"
    key_id            = "mock-key-id"
    alias_arn         = "arn:aws:kms:region:account:alias/mock-alias"
    alias_name        = "alias/mock-alias"
    key_policy        = "{}"
    key_usage         = "ENCRYPT_DECRYPT"
    key_spec          = "SYMMETRIC_DEFAULT"
  }
  
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers", "state"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# =============================================================================
# SECURE MODULE CONFIGURATION EXAMPLES
# =============================================================================

# Secure RDS Configuration
terraform {
  source = "tfr://terraform-aws-modules/rds/aws//?version=6.6.0"
}

inputs = {
  # Identity and naming
  identifier = "${local.project}-${local.environment}-db"
  
  # Engine configuration
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = local.current_config.instance_types.db_server
  
  # Storage configuration
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = dependency.kms.outputs.key_arn
  
  # Network configuration
  vpc_security_group_ids = [dependency.security_group.outputs.security_group_id]
  subnet_ids            = dependency.vpc.outputs.database_subnets
  
  # Security configuration
  manage_master_user_password   = true
  master_user_secret_kms_key_id = dependency.kms.outputs.key_arn
  
  # Backup and recovery
  backup_retention_period = local.current_config.backup_retention
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot  = true
  
  # Protection settings
  deletion_protection = local.current_config.deletion_protection
  skip_final_snapshot = !local.current_config.deletion_protection
  final_snapshot_identifier = local.current_config.deletion_protection ? "${local.project}-${local.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null
  
  # Monitoring and logging
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id      = dependency.kms.outputs.key_arn
  
  monitoring_interval = 60
  monitoring_role_arn = dependency.iam_monitoring_role.outputs.arn
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Security parameters
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
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    }
  ]
}

# =============================================================================
# SECURE SECURITY GROUP CONFIGURATION
# =============================================================================

# Security Group with principle of least privilege
terraform {
  source = "tfr://terraform-aws-modules/security-group/aws//?version=5.1.2"
}

inputs = {
  name        = "${local.project}-${local.environment}-app-sg"
  description = "Security group for ${local.environment} application servers"
  vpc_id      = dependency.vpc.outputs.vpc_id

  # Secure ingress rules - NO 0.0.0.0/0 allowed
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH from VPN networks only"
      cidr_blocks = join(",", [
        "10.0.0.0/8",      # Private networks
        "172.16.0.0/12",   # Private networks  
        "192.168.0.0/16",  # Private networks
        get_env("OFFICE_CIDR", "203.0.113.0/24")  # Office network
      ])
    }
  ]
  
  # Application access through load balancer only
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP from load balancer"
      source_security_group_id = dependency.alb_security_group.outputs.security_group_id
    },
    {
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      description              = "HTTPS from load balancer"
      source_security_group_id = dependency.alb_security_group.outputs.security_group_id
    }
  ]

  # Restricted egress (not wide open)
  egress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP for package updates"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS for secure communications"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  
  # Database access within VPC
  egress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "PostgreSQL to database"
      source_security_group_id = dependency.db_security_group.outputs.security_group_id
    }
  ]
}

# =============================================================================
# SECURE S3 CONFIGURATION
# =============================================================================

terraform {
  source = "tfr://terraform-aws-modules/s3-bucket/aws//?version=4.1.2"
}

inputs = {
  bucket = "${local.project}-${local.environment}-data-${formatdate("YYYY", timestamp())}"

  # Access control
  control_object_ownership = true
  object_ownership        = "BucketOwnerPreferred"
  
  # Block all public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Versioning for data protection
  versioning = {
    enabled    = true
    mfa_delete = local.environment == "prod" ? true : false
  }

  # Customer-managed encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = dependency.kms.outputs.key_arn
      }
      bucket_key_enabled = true
    }
  }

  # Lifecycle management
  lifecycle_rule = [
    {
      id      = "security-lifecycle"
      enabled = true
      
      # Transition strategy based on environment
      transition = local.environment == "prod" ? [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ] : [
        {
          days          = 7
          storage_class = "STANDARD_IA"
        },
        {
          days          = 30
          storage_class = "GLACIER"
        }
      ]
      
      # Cleanup old versions
      noncurrent_version_expiration = {
        noncurrent_days = local.environment == "prod" ? 90 : 30
      }
    }
  ]

  # Object lock for compliance (production only)
  object_lock_configuration = local.environment == "prod" ? {
    object_lock_enabled = "Enabled"
    rule = {
      default_retention = {
        mode = "GOVERNANCE"
        days = 90
      }
    }
  } : null

  # Security policies
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy     = true
  
  # Bucket policy for enhanced security
  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureConnections"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${local.project}-${local.environment}-data-${formatdate("YYYY", timestamp())}",
          "arn:aws:s3:::${local.project}-${local.environment}-data-${formatdate("YYYY", timestamp())}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "EnforceEncryption"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "arn:aws:s3:::${local.project}-${local.environment}-data-${formatdate("YYYY", timestamp())}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# =============================================================================
# SECURE IAM ROLE CONFIGURATION  
# =============================================================================

terraform {
  source = "tfr://terraform-aws-modules/iam/aws//modules/iam-role?version=5.30.0"
}

inputs = {
  # Role configuration
  role_name = "${local.project}-${local.environment}-app-role"
  
  # Secure trust policy - specific accounts only
  trusted_role_arns = [
    "arn:aws:iam::${local.aws_account_id}:root"
  ]
  
  # Security requirements
  role_requires_mfa    = local.environment == "prod" ? true : false
  max_session_duration = local.environment == "prod" ? 3600 : 7200  # Shorter for prod
  
  # Permissions boundary for additional security
  permissions_boundary = "arn:aws:iam::${local.aws_account_id}:policy/${local.project}-${local.environment}-permissions-boundary"
  
  # Least privilege policy attachments
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  
  # Custom inline policy for specific permissions
  role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${local.project}-${local.environment}-*/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}