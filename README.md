# Terragrunt-Olechka / EU-Central-1, AP-Southeast-1

[![Terragrunt Deploy](https://github.com/catherinevee/terragrunt-olechka/actions/workflows/terragrunt-deploy.yml/badge.svg)](https://github.com/catherinevee/terragrunt-olechka/actions/workflows/terragrunt-deploy.yml)
[![Infrastructure Status](https://img.shields.io/badge/Infrastructure-Template-blue)](https://github.com/catherinevee/terragrunt-olechka)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623ce4)](https://www.terraform.io/)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-%3E%3D0.50.0-1f77b4)](https://terragrunt.gruntwork.io/)

Production-ready Terragrunt deployment architecture for AWS, optimized for AI tool workloads following the guidelines in CLAUDE.md.

> **Project Status**: This is a complete infrastructure-as-code template ready for deployment. The infrastructure is not currently deployed. To deploy, follow the setup instructions below to configure AWS credentials and IAM roles.

## Architecture Diagrams

- **[Complete Architecture Diagrams](docs/architecture-diagram.md)** - Detailed infrastructure, CI/CD pipeline, and dependency diagrams
- **[Overview Diagrams](docs/overview-diagram.md)** - High-level system architecture and workflow visualizations

## Version Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **Terraform** | >= 1.5.0 | Required for latest AWS provider features |
| **Terragrunt** | >= 0.50.0 | Required for enhanced dependency management |
| **AWS Provider** | Latest (auto-generated) | Provider version managed by Terraform |
| **AWS CLI** | >= 2.0 | Required for local development and testing |
| **GitHub CLI** | >= 2.0 | Required for repository management |

## Project Overview

This infrastructure implements a multi-region, multi-environment AWS architecture with:

- **Complete environment isolation** between dev, staging, and production
- **Multi-region deployment** with eu-central-1 (primary) and ap-southeast-1 (secondary)
- **ECS Fargate** for containerized AI workloads
- **Aurora PostgreSQL** for persistent data storage
- **Comprehensive security** with KMS encryption, Secrets Manager, and WAF
- **Full observability** with CloudWatch and X-Ray tracing
- **GitOps workflow** with GitHub Actions CI/CD pipeline

## Architecture Components

### Network Layer
- **VPC**: Multi-AZ design with public, private, database, and cache subnets
- **NAT Gateways**: Environment-specific configuration (1 for dev, 2 for staging, 3 for production)
- **VPC Endpoints**: Cost-optimized access to AWS services
- **Application Load Balancer**: With WAF protection and SSL/TLS termination

### Compute Layer
- **ECS Fargate Cluster**: Serverless container orchestration
- **ECS Services**: Auto-scaling API and Worker services
- **Capacity Providers**: Mixed Fargate and Fargate Spot for cost optimization
- **Service Discovery**: AWS Cloud Map integration

### Storage Layer
- **Aurora PostgreSQL**: Multi-AZ deployment with read replicas (production)
- **S3 Buckets**: Artifact and model storage with lifecycle policies
- **ElastiCache Redis**: Session management and caching
- **Cross-region replication**: For critical data (production only)

### Security Layer
- **KMS**: Customer-managed encryption keys with rotation
- **Secrets Manager**: Automated secret rotation for database credentials
- **WAF**: Web Application Firewall with managed rules
- **Security Groups**: Least-privilege network access controls

### Monitoring & Observability
- **CloudWatch**: Centralized logging and metrics
- **X-Ray**: Distributed tracing for microservices
- **CloudWatch Alarms**: Proactive alerting based on thresholds
- **Performance Insights**: Database performance monitoring

## Project Structure

```
terragrunt-olechka/
├── .github/
│   └── workflows/
│       └── terragrunt-deploy.yml     # CI/CD pipeline
├── infrastructure/
│   ├── terragrunt.hcl               # Root configuration
│   ├── _envcommon/                  # Shared environment configs
│   │   ├── network.hcl
│   │   ├── compute.hcl
│   │   ├── storage.hcl
│   │   └── monitoring.hcl
│   ├── dev/
│   │   ├── account.hcl
│   │   ├── env.hcl
│   │   ├── eu-central-1/           # Primary region
│   │   │   ├── region.hcl
│   │   │   ├── network/
│   │   │   ├── compute/
│   │   │   ├── storage/
│   │   │   ├── security/
│   │   │   └── monitoring/
│   │   └── ap-southeast-1/         # Secondary region
│   ├── staging/
│   └── production/
├── scripts/
│   ├── setup-aws-backend.sh        # Backend initialization
│   └── setup-github-secrets.sh     # GitHub configuration
└── docs/
    ├── architecture-diagram.md     # Architecture diagrams
    └── overview-diagram.md         # System overview
```

## Environment Configurations

| Component | Development | Staging | Production |
|-----------|------------|---------|------------|
| **Network** |
| VPC CIDR | 10.0.0.0/16 | 10.10.0.0/16 | 10.20.0.0/16 |
| NAT Gateways | 1 (single) | 2 (multi-AZ) | 3 (one per AZ) |
| VPC Flow Logs | 30 days | 30 days | 90 days |
| **Compute** |
| ECS CPU | 512 | 1024 | 2048 |
| ECS Memory | 1024 MB | 2048 MB | 4096 MB |
| Auto-scaling Min | 1 | 2 | 3 |
| Auto-scaling Max | 5 | 10 | 20 |
| Spot Instances | 80% | 20% | 0% |
| **Database** |
| Aurora Instance | db.t3.medium | db.r6g.large | db.r6g.xlarge |
| Read Replicas | 0 | 0 | 2 |
| Backup Retention | 7 days | 14 days | 30 days |
| Deletion Protection | No | No | Yes |
| **Storage** |
| S3 Lifecycle | 30 days to IA | 30 days to IA | 90 days to IA |
| S3 Replication | No | No | Cross-region |
| **Monitoring** |
| Log Retention | 30 days | 30 days | 90 days |
| Detailed Monitoring | No | Yes | Yes |
| Performance Insights | No | 7 days | 731 days |

## Getting Started

### Prerequisites

1. **AWS Account**: With appropriate IAM permissions
2. **AWS CLI**: Configured with credentials
3. **Terraform**: Version >= 1.5.0
4. **Terragrunt**: Version >= 0.50.0
5. **GitHub CLI**: For repository management
6. **GitHub Repository**: With Actions enabled

### Initial Setup

#### 1. Configure AWS Backend

Run the backend setup script to create S3 bucket and DynamoDB table:

```bash
bash scripts/setup-aws-backend.sh
```

This creates:
- S3 bucket: `terraform-state-{ACCOUNT_ID}-{REGION}`
- DynamoDB table: `terraform-locks-{ACCOUNT_ID}`

#### 2. Configure GitHub Secrets

Set up GitHub Actions secrets for CI/CD:

```bash
bash scripts/setup-github-secrets.sh
```

This configures:
- `AWS_ACCOUNT_ID`: As repository variable
- `AWS_ROLE_ARN`: For OIDC authentication
- `AWS_DEFAULT_REGION`: Default deployment region

#### 3. Create IAM Role for GitHub Actions

Create an IAM role with OIDC trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:catherinevee/terragrunt-olechka:*"
        }
      }
    }
  ]
}
```

### Deployment

#### Using GitHub Actions (Recommended)

Push changes to trigger automatic deployment:

```bash
git add .
git commit -m "Deploy infrastructure"
git push origin main
```

The GitHub Actions workflow will:
1. Detect changed Terragrunt configurations
2. Validate and scan for security issues
3. Generate and review Terraform plan
4. Apply changes (with approval for production)

#### Manual Deployment

For local development and testing:

```bash
# Export AWS credentials
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_DEFAULT_REGION=eu-central-1

