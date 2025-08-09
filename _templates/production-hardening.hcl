# Production Hardening Configuration Template
# Apply these configurations for production-grade security

# =============================================================================
# ENHANCED KMS KEY MANAGEMENT
# =============================================================================

terraform {
  source = "tfr://terraform-aws-modules/kms/aws//?version=3.1.0"
}

inputs = {
  description = "${local.project} ${local.environment} encryption key"
  key_usage   = "ENCRYPT_DECRYPT"
  key_spec    = "SYMMETRIC_DEFAULT"

  # Enhanced key policy with least privilege
  key_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${local.region}.amazonaws.com",
              "rds.${local.region}.amazonaws.com",
              "secretsmanager.${local.region}.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "Allow Terragrunt Role"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.aws_account_id}:role/terragrunt-${local.environment}-role"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  # Key rotation
  enable_key_rotation = true
  rotation_period_in_days = 90

  # Aliases
  aliases = [
    "${local.project}-${local.environment}-key",
    "${local.project}-${local.environment}-encryption"
  ]

  # Deletion protection
  deletion_window_in_days = 30

  # Enhanced tagging
  tags = {
    Environment        = local.environment
    Project           = local.project
    Purpose           = "encryption"
    KeyRotation       = "enabled"
    ComplianceRequired = "true"
    SecurityLevel     = "maximum"
  }
}

# =============================================================================
# ENHANCED MONITORING AND ALERTING
# =============================================================================

# CloudWatch Log Group for centralized logging
terraform {
  source = "tfr://terraform-aws-modules/cloudwatch/aws//modules/log-group?version=5.3.1"
}

inputs = {
  name              = "/aws/${local.project}/${local.environment}/application"
  retention_in_days = local.environment == "prod" ? 365 : 90
  
  # Encryption with customer-managed key
  kms_key_id = dependency.kms.outputs.key_arn
  
  tags = {
    Environment = local.environment
    Project     = local.project
    Purpose     = "application-logging"
    Retention   = local.environment == "prod" ? "365-days" : "90-days"
  }
}

# CloudWatch Alarms for security monitoring
terraform {
  source = "tfr://terraform-aws-modules/cloudwatch/aws//modules/metric-alarm?version=5.3.1"
}

inputs = {
  alarm_name        = "${local.project}-${local.environment}-security-alerts"
  alarm_description = "Security-related alerts for ${local.environment} environment"
  
  # Monitor failed login attempts
  metric_name = "FailedLoginAttempts"
  namespace   = "AWS/ApplicationELB"
  statistic   = "Sum"
  
  # Alert thresholds
  threshold          = local.environment == "prod" ? 5 : 10
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 2
  period            = 300
  
  # Actions
  alarm_actions = [
    dependency.sns_security_alerts.outputs.topic_arn
  ]
  
  treat_missing_data = "breaching"
  
  tags = {
    Environment = local.environment
    Project     = local.project
    AlertType   = "security"
    Severity    = "high"
  }
}

# =============================================================================
# ENHANCED BACKUP AND DISASTER RECOVERY
# =============================================================================

# AWS Backup Vault with encryption
terraform {
  source = "tfr://terraform-aws-modules/backup/aws//modules/vault?version=1.3.0"
}

inputs = {
  vault_name = "${local.project}-${local.environment}-backup-vault"
  
  # Encryption
  vault_kms_key_arn = dependency.kms.outputs.key_arn
  
  # Access policy
  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDeleteBackups"
        Effect = "Deny"
        Principal = "*"
        Action = [
          "backup:DeleteBackupVault",
          "backup:DeleteBackupPlan",
          "backup:DeleteRecoveryPoint"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:userid" = [
              "AIDACKCEVSQ6C2EXAMPLE",  # Replace with actual admin user ID
              "arn:aws:iam::${local.aws_account_id}:role/backup-admin-role"
            ]
          }
        }
      }
    ]
  })
  
  # Notification
  sns_topic_arn = dependency.sns_backup_notifications.outputs.topic_arn
  
  tags = {
    Environment = local.environment
    Project     = local.project
    Purpose     = "backup-vault"
    Protection  = "maximum"
  }
}

