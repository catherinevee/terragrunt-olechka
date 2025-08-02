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
  create_macie2_account = true
  create_macie2_classification_job = true

  classification_job_name = "olechka-classification-job"
  job_type = "SCHEDULED"
  schedule_frequency = "DAILY"

  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
  }
} 