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
  name = "olechka-prod-waf"
  description = "Enterprise WAF for production environment"

  scope = "REGIONAL"

  # Enhanced default action
  default_action = {
    allow = {}
  }

  # Enhanced visibility configuration
  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "olechka-prod-waf-metric"
    sampled_requests_enabled   = true
  }

  # Enhanced rules for production environment
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
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 4

      override_action = {
        none = {}
      }

      statement = {
        managed_rule_group_statement = {
          name        = "AWSManagedRulesLinuxRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesLinuxRuleSetMetric"
        sampled_requests_enabled   = true
      }
    },
    {
      name     = "RateLimitRule"
      priority = 5

      action = {
        block = {}
      }

      statement = {
        rate_based_statement = {
          limit              = 10000
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
      priority = 6

      action = {
        block = {}
      }

      statement = {
        geo_match_statement = {
          country_codes = ["CN", "RU", "KP", "IR", "SY"]  # Block additional countries in production
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
      priority = 7

      action = {
        block = {}
      }

      statement = {
        rate_based_statement = {
          limit              = 500
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
    },
    {
      name     = "BlockBadBots"
      priority = 8

      action = {
        block = {}
      }

      statement = {
        byte_match_statement = {
          search_string         = "bot"
          positional_constraint = "CONTAINS"
          field_to_match = {
            single_header = {
              name = "user-agent"
            }
          }
          text_transformation {
            priority = 1
            type     = "LOWERCASE"
          }
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "BlockBadBotsMetric"
        sampled_requests_enabled   = true
      }
    }
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
    WAFType = "regional"
    HighAvailability = "enabled"
    Compliance = "enabled"
    DisasterRecovery = "enabled"
  }
} 