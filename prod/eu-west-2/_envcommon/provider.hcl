generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      CostCenter  = "production-ops"
      DataClassification = "restricted"
      AutoShutdown = "false"
      Backup = "required"
      HighAvailability = "enabled"
      Compliance = "enabled"
      DisasterRecovery = "enabled"
      SecurityLevel = "enterprise"
    }
  }
}

provider "aws" {
  alias  = "backup"
  region = "eu-west-1"
  
  default_tags {
    tags = {
      Environment = "production"
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
      Environment = "production"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      Purpose     = "monitoring"
    }
  }
}

provider "aws" {
  alias  = "compliance"
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      Purpose     = "compliance"
    }
  }
}
EOF
} 