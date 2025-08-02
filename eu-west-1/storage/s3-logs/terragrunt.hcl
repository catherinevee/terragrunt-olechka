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
  bucket = "olechka-app-logs-2024"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [
    {
      id      = "log-retention"
      enabled = true

      expiration = {
        days = 90
      }
    }
  ]

  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
    Purpose     = "logs"
  }
} 