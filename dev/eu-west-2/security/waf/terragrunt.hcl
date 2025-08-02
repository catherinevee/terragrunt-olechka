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
  source = "tfr://terraform-aws-modules/wafv2/aws//?version=7.6.1"
}

inputs = {
  name = "olechka-dev-waf"
  description = "Enhanced WAF for development environment"

  scope = "REGIONAL"

  # Enhanced default action
  default_action = {
    allow = {}
  }

  # Enhanced visibility configuration
  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "olechka-dev-waf-metric"
    sampled_requests_enabled   = true
  }

  # Enhanced rules for dev environment
  rules = [
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1

      override_action = {
        none = {}
      }

      statement = {
        managed_rule_group_statement = {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesCommonRuleSetMetric"
        sampled_requests_enabled   = true
      }
    },
    {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 2

      override_action = {
        none = {}
      }

      statement = {
        managed_rule_group_statement = {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
        sampled_requests_enabled   = true
      }
    },
    {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 3

      override_action = {
        none = {}
      }

      statement = {
        managed_rule_group_statement = {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
        sampled_requests_enabled   = true
      }
    },
    {
      name     = "RateLimitRule"
      priority = 4

      action = {
        block = {}
      }

      statement = {
        rate_based_statement = {
          limit              = 2000
          aggregate_key_type = "IP"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "RateLimitRuleMetric"
        sampled_requests_enabled   = true
      }
    },
    {
      name     = "GeoRestrictionRule"
      priority = 5

      action = {
        block = {}
      }

      statement = {
        geo_match_statement = {
          country_codes = ["CN", "RU", "KP"]  # Block specific countries in dev
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoRestrictionRuleMetric"
        sampled_requests_enabled   = true
      }
    },
    {
      name     = "IPRateLimitRule"
      priority = 6

      action = {
        block = {}
      }

      statement = {
        rate_based_statement = {
          limit              = 100
          aggregate_key_type = "IP"
          scope_down_statement = {
            byte_match_statement = {
              search_string         = "/admin"
              positional_constraint = "STARTS_WITH"
              field_to_match = {
                uri_path = {}
              }
              text_transformation {
                priority = 1
                type     = "LOWERCASE"
              }
            }
          }
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "IPRateLimitRuleMetric"
        sampled_requests_enabled   = true
      }
    }
  ]

  # Enhanced tags
  tags = {
    Environment = "development"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "dev-ops"
    DataClassification = "internal"
    AutoShutdown = "true"
    SecurityLevel = "enhanced"
    WAFType = "regional"
  }
} 