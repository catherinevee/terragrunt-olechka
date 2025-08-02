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
  source = "tfr://terraform-aws-modules/macie/aws//?version=1.0.0"
}

inputs = {
  # Enhanced Macie account configuration
  enable_macie_account = true
  enable_macie_member = false

  # Enhanced classification job configuration
  classification_job_name = "olechka-prod-classification-job"
  classification_job_description = "Enterprise data classification for production environment"

  # Enhanced job schedule
  job_type = "SCHEDULED"
  schedule_frequency = "DAILY"
  schedule_start_time = "2024-01-01T00:00:00Z"

  # Enhanced sampling configuration
  sampling_percentage = 100  # Full sampling for production

  # Enhanced S3 job definition
  s3_job_definition = {
    bucket_definitions = [
      {
        account_id = "123456789012"  # Replace with actual account ID
        buckets    = ["olechka-prod-app-data-2024", "olechka-prod-logs-2024"]
      }
    ]
    scoping = {
      excludes = {
        and = [
          {
            simple_scope_term = {
              comparator = "NOT_EQUALS"
              key        = "OBJECT_EXTENSION"
              values     = ["jpg", "png", "gif", "mp4", "avi", "mov", "wmv"]
            }
          }
        ]
      }
    }
  }

  # Enhanced tags
  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "production-ops"
    DataClassification = "restricted"
    AutoShutdown = "false"
    SecurityLevel = "enterprise"
    MacieType = "data-classification"
    HighAvailability = "enabled"
    Compliance = "enabled"
    DisasterRecovery = "enabled"
  }
} 