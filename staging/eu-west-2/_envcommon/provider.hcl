generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "staging"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      CostCenter  = "staging-ops"
      DataClassification = "confidential"
      AutoShutdown = "false"
      Backup = "required"
      HighAvailability = "enabled"
    }
  }
}

provider "aws" {
  alias  = "backup"
  region = "eu-west-1"
  
  default_tags {
    tags = {
      Environment = "staging"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      Purpose     = "backup"
    }
  }
}

provider "aws" {
  alias  = "monitoring"
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "staging"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      Purpose     = "monitoring"
    }
  }
}
EOF
} 