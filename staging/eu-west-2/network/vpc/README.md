# VPC Module Configuration

## Overview
This module creates a secure, multi-AZ VPC configuration for the staging environment in eu-west-2 (London) region.

## Features
- Multi-AZ deployment (eu-west-2a, eu-west-2b, eu-west-2c)
- Separate subnet tiers:
  - Private subnets (10.2.1.0/24, 10.2.2.0/24, 10.2.3.0/24)
  - Public subnets (10.2.101.0/24, 10.2.102.0/24, 10.2.103.0/24)
  - Database subnets (10.2.201.0/24, 10.2.202.0/24, 10.2.203.0/24)
  - Elasticache subnets (10.2.211.0/24, 10.2.212.0/24, 10.2.213.0/24)
  - Redshift subnets (10.2.221.0/24, 10.2.222.0/24, 10.2.223.0/24)
  - Intra subnets (10.2.251.0/24, 10.2.252.0/24, 10.2.253.0/24)

## Security Features
- VPC Flow Logs enabled
- CloudWatch integration
- Enhanced network monitoring
- NAT Gateway per AZ for high availability

## Prerequisites
- Terragrunt installed
- AWS credentials configured
- Required IAM permissions

## Usage
```bash
# Initialize
terragrunt init

# Plan changes
terragrunt plan

# Apply changes
terragrunt apply
```

## Inputs
| Name | Description | Type | Default |
|------|-------------|------|---------|
| cidr | VPC CIDR block | string | 10.2.0.0/16 |
| azs | Availability zones | list(string) | ["eu-west-2a", "eu-west-2b", "eu-west-2c"] |
| enable_nat_gateway | Enable NAT Gateway | bool | true |
| single_nat_gateway | Use single NAT Gateway | bool | false |
| enable_vpn_gateway | Enable VPN Gateway | bool | true |

## Outputs
| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| private_subnets | List of private subnet IDs |
| public_subnets | List of public subnet IDs |
| database_subnets | List of database subnet IDs |

## Security Considerations
1. All subnets properly segregated
2. Flow logs enabled for monitoring
3. NAT Gateways in private subnets
4. Network ACLs implemented
5. Security groups segregated by function

## Monitoring
- VPC Flow Logs enabled
- CloudWatch metrics enabled
- Network usage metrics enabled

## Maintenance
- Regular security group review
- CIDR block capacity monitoring
- Flow log analysis
- Cost optimization review
