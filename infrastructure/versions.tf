# Terraform and Provider Version Requirements
# This file defines the exact versions used across the project

terraform {
  required_version = "1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

# Version Information
# Terraform:  1.5.7  (Released: August 2, 2023)
# Terragrunt: 0.50.17 (Released: September 8, 2023)
# AWS Provider: 5.31.0 (Released: December 14, 2023)
#
# These versions have been tested and validated for stability
# and compatibility with all modules in this project.