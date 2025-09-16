# Terragrunt AWS Infrastructure for AI Tools

[![Terragrunt Deploy](https://github.com/catherinevee/terragrunt-olechka/actions/workflows/terragrunt-deploy.yml/badge.svg)](https://github.com/catherinevee/terragrunt-olechka/actions/workflows/terragrunt-deploy.yml)
[![Infrastructure Status](https://img.shields.io/badge/Infrastructure-Active-success)](https://github.com/catherinevee/terragrunt-olechka)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623ce4)](https://www.terraform.io/)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-%3E%3D0.50.0-1f77b4)](https://terragrunt.gruntwork.io/)

Production-ready Terragrunt deployment architecture for AWS, optimized for AI tool workloads following the guidelines in CLAUDE.md.

## Architecture Overview

This infrastructure implements a multi-region, multi-environment AWS architecture with:
- Complete environment isolation (dev, staging, production)
- Regional distribution (eu-central-1, ap-southeast-1)
- ECS Fargate for containerized workloads
- Aurora PostgreSQL for databases
- Comprehensive security and monitoring

## Directory Structure

```
infrastructure/
├── terragrunt.hcl                 # Root configuration
├── _envcommon/                    # Shared environment configs
│   ├── network.hcl
│   ├── compute.hcl
│   ├── storage.hcl
│   └── monitoring.hcl
├── dev/
│   ├── account.hcl
│   ├── env.hcl
│   ├── eu-central-1/
│   │   ├── region.hcl
│   │   ├── network/
│   │   ├── compute/
│   │   ├── storage/
│   │   ├── security/
│   │   └── monitoring/
│   └── ap-southeast-1/
├── staging/
└── production/
```

## Prerequisites

1. **AWS Accounts**: Separate AWS accounts for dev, staging, and production
2. **Terraform**: Version >= 1.5.0
3. **Terragrunt**: Version >= 0.50.0
4. **AWS CLI**: Configured with appropriate credentials
5. **GitHub Actions**: Repository secrets configured

## Getting Started

### 1. Configure AWS Accounts

Update the account IDs in:
- `dev/account.hcl`
- `staging/account.hcl`
- `production/account.hcl`

### 2. Set Up State Backend

Create S3 buckets and DynamoDB tables for Terraform state:

```bash
aws s3api create-bucket \
  --bucket terraform-state-<ACCOUNT_ID>-<REGION> \
  --region <REGION> \
  --create-bucket-configuration LocationConstraint=<REGION>

aws dynamodb create-table \
  --table-name terraform-locks-<ACCOUNT_ID> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region <REGION>
```

### 3. Configure GitHub Secrets

Add the following secrets to your GitHub repository:
- `AWS_ROLE_ARN`: IAM role for GitHub Actions
- `INFRACOST_API_KEY`: For cost estimation
- `SLACK_WEBHOOK`: For notifications

### 4. Deploy Infrastructure

#### Deploy entire environment:
```bash
cd infrastructure/dev/eu-central-1
terragrunt run-all apply
```

#### Deploy specific module:
```bash
cd infrastructure/dev/eu-central-1/network/vpc
terragrunt apply
```

## Module Descriptions

### Network Layer
- **VPC**: Multi-AZ VPC with public, private, and database subnets
- **Security Groups**: Managed security groups for services
- **ALB**: Application Load Balancer with WAF protection
- **VPC Endpoints**: Cost-optimized endpoints for AWS services

### Compute Layer
- **ECS Cluster**: Fargate-based container orchestration
- **ECS Services**: API and worker services with auto-scaling
- **Task Definitions**: Containerized applications with X-Ray tracing

### Storage Layer
- **Aurora**: PostgreSQL cluster with read replicas
- **S3**: Artifact and model storage with lifecycle policies
- **ElastiCache**: Redis cluster for caching

### Security Layer
- **KMS**: Customer-managed encryption keys
- **Secrets Manager**: Automated secret rotation
- **WAF**: Web Application Firewall rules

### Monitoring
- **CloudWatch**: Logs, metrics, and dashboards
- **X-Ray**: Distributed tracing

## Environment Configuration

### Development
- Single NAT gateway for cost optimization
- Spot instances for non-critical workloads
- Reduced retention periods
- Minimal redundancy

### Staging
- Multi-AZ deployment
- Production-like configuration
- Moderate retention periods
- Testing environment for production changes

### Production
- Full high-availability setup
- Multi-region deployment
- Extended retention periods
- Maximum security and monitoring

## CI/CD Pipeline

The GitHub Actions workflow provides:
- Automated validation and security scanning
- Cost estimation with Infracost
- Terraform plan on pull requests
- Automated apply on merge to main
- Drift detection (scheduled)

### Workflow Triggers
- **Push to main/develop**: Validates and applies changes
- **Pull Request**: Plans and comments changes
- **Manual dispatch**: Deploy specific environment/region
- **Schedule**: Daily drift detection

## Security Best Practices

1. **Encryption**: All data encrypted at rest and in transit
2. **Secrets**: Managed through AWS Secrets Manager
3. **Access Control**: Least privilege IAM policies
4. **Network Security**: Private subnets with security groups
5. **Compliance**: Checkov scanning in CI/CD

## Cost Optimization

1. **Spot Instances**: Used in dev environment
2. **Lifecycle Policies**: Automatic transition to cheaper storage
3. **Reserved Capacity**: For production baseline
4. **VPC Endpoints**: Reduce data transfer costs
5. **Auto-scaling**: Scale down during off-peak hours

## Monitoring and Alerting

- CloudWatch dashboards for each environment
- Automated alerts for critical metrics
- X-Ray tracing for performance analysis
- Log aggregation with CloudWatch Logs

## Disaster Recovery

- **RTO**: 1 hour
- **RPO**: 15 minutes
- Cross-region replication for critical data
- Automated backups with point-in-time recovery
- Tested disaster recovery procedures

## Maintenance

### Regular Tasks
- **Daily**: Monitor CloudWatch dashboards
- **Weekly**: Review security alerts
- **Monthly**: Update container images, rotate secrets
- **Quarterly**: Update Terraform modules, security audit

## Troubleshooting

### Common Issues

1. **State Lock Error**:
   ```bash
   terragrunt force-unlock <LOCK_ID>
   ```

2. **Dependency Error**:
   ```bash
   terragrunt run-all apply --terragrunt-ignore-dependency-errors
   ```

3. **Plan Drift**:
   ```bash
   terragrunt refresh
   ```

## Contributing

1. Create feature branch from `develop`
2. Make changes and test locally
3. Open pull request to `develop`
4. After review, merge to `develop`
5. Deploy to staging for testing
6. Merge to `main` for production deployment

## License

[Your License Here]

## Support

For issues or questions, please open a GitHub issue.