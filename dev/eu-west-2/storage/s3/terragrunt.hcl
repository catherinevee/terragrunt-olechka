include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = "${get_terragrunt_dir()}/../_envcommon/provider.hcl"
}

include "versions" {
  path = "${get_terragrunt_dir()}/../_envcommon/versions.hcl"
}

terraform {
  source = "tfr://terraform-aws-modules/s3-bucket/aws//?version=4.1.2"
}

inputs = {
  bucket = "olechka-dev-app-data-2024"

  # Enhanced access control for dev
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  # Enhanced versioning and replication
  versioning = {
    enabled = true
  }

  # Enhanced server-side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
      bucket_key_enabled = true
    }
  }

  # Enhanced lifecycle rules for dev environment
  lifecycle_rule = [
    {
      id      = "transition-to-ia"
      enabled = true

      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 180
          storage_class = "DEEP_ARCHIVE"
        }
      ]
    },
    {
      id      = "delete-old-versions"
      enabled = true
      noncurrent_version_transition = [
        {
          noncurrent_days = 30
          storage_class   = "STANDARD_IA"
        },
        {
          noncurrent_days = 90
          storage_class   = "GLACIER"
        }
      ]
      noncurrent_version_expiration = {
        noncurrent_days = 365
      }
    },
    {
      id      = "abort-incomplete-multipart"
      enabled = true
      abort_incomplete_multipart_upload_days = 7
    }
  ]

  # Enhanced bucket policies for dev
  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforceSSLOnly"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::olechka-dev-app-data-2024",
          "arn:aws:s3:::olechka-dev-app-data-2024/*"
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
        Resource = "arn:aws:s3:::olechka-dev-app-data-2024/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })

  # Enhanced public access block
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Enhanced intelligent tiering
  intelligent_tiering = [
    {
      name = "EntireBucket"
      status = "Enabled"
      tiering = [
        {
          access_tier = "DEEP_ARCHIVE_ACCESS"
          days        = 180
        },
        {
          access_tier = "ARCHIVE_ACCESS"
          days        = 90
        }
      ]
    }
  ]

  # Enhanced object lock configuration
  object_lock_configuration = {
    object_lock_enabled = "Enabled"
    rule = {
      default_retention = {
        mode = "GOVERNANCE"
        days = 30
      }
    }
  }

  # Enhanced tagging
  tags = {
    Environment = "development"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "dev-ops"
    DataClassification = "internal"
    AutoShutdown = "true"
    Backup = "true"
    StorageClass = "s3"
    Encryption = "enabled"
    Versioning = "enabled"
  }
} 