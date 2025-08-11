# Olechka AWS Environment Deployment Script (PowerShell)
# This script deploys the complete AWS environment in eu-west-1

param(
    [switch]$Force,
    [switch]$SkipValidation
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Starting Olechka AWS Environment Deployment" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check if terragrunt is installed
    try {
        $null = Get-Command terragrunt -ErrorAction Stop
    }
    catch {
        Write-Error "Terragrunt is not installed. Please install Terragrunt first."
        exit 1
    }
    
    # Check if AWS CLI is configured
    try {
        $null = aws sts get-caller-identity 2>$null
    }
    catch {
        Write-Error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    }
    
    Write-Status "Prerequisites check passed!"
}

# Validate configuration
function Test-Configuration {
    Write-Status "Validating configuration..."
    
    # Check if common.hcl exists
    if (-not (Test-Path "../common.hcl")) {
        Write-Error "common.hcl file not found. Please create it first."
        exit 1
    }
    
    # Check if AWS account ID is set
    $commonContent = Get-Content "../common.hcl" -Raw
    if ($commonContent -match "123456789012") {
        Write-Warning "Please update the AWS account ID in common.hcl before deployment."
    }
    
    Write-Status "Configuration validation completed!"
}

# Deploy infrastructure
function Deploy-Infrastructure {
    Write-Status "Deploying infrastructure..."
    
    # Deploy all modules
    Write-Status "Running terragrunt run-all apply..."
    terragrunt run-all apply --terragrunt-non-interactive
    
    Write-Status "Infrastructure deployment completed!"
}

# Show deployment summary
function Show-Summary {
    Write-Status "Deployment Summary:"
    Write-Host "====================" -ForegroundColor Cyan
    Write-Host "VPC with public and private subnets" -ForegroundColor White
    Write-Host "Security groups configured" -ForegroundColor White
    Write-Host "EC2 instance with Apache web server" -ForegroundColor White
    Write-Host "RDS PostgreSQL database" -ForegroundColor White
    Write-Host "S3 buckets for data and logs" -ForegroundColor White
    Write-Host "Application Load Balancer" -ForegroundColor White
    Write-Host "IAM roles and policies" -ForegroundColor White
    Write-Host "WAF, Inspector, and Macie security services" -ForegroundColor White
    Write-Host ""
    Write-Status "Your AWS environment is now ready!"
}

# Main deployment flow
function Main {
    if (-not $SkipValidation) {
        Test-Prerequisites
        Test-Configuration
    }
    
    if (-not $Force) {
        Write-Host ""
        Write-Warning "This will create AWS resources that may incur costs."
        $response = Read-Host "Do you want to continue? (y/N)"
        
        if ($response -notmatch "^[Yy]$") {
            Write-Status "Deployment cancelled."
            exit 0
        }
    }
    
    Deploy-Infrastructure
    Show-Summary
}

# Run main function
Main 