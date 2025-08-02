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
  bucket = "olechka-dev-logs-2024"

  # Enhanced access control for logs
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  # Enhanced versioning for logs
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

  # Enhanced lifecycle rules for logs
  lifecycle_rule = [
    {
      id      = "log-transition"
      enabled = true
      prefix  = "logs/"

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
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
    },
    {
      id      = "log-expiration"
      enabled = true
      prefix  = "logs/"
      expiration = {
        days = 2555  # 7 years for compliance
      }
    },
    {
      id      = "abort-incomplete-multipart"
      enabled = true
      abort_incomplete_multipart_upload_days = 7
    }
  ]

  # Enhanced public access block
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Enhanced bucket policies for logs
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
          "arn:aws:s3:::olechka-dev-logs-2024",
          "arn:aws:s3:::olechka-dev-logs-2024/*"
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
        Resource = "arn:aws:s3:::olechka-dev-logs-2024/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })

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
    StorageClass = "s3-logs"
    Encryption = "enabled"
    Versioning = "enabled"
    LogRetention = "7-years"
  }
} 