# Navigate to environment
cd infrastructure/dev/eu-central-1

# Deploy all modules
terragrunt run-all apply

# Or deploy specific module
cd network/vpc
terragrunt apply
```

## CI/CD Pipeline

The GitHub Actions workflow provides:

### Automated Validation
- **Format checking**: `terragrunt fmt`
- **Configuration validation**: `terragrunt validate`
- **Security scanning**: Checkov
- **Linting**: TFLint
- **Cost estimation**: Infracost

### Deployment Process
1. **Change Detection**: Identifies modified Terragrunt configurations
2. **Parallel Validation**: Validates all changed modules simultaneously
3. **Plan Generation**: Creates Terraform execution plan
4. **Review**: Comments plan summary on pull requests
5. **Apply**: Deploys changes with environment-appropriate approvals
6. **Notification**: Updates status via Slack (if configured)

### Security Features
- **OIDC Authentication**: No static AWS credentials
- **Least Privilege**: IAM role with minimal required permissions
- **State Locking**: Prevents concurrent modifications
- **Encrypted State**: S3 bucket encryption enabled
- **Audit Trail**: All actions logged in CloudTrail

## Module Dependencies

Terragrunt manages dependencies between modules automatically:

```
VPC → Security Groups → ALB
 ↓          ↓            ↓
KMS → Secrets Manager → ECS Services
 ↓                         ↓