# =============================================================================
# ENHANCED NETWORK SECURITY
# =============================================================================

# VPC with comprehensive security features
terraform {
  source = "tfr://terraform-aws-modules/vpc/aws//?version=5.8.1"
}

inputs = {
  name = "${local.project}-${local.environment}-vpc"
  cidr = local.network_config.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = local.network_config.private_subnets
  public_subnets  = local.network_config.public_subnets
  database_subnets = local.network_config.database_subnets

  # NAT Gateway configuration
  enable_nat_gateway     = true
  single_nat_gateway     = local.environment == "dev" ? true : false
  one_nat_gateway_per_az = local.environment != "dev"

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs for security monitoring
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_destination_type            = "cloud-watch-logs"
  flow_log_cloudwatch_log_group_name_prefix = "/aws/vpc/flowlogs"
  flow_log_cloudwatch_log_group_retention_in_days = local.environment == "prod" ? 365 : 90
  flow_log_cloudwatch_log_group_kms_key_id = dependency.kms.outputs.key_arn

  # Network ACLs for additional security
  manage_default_network_acl = true
  default_network_acl_tags = {
    Name = "${local.project}-${local.environment}-default-nacl"
  }

  # Security groups
  manage_default_security_group = true
  default_security_group_name = "${local.project}-${local.environment}-default-sg"
  
  # Remove all rules from default security group
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Enhanced tagging
  tags = {
    Environment = local.environment
    Project     = local.project
    NetworkTier = "core"
    FlowLogs    = "enabled"
    Monitoring  = "enabled"
  }
  
  # Subnet-specific tags
  private_subnet_tags = {
    Type = "private"
    Tier = "application"
  }
  
  public_subnet_tags = {
    Type = "public" 
    Tier = "load-balancer"
  }
  
  database_subnet_tags = {
    Type = "database"
    Tier = "data"
    Backup = "required"
  }
}

# =============================================================================
# SECRETS MANAGER INTEGRATION
# =============================================================================

# Secrets Manager for sensitive configuration
terraform {
  source = "tfr://terraform-aws-modules/secrets-manager/aws//?version=1.1.2"
}

inputs = {
  # Secret configuration
  name        = "${local.project}/${local.environment}/database/master-password"
  description = "Master password for ${local.environment} database"
  
  # Encryption
  kms_key_id = dependency.kms.outputs.key_arn
  
  # Automatic rotation
  rotation_lambda_arn = dependency.rotation_lambda.outputs.function_arn
  rotation_rules = {
    automatically_after_days = 30
  }
  
  # Recovery configuration
  recovery_window_in_days = local.environment == "prod" ? 30 : 7
  
  # Secret value (generated automatically)
  create_random_password = true
  random_password_length = 32
  random_password_override_special = "!@#$%^&*"
  
  # Replica for disaster recovery
  replica = local.environment == "prod" ? {
    region     = "eu-west-1"  # Different from primary region
    kms_key_id = dependency.backup_kms.outputs.key_arn
  } : null
  
  tags = {
    Environment = local.environment
    Project     = local.project
    Purpose     = "database-credentials"
    Rotation    = "enabled"
    SecurityLevel = "maximum"
  }
}

# =============================================================================
# ENHANCED SECURITY MONITORING
# =============================================================================

# GuardDuty for threat detection
terraform {
  source = "tfr://terraform-aws-modules/guardduty/aws//?version=1.4.0"
}

inputs = {
  enable = true
  
  # Enhanced finding publishing
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  
  # S3 protection
  datasources = {
    s3_logs = {
      enable = true
    }
    kubernetes = {
      enable = true
    }
    malware_protection = {
      enable = true
    }
  }
  
  # CloudWatch integration
  cloudwatch_event_rule_name = "${local.project}-${local.environment}-guardduty-events"
  sns_topic_arn = dependency.sns_security_alerts.outputs.topic_arn
  
  tags = {
    Environment = local.environment
    Project     = local.project
    Service     = "threat-detection"
    Monitoring  = "enabled"
  }
}

# Security Hub for centralized security findings
terraform {
  source = "tfr://terraform-aws-modules/security-hub/aws//?version=1.3.0"
}

inputs = {
  enable_default_standards = true
  
  # Enable compliance standards
  enabled_standards = [
    "aws-foundational-security-standard",
    "cis-aws-foundations-benchmark",
    "pci-dss"
  ]
  
  # Custom insights
  insights = [
    {
      name    = "${local.project}-${local.environment}-critical-findings"
      filters = {
        severity_label = ["CRITICAL", "HIGH"]
        workflow_state = ["NEW", "ASSIGNED"]
      }
      group_by_attribute = "ResourceId"
    }
  ]
  
  tags = {
    Environment = local.environment
    Project     = local.project
    Service     = "security-hub"
    Compliance  = "enabled"
  }
}

# =============================================================================
# COMPLIANCE AND AUDIT CONFIGURATION
# =============================================================================

# CloudTrail for audit logging
terraform {
  source = "tfr://terraform-aws-modules/cloudtrail/aws//?version=4.1.0"
}

inputs = {
  cloudtrail_name = "${local.project}-${local.environment}-audit-trail"
  
  # S3 configuration
  s3_bucket_name = "${local.project}-${local.environment}-audit-logs-${random_id.bucket_suffix.hex}"
  s3_key_prefix  = "cloudtrail-logs/"
  
  # Encryption
  kms_key_id = dependency.kms.outputs.key_arn
  
  # Enhanced logging
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true
  
  # Event selectors for comprehensive logging
  event_selector = [
    {
      read_write_type                 = "All"
      include_management_events       = true
      exclude_management_event_sources = []
      
      data_resource = [
        {
          type   = "AWS::S3::Object"
          values = ["arn:aws:s3:::${local.project}-${local.environment}-*/*"]
        },
        {
          type   = "AWS::S3::Bucket"
          values = ["arn:aws:s3:::${local.project}-${local.environment}-*"]
        }
      ]
    }
  ]
  
  # Advanced event selectors for detailed logging
  advanced_event_selector = [
    {
      name = "Log all S3 data events"
      field_selector = [
        {
          field  = "eventCategory"
          equals = ["Data"]
        },
        {
          field  = "resources.type"
          equals = ["AWS::S3::Object"]
        }
      ]
    }
  ]
  
  # CloudWatch integration
  cloud_watch_logs_group_arn = dependency.cloudwatch_log_group.outputs.arn
  cloud_watch_logs_role_arn  = dependency.cloudtrail_cloudwatch_role.outputs.arn
  
  tags = {
    Environment = local.environment
    Project     = local.project
    Purpose     = "audit-logging"
    Compliance  = "required"
    Retention   = "long-term"
  }
}

# =============================================================================
# ENHANCED LOAD BALANCER SECURITY
# =============================================================================

terraform {
  source = "tfr://terraform-aws-modules/alb/aws//?version=9.9.2"
}

inputs = {
  name     = "${local.project}-${local.environment}-alb"
  vpc_id   = dependency.vpc.outputs.vpc_id
  subnets  = dependency.vpc.outputs.public_subnets
  
  # Security configuration
  security_groups = [dependency.alb_security_group.outputs.security_group_id]
  
  # Enhanced load balancer attributes
  load_balancer_type = "application"
  internal          = false
  
  # Security attributes
  enable_deletion_protection       = local.environment == "prod" ? true : false
  enable_cross_zone_load_balancing = true
  enable_http2                    = true
  enable_waf_fail_open           = false
  
  # Access logging with encryption
  access_logs = {
    bucket  = dependency.s3_access_logs.outputs.bucket_id
    prefix  = "alb-access-logs"
    enabled = true
  }
  
  # Connection logs
  connection_logs = {
    bucket  = dependency.s3_access_logs.outputs.bucket_id
    prefix  = "alb-connection-logs"
    enabled = true
  }

  # Enhanced HTTPS listeners with security headers
  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = dependency.acm_certificate.outputs.arn
      ssl_policy         = "ELBSecurityPolicy-TLS-1-2-2017-01"  # Strong TLS policy
      target_group_index = 0
      
      # Security headers
      fixed_response = {
        content_type = "text/plain"
        message_body = "Access denied"
        status_code  = "403"
      }
    }
  ]
  
  # Redirect HTTP to HTTPS
  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]
  
  # Target groups with health checks
  target_groups = [
    {
      name             = "${local.project}-${local.environment}-app-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      
      # Enhanced health check
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
      
      # Stickiness for session management
      stickiness = {
        enabled         = true
        cookie_duration = 86400
        type           = "lb_cookie"
      }
    }
  ]

  # WAF integration
  enable_waf = true
  waf_arn    = dependency.waf.outputs.arn
  
  tags = {
    Environment = local.environment
    Project     = local.project
    Service     = "load-balancer"
    SecurityLevel = "enhanced"
    WAF         = "enabled"
    Monitoring  = "enabled"
  }
}

# =============================================================================
# ENHANCED SECURITY GROUP FOR ALB
# =============================================================================

terraform {
  source = "tfr://terraform-aws-modules/security-group/aws//?version=5.1.2"
}

inputs = {
  name        = "${local.project}-${local.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = dependency.vpc.outputs.vpc_id

  # HTTP/HTTPS from internet (ALB only)
  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP from internet (redirects to HTTPS)"
      cidr_blocks = "0.0.0.0/0"  # Acceptable for ALB HTTP redirect
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from internet"
      cidr_blocks = "0.0.0.0/0"  # Acceptable for ALB HTTPS
    }
  ]

  # Egress to application servers only
  egress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP to application servers"
      source_security_group_id = dependency.app_security_group.outputs.security_group_id
    },
    {
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      description              = "HTTPS to application servers"
      source_security_group_id = dependency.app_security_group.outputs.security_group_id
    }
  ]

  tags = {
    Environment = local.environment
    Project     = local.project
    Purpose     = "load-balancer-security"
    NetworkTier = "public"
  }
}

# =============================================================================
# ENHANCED WAF CONFIGURATION
# =============================================================================

terraform {
  source = "tfr://terraform-aws-modules/wafv2/aws//?version=7.6.1"
}

inputs = {
  name  = "${local.project}-${local.environment}-waf"
  scope = "REGIONAL"

  # Default action
  default_action = {
    allow = {}
  }

  # Comprehensive rule set
  rules = [
    # AWS Managed Rules
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
      
      override_action = {
        none = {}
      }
      
      managed_rule_group_statement = {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        
        # Exclude specific rules if needed
        excluded_rule = [
          {
            name = "SizeRestrictions_BODY"
          }
        ]
      }
      
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "CommonRuleSetMetric"
        sampled_requests_enabled   = true
      }
    },
    
    # SQL Injection protection
    {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 2
      
      override_action = {
        none = {}
      }
      
      managed_rule_group_statement = {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
      
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "SQLiRuleSetMetric"
        sampled_requests_enabled   = true
      }
    },
    
    # Rate limiting
    {
      name     = "RateLimitRule"
      priority = 3
      
      action = {
        block = {}
      }
      
      rate_based_statement = {
        limit              = local.environment == "prod" ? 2000 : 1000
        aggregate_key_type = "IP"
      }
      
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "RateLimitMetric"
        sampled_requests_enabled   = true
      }
    },
    
    # Geo-blocking (if required)
    {
      name     = "GeoBlockRule"
      priority = 4
      
      action = {
        block = {}
      }
      
      geo_match_statement = {
        country_codes = ["CN", "RU", "KP"]  # Block specific countries
      }
      
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockMetric"
        sampled_requests_enabled   = true
      }
    }
  ]

  # Logging configuration
  logging_config = {
    log_destination_configs = [
      dependency.s3_waf_logs.outputs.bucket_arn
    ]
    redacted_fields = [
      {
        single_header = {
          name = "authorization"
        }
      },
      {
        single_header = {
          name = "cookie"
        }
      }
    ]
  }

  tags = {
    Environment = local.environment
    Project     = local.project
    Service     = "web-application-firewall"
    Protection  = "comprehensive"
    Logging     = "enabled"
  }
}