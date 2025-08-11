# Olechka AWS Environment - eu-west-1

This directory contains the Terragrunt configuration for a complete AWS environment in the eu-west-1 region.

## Environment Overview

This environment includes the following AWS services:

### Networking
- **VPC** (`network/vpc/`) - Virtual Private Cloud with public and private subnets across 3 AZs
- **Security Groups** (`network/securitygroup/`) - Network security rules for application access
- **Application Load Balancer** (`network/elb/`) - Load balancer for distributing traffic
- **NAT Gateways** - Automatically created by the VPC module for private subnet internet access

### Compute
- **EC2 Instance** (`compute/ec2/`) - Application server with Apache web server

### Database
- **RDS PostgreSQL** (`database/rds/`) - Managed PostgreSQL database with encryption and monitoring

### Storage
- **S3 Data Bucket** (`storage/s3/`) - Application data storage with lifecycle policies
- **S3 Logs Bucket** (`storage/s3-logs/`) - Centralized logging storage

### Security
- **WAF** (`security/waf/`) - Web Application Firewall with AWS managed rules
- **Inspector** (`security/inspector/`) - Security assessment service
- **Macie** (`security/macie/`) - Data discovery and protection service

### Identity & Access Management
- **IAM Role** (`iam/role/`) - Application role with necessary permissions

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terragrunt** installed (version 0.54.0 or later)
3. **Terraform** installed (version 1.13.0)
4. **AWS Account** with appropriate permissions

## Configuration

### Required Variables

Before deploying, update the following in `common.hcl`:
- `aws_account_id` - Your actual AWS account ID
- `environment` - Environment name (default: production)
- `project` - Project name (default: olechka)
- `owner` - Owner name (default: olechka)

### SSL Certificate

The ALB configuration references an SSL certificate. You'll need to:
1. Create or import an SSL certificate in AWS Certificate Manager
2. Update the `certificate_arn` in `network/elb/terragrunt.hcl`

### SSH Key Pair

The EC2 instance requires an SSH key pair named "olechka-key". Create this in the AWS console or via AWS CLI.

## Deployment Order

The modules have dependencies configured. Deploy in this order:

1. **VPC** - Foundation networking
2. **Security Groups** - Network security rules
3. **S3 Buckets** - Storage for logs and data
4. **IAM Role** - Application permissions
5. **RDS Database** - Database layer
6. **EC2 Instance** - Application server
7. **ALB** - Load balancer
8. **Security Services** - WAF, Inspector, Macie

## Usage

### Deploy All Modules

```bash
# From the eu-west-1 directory
terragrunt run-all apply
```

### Deploy Specific Module

```bash
# Deploy only the VPC
cd network/vpc
terragrunt apply

# Deploy only the EC2 instance
cd compute/ec2
terragrunt apply
```

### Destroy Environment

```bash
# Destroy all resources (use with caution)
terragrunt run-all destroy
``` 