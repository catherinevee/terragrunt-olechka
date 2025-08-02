generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "eu-west-2"
  
  default_tags {
    tags = {
      Environment = "development"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      CostCenter  = "dev-ops"
      DataClassification = "internal"
      AutoShutdown = "true"
    }
  }
}

provider "aws" {
  alias  = "backup"
  region = "eu-west-1"
  
  default_tags {
    tags = {
      Environment = "development"
      Project     = "olechka"
      Owner       = "olechka"
      ManagedBy   = "terragrunt"
      Purpose     = "backup"
    }
  }
}
EOF
} 