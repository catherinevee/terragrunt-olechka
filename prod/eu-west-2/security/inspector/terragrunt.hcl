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
  name = "olechka-prod-inspector"

  # Enhanced assessment target
  assessment_target_name = "olechka-prod-target"
  assessment_target_arn  = "arn:aws:ec2:eu-west-2:*:instance/*"

  # Enhanced assessment template
  assessment_template_name = "olechka-prod-template"
  assessment_template_duration = 14400  # 4 hours for production

  # Enhanced rules packages for production
  rules_packages = [
    "arn:aws:inspector:eu-west-2:316112463485:rulespackage/0-9hgA516p",
    "arn:aws:inspector:eu-west-2:316112463485:rulespackage/0-H5hpSawc",
    "arn:aws:inspector:eu-west-2:316112463485:rulespackage/0-JJOtZiqQ",
    "arn:aws:inspector:eu-west-2:316112463485:rulespackage/0-vg5GGHSD"
  ]

  # Enhanced event subscription
  event_subscription_name = "olechka-prod-inspector-events"
  event_subscription_events = [
    "ASSESSMENT_RUN_STARTED",
    "ASSESSMENT_RUN_COMPLETED",
    "ASSESSMENT_RUN_STATE_CHANGED",
    "FINDING_REPORTED"
  ]

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
    InspectorType = "vulnerability-assessment"
    HighAvailability = "enabled"
    Compliance = "enabled"
    DisasterRecovery = "enabled"
  }
} 