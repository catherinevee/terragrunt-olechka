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
  source = "tfr://terraform-aws-modules/iam/aws//modules/iam-assumable-role?version=5.30.0"
}

inputs = {
  trusted_role_arns = [
    "arn:aws:iam::*:root"
  ]

  create_role = true
  role_name   = "olechka-app-role"
  role_requires_mfa = false

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
  }
} 