S3 Buckets ← Aurora Database
```

Dependencies are defined using Terragrunt's `dependency` blocks with mock outputs for planning.

## Monitoring and Alerting

### CloudWatch Alarms

| Metric | Development | Staging | Production |
|--------|------------|---------|------------|
| CPU High Threshold | 85% | 80% | 75% |
| Memory High Threshold | 85% | 80% | 75% |
| Error Rate Threshold | 10/min | 5/min | 2/min |
| P99 Latency | 2000ms | 1500ms | 1000ms |
| Database CPU | 80% | 75% | 70% |

### Log Aggregation
- Application logs: `/ecs/ai-tools-api`, `/ecs/ai-tools-worker`
- Infrastructure logs: VPC Flow Logs, ALB Access Logs
- Audit logs: CloudTrail, Config

### Distributed Tracing
- X-Ray enabled for all ECS services
- Service map visualization
- Performance bottleneck identification

## Cost Optimization

### Implemented Strategies
- **Spot Instances**: Used in development (80% of capacity)
- **VPC Endpoints**: Reduce NAT Gateway data transfer costs
- **S3 Lifecycle Policies**: Automatic transition to cheaper storage classes
- **Reserved Capacity**: Available for production baseline
- **Auto-scaling**: Scale down during off-peak hours

### Estimated Monthly Costs

| Environment | Compute | Storage | Network | Total |
|-------------|---------|---------|---------|-------|
| Development | $150 | $50 | $30 | $230 |
| Staging | $400 | $100 | $60 | $560 |
| Production | $1,200 | $300 | $150 | $1,650 |

*Note: Costs are estimates and vary based on usage*

## Disaster Recovery

### Backup Strategy
- **RTO**: 1 hour
- **RPO**: 15 minutes
- **Aurora**: Automated backups with point-in-time recovery
- **S3**: Cross-region replication for critical data
- **Secrets**: Replicated to secondary region (production)

### Recovery Procedures
1. Trigger failover in Route 53
2. Promote Aurora read replica in secondary region
3. Update application configuration
4. Verify service health

## Security Best Practices

### Implemented Controls
- **Encryption**: All data encrypted at rest (KMS) and in transit (TLS)
- **Network Segmentation**: Private subnets for compute and database
- **Access Control**: IAM roles with least privilege
- **Secret Management**: AWS Secrets Manager with rotation
- **Vulnerability Scanning**: Container image scanning in ECR
- **Web Protection**: WAF with AWS managed rules

### Compliance
- **Data Residency**: Configurable per environment
- **Audit Logging**: CloudTrail enabled
- **Configuration Compliance**: AWS Config rules
- **Security Monitoring**: GuardDuty enabled (production)

## Troubleshooting

### Common Issues

**Terraform State Lock**
```bash
# List locks
aws dynamodb scan --table-name terraform-locks-${AWS_ACCOUNT_ID}

# Force unlock (use with caution)
terragrunt force-unlock <LOCK_ID>
```

**OIDC Authentication Failure**
- Verify IAM role trust policy
- Check GitHub repository name in trust condition
- Ensure `id-token: write` permission in workflow

**Dependency Errors**
```bash
# Refresh dependencies
terragrunt refresh

# Ignore dependency errors
terragrunt apply --terragrunt-ignore-dependency-errors
```

### Debug Commands

```bash
# Validate configuration
terragrunt validate

# Show dependency graph
terragrunt graph-dependencies

# Plan with detailed output
terragrunt plan -detailed-exitcode

# Check AWS credentials
aws sts get-caller-identity
```

## Maintenance

### Regular Tasks

**Daily**
- Monitor CloudWatch dashboards
- Review error logs

**Weekly**
- Check AWS Cost Explorer
- Review security findings

**Monthly**
- Update container images
- Rotate secrets
- Review and update documentation

**Quarterly**
- Update Terraform modules
- Security audit
- Disaster recovery drill

## Clean Up

To destroy infrastructure:

```bash
# Destroy specific environment
cd infrastructure/dev/eu-central-1
terragrunt run-all destroy

# Confirm destruction
terragrunt run-all destroy --terragrunt-non-interactive
```

**Warning**: This permanently deletes all resources and data.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Ensure all validations pass
5. Submit a pull request
6. Wait for CI/CD validation
7. Request review

## Support

For issues or questions:
1. Check the [Architecture Diagrams](docs/architecture-diagram.md)
2. Review [Troubleshooting](#troubleshooting) section
3. Check GitHub Actions logs
4. Open an issue with details

## License

This project is licensed under the MIT License.

## References

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments)