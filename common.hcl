locals {
  environment = "production"
  project     = "olechka"
  owner       = "olechka"
  
  # AWS Account ID - replace with actual account ID
  aws_account_id = "123456789012"
  
  # Common tags
  common_tags = {
    Environment = local.environment
    Project     = local.project
    Owner       = local.owner
    ManagedBy   = "terragrunt"
  }
} 