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
  source = "tfr://terraform-aws-modules/inspector/aws//?version=1.0.0"
}

inputs = {
  assessment_target_name = "olechka-assessment-target"
  assessment_template_name = "olechka-assessment-template"

  rules_packages = [
    "arn:aws:inspector:eu-west-1:316112463485:rulespackage/0-9hgA516p",
    "arn:aws:inspector:eu-west-1:316112463485:rulespackage/0-H5hpSawc",
    "arn:aws:inspector:eu-west-1:316112463485:rulespackage/0-rExsr2X8"
  ]

  duration = 3600

  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
  }
} 