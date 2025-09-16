include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_envcommon/storage.hcl"
}

dependency "kms" {
  config_path = "../../security/kms"

  mock_outputs = {
    key_arn = "arn:aws:kms:eu-central-1:123456789012:key/mock"
  }
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.env_vars.locals.environment
  region      = local.region_vars.locals.region
}

terraform {
  source = "tfr:///terraform-aws-modules/s3-bucket/aws?version=3.15.1"
}

inputs = {
  bucket = "ai-tools-artifacts-${local.environment}-${local.region}"

  # Versioning
  versioning = {
    enabled = true
  }

  # Server side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = dependency.kms.outputs.key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  # Public access block
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Lifecycle rules
  lifecycle_rule = [
    {
      id      = "transition-old-artifacts"
      enabled = true

      transition = [
        {
          days          = local.environment == "production" ? 90 : 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = local.environment == "production" ? 180 : 90
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = local.environment == "production" ? 2555 : 365
      }

      noncurrent_version_transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 60
          storage_class = "GLACIER"
        }
      ]

      noncurrent_version_expiration = {
        days = 90
      }
    }
  ]

  # CORS configuration
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD", "PUT", "POST"]
      allowed_origins = local.environment == "production" ? ["https://*.ai-tools.com"] : ["*"]
      expose_headers  = ["ETag", "x-amz-request-id"]
      max_age_seconds = 3000
    }
  ]

  # Intelligent tiering
  intelligent_tiering = {
    general = {
      status = "Enabled"
      filter = {
        prefix = "data/"
      }
      tiering = {
        ARCHIVE_ACCESS = {
          days = 90
        }
        DEEP_ARCHIVE_ACCESS = {
          days = 180
        }
      }
    }
  }

  # Bucket policies
  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::ai-tools-artifacts-${local.environment}-${local.region}/*",
          "arn:aws:s3:::ai-tools-artifacts-${local.environment}-${local.region}"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  # Object lock (for compliance)
  object_lock_enabled = local.environment == "production"
  object_lock_configuration = local.environment == "production" ? {
    rule = {
      default_retention = {
        mode = "GOVERNANCE"
        days = 30
      }
    }
  } : null

  # Replication configuration (production only)
  replication_configuration = local.environment == "production" ? {
    role = "arn:aws:iam::${local.account_id}:role/s3-replication-role"

    rules = [
      {
        id       = "replicate-artifacts"
        status   = "Enabled"
        priority = 1

        filter = {
          prefix = "critical/"
        }

        destination = {
          bucket        = "arn:aws:s3:::ai-tools-artifacts-${local.environment}-ap-southeast-1"
          storage_class = "STANDARD_IA"

          replication_time = {
            status = "Enabled"
            time = {
              minutes = 15
            }
          }

          metrics = {
            status = "Enabled"
            event_threshold = {
              minutes = 15
            }
          }
        }

        delete_marker_replication = true
      }
    ]
  } : null

  tags = {
    Environment = local.environment
    Type        = "artifacts"
    Service     = "storage"
  }
}