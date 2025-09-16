# Terragrunt AWS Architecture for AI Tools

## Executive Summary

This document outlines a production-ready Terragrunt deployment architecture for AWS, specifically optimized for AI tool workloads like Claude Code. The architecture emphasizes security, reliability, and scalability while avoiding common Terraform/Terragrunt anti-patterns.

## Architecture Overview

### Core Principles

1. **Environment Isolation**: Complete separation between dev, staging, and production environments
2. **Regional Distribution**: Multi-region deployment using eu-central-1 (Frankfurt) and ap-southeast-1 (Singapore)
3. **Containerized Workloads**: ECS Fargate for serverless container orchestration (no EKS)
4. **Infrastructure as Code**: Terragrunt for DRY configurations with Terraform Registry modules
5. **GitOps**: GitHub Actions for CI/CD with proper state management

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Route 53 (Global DNS)                    │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
┌───────▼────────┐                       ┌─────────▼────────┐
│  eu-central-1  │                       │ ap-southeast-1   │
│   (Primary)    │                       │   (Secondary)    │
└────────────────┘                       └──────────────────┘
        │                                           │
┌───────▼────────┐                       ┌─────────▼────────┐
│   CloudFront   │                       │   CloudFront     │
└────────────────┘                       └──────────────────┘
        │                                           │
┌───────▼────────┐                       ┌─────────▼────────┐
│   ALB + WAF    │                       │   ALB + WAF      │
└────────────────┘                       └──────────────────┘
        │                                           │
┌───────▼────────┐                       ┌─────────▼────────┐
│  ECS Fargate   │                       │  ECS Fargate     │
└────────────────┘                       └──────────────────┘
        │                                           │
┌───────▼────────┐                       ┌─────────▼────────┐
│     Aurora     │◄──────────────────────│     Aurora       │
│   (Primary)    │      Replication      │    (Replica)     │
└────────────────┘                       └──────────────────┘
```

## Folder Structure

```
infrastructure/
├── terragrunt.hcl                 # Root configuration
├── _envcommon/                    # Shared environment configs
│   ├── network.hcl
│   ├── compute.hcl
│   ├── storage.hcl
│   └── monitoring.hcl
├── modules/                       # Local module wrappers
│   └── tags/
│       └── main.tf
├── dev/
│   ├── account.hcl
│   ├── env.hcl
│   ├── eu-central-1/
│   │   ├── region.hcl
│   │   ├── network/
│   │   │   ├── vpc/
│   │   │   │   └── terragrunt.hcl
│   │   │   ├── security-groups/
│   │   │   │   └── terragrunt.hcl
│   │   │   └── endpoints/
│   │   │       └── terragrunt.hcl
│   │   ├── compute/
│   │   │   ├── ecs-cluster/
│   │   │   │   └── terragrunt.hcl
│   │   │   ├── ecs-service-api/
│   │   │   │   └── terragrunt.hcl
│   │   │   └── ecs-service-worker/
│   │   │       └── terragrunt.hcl
│   │   ├── storage/
│   │   │   ├── s3-artifacts/
│   │   │   │   └── terragrunt.hcl
│   │   │   ├── s3-models/
│   │   │   │   └── terragrunt.hcl
│   │   │   └── aurora/
│   │   │       └── terragrunt.hcl
│   │   ├── cdn/
│   │   │   └── cloudfront/
│   │   │       └── terragrunt.hcl
│   │   ├── security/
│   │   │   ├── waf/
│   │   │   │   └── terragrunt.hcl
│   │   │   ├── secrets/
│   │   │   │   └── terragrunt.hcl
│   │   │   └── kms/
│   │   │       └── terragrunt.hcl
│   │   └── monitoring/
│   │       ├── cloudwatch/
│   │       │   └── terragrunt.hcl
│   │       └── x-ray/
│   │           └── terragrunt.hcl
│   └── ap-southeast-1/
│       └── [similar structure]
├── staging/
│   └── [similar structure]
└── production/
    └── [similar structure]
```

## Core Components

### 1. Networking Layer

**VPC Configuration** (using terraform-aws-modules/vpc/aws)
- Three-tier architecture with public, private, and database subnets
- NAT Gateways in multiple AZs for high availability
- VPC Endpoints for AWS services to reduce data transfer costs
- Network ACLs and Security Groups with least privilege

**Key Features:**
- IPv6 support enabled
- VPC Flow Logs to S3
- Transit Gateway for cross-region connectivity
- PrivateLink endpoints for AWS services

### 2. Compute Layer

**ECS Fargate** (using terraform-aws-modules/ecs/aws)
- Serverless container orchestration
- Auto-scaling based on CPU/Memory metrics
- Blue/Green deployments with CodeDeploy
- Service discovery using AWS Cloud Map

**Application Load Balancer**
- Path-based routing
- SSL/TLS termination
- Health checks with custom intervals
- Integration with WAF for DDoS protection

### 3. Storage Layer

**Aurora PostgreSQL** (using terraform-aws-modules/rds-aurora/aws)
- Multi-AZ deployment with read replicas
- Automated backups with 30-day retention
- Performance Insights enabled
- Encryption at rest using KMS

**S3 Buckets**
- Versioning enabled
- Server-side encryption with KMS
- Lifecycle policies for cost optimization
- Cross-region replication for critical data

**ElastiCache Redis**
- Cluster mode enabled for horizontal scaling
- Multi-AZ with automatic failover
- Encryption in transit and at rest

### 4. Security Components

**AWS WAF**
- Rate limiting rules
- SQL injection protection
- XSS prevention
- Geographic restrictions

**Secrets Manager**
- Automatic rotation for database credentials
- Integration with ECS task definitions
- Cross-region replication for secrets

**KMS**
- Customer-managed keys for encryption
- Key rotation policies
- Separate keys per environment

### 5. Monitoring & Observability

**CloudWatch**
- Custom metrics for application performance
- Log aggregation with Log Insights
- Alarms with SNS notifications

**X-Ray**
- Distributed tracing for microservices
- Performance bottleneck identification
- Service map visualization

## Terragrunt Configuration Examples

### Root terragrunt.hcl

```hcl
locals {
  # Parse account and region from path
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id   = local.account_vars.locals.account_id
  region       = local.region_vars.locals.region
  environment  = local.env_vars.locals.environment
}

# Remote state configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "terraform-state-${local.account_id}-${local.region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks-${local.account_id}"
    
    s3_bucket_tags = {
      Environment = local.environment
      ManagedBy   = "Terragrunt"
    }
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Region      = "${local.region}"
      ManagedBy   = "Terragrunt"
      Project     = "ai-tools"
    }
  }
}
EOF
}

# Version constraints
terraform_version_constraint  = ">= 1.5.0"
terragrunt_version_constraint = ">= 0.50.0"
```

### VPC Module Configuration (dev/eu-central-1/network/vpc/terragrunt.hcl)

```hcl
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../../../../_envcommon/network.hcl"
}

locals {
  environment = "dev"
  region      = "eu-central-1"
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.2"
}

inputs = {
  name = "ai-tools-${local.environment}-${local.region}"
  cidr = "10.0.0.0/16"

  azs              = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway     = true
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_ipv6           = true
  single_nat_gateway    = local.environment == "dev" ? true : false
  one_nat_gateway_per_az = local.environment == "production" ? true : false

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role = true
  create_flow_log_cloudwatch_log_group = true

  # VPC Endpoints
  enable_s3_endpoint          = true
  enable_dynamodb_endpoint    = true
  enable_secretsmanager_endpoint = true
  enable_kms_endpoint         = true
  enable_ecs_endpoint         = true
  enable_ecs_agent_endpoint   = true
  enable_ecs_telemetry_endpoint = true

  tags = {
    Environment = local.environment
    Region      = local.region
  }
}
```

### ECS Service Configuration (dev/eu-central-1/compute/ecs-service-api/terragrunt.hcl)

```hcl
include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../../network/vpc"
}

dependency "ecs_cluster" {
  config_path = "../ecs-cluster"
}

dependency "alb" {
  config_path = "../../network/alb"
}

dependency "secrets" {
  config_path = "../../security/secrets"
}

terraform {
  source = "tfr:///terraform-aws-modules/ecs/aws//modules/service?version=5.2.2"
}

inputs = {
  name        = "ai-tools-api"
  cluster_arn = dependency.ecs_cluster.outputs.cluster_arn

  cpu    = 2048
  memory = 4096

  container_definitions = {
    api = {
      essential = true
      image     = "your-ecr-repo/ai-tools-api:latest"
      
      port_mappings = [
        {
          name          = "api"
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = "dev"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = dependency.secrets.outputs.database_url_arn
        }
      ]

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      log_configuration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/ai-tools-api"
          awslogs-region        = "eu-central-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  }

  load_balancer = {
    service = {
      target_group_arn = dependency.alb.outputs.target_group_arns[0]
      container_name   = "api"
      container_port   = 8080
    }
  }

  subnet_ids = dependency.vpc.outputs.private_subnets

  security_group_rules = {
    alb_ingress = {
      type                     = "ingress"
      from_port               = 8080
      to_port                 = 8080
      protocol                = "tcp"
      source_security_group_id = dependency.alb.outputs.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Auto-scaling
  enable_autoscaling = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 10

  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value = 75
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value = 80
      }
    }
  }

  # Circuit breaker
  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  tags = {
    Service = "api"
    Type    = "fargate"
  }
}
```

## CI/CD Pipeline

### GitHub Actions Workflow (.github/workflows/terragrunt-deploy.yml)

```yaml
name: Terragrunt Deploy

on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'infrastructure/**'
      - '.github/workflows/terragrunt-deploy.yml'
  pull_request:
    branches:
      - main
      - develop
    paths:
      - 'infrastructure/**'

env:
  TERRAFORM_VERSION: '1.5.7'
  TERRAGRUNT_VERSION: '0.50.17'
  AWS_DEFAULT_REGION: 'eu-central-1'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
      has-changes: ${{ steps.set-matrix.outputs.has-changes }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changed directories
        id: set-matrix
        run: |
          # Detect changed Terragrunt configurations
          CHANGED_DIRS=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }} | \
            grep -E "infrastructure/.*/terragrunt.hcl$" | \
            xargs -I {} dirname {} | \
            sort -u | \
            jq -R -s -c 'split("\n")[:-1]')
          
          if [ "$CHANGED_DIRS" == "[]" ]; then
            echo "has-changes=false" >> $GITHUB_OUTPUT
            echo "matrix={\"include\":[]}" >> $GITHUB_OUTPUT
          else
            echo "has-changes=true" >> $GITHUB_OUTPUT
            MATRIX=$(echo $CHANGED_DIRS | jq -c '{include: [.[] | {directory: .}]}')
            echo "matrix=$MATRIX" >> $GITHUB_OUTPUT
          fi

  validate:
    needs: detect-changes
    if: needs.detect-changes.outputs.has-changes == 'true'
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Setup Terragrunt
        run: |
          wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Terragrunt Format Check
        run: |
          cd ${{ matrix.directory }}
          terragrunt fmt -check -diff

      - name: Terragrunt Validate
        run: |
          cd ${{ matrix.directory }}
          terragrunt validate

      - name: TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: latest

      - name: Run TFLint
        run: |
          cd ${{ matrix.directory }}
          tflint --init
          tflint

      - name: Checkov Security Scan
        uses: bridgecrewio/checkov-action@master
        with:
          directory: ${{ matrix.directory }}
          framework: terraform
          quiet: false
          soft_fail: false
          skip_check: CKV_AWS_18,CKV_AWS_21  # Example skips

  plan:
    needs: [detect-changes, validate]
    if: needs.detect-changes.outputs.has-changes == 'true'
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    environment:
      name: ${{ github.ref == 'refs/heads/main' && 'production' || 'development' }}
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Setup Terragrunt
        run: |
          wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Terragrunt Plan
        id: plan
        run: |
          cd ${{ matrix.directory }}
          terragrunt plan -out=tfplan -input=false
          terragrunt show -json tfplan > plan.json

      - name: Upload Plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-${{ hashFiles(matrix.directory) }}
          path: |
            ${{ matrix.directory }}/tfplan
            ${{ matrix.directory }}/plan.json

      - name: Comment PR with Plan
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const plan = JSON.parse(fs.readFileSync('${{ matrix.directory }}/plan.json', 'utf8'));
            
            const output = `#### Terraform Plan for \`${{ matrix.directory }}\`
            \`\`\`
            Resources: ${plan.resource_changes.filter(r => r.change.actions.includes('create')).length} to create, 
                      ${plan.resource_changes.filter(r => r.change.actions.includes('update')).length} to update, 
                      ${plan.resource_changes.filter(r => r.change.actions.includes('delete')).length} to delete
            \`\`\`
            
            <details><summary>Show Details</summary>
            
            \`\`\`json
            ${JSON.stringify(plan.resource_changes, null, 2)}
            \`\`\`
            
            </details>`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

  apply:
    needs: [detect-changes, plan]
    if: |
      needs.detect-changes.outputs.has-changes == 'true' &&
      github.ref == 'refs/heads/main' &&
      github.event_name == 'push'
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
      max-parallel: 1  # Apply changes sequentially to avoid conflicts
    environment:
      name: production
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Setup Terragrunt
        run: |
          wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Download Plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan-${{ hashFiles(matrix.directory) }}
          path: ${{ matrix.directory }}

      - name: Terragrunt Apply
        run: |
          cd ${{ matrix.directory }}
          terragrunt apply tfplan -auto-approve -input=false

      - name: Slack Notification
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            Deployment ${{ job.status }} for ${{ matrix.directory }}
            Commit: ${{ github.sha }}
            Author: ${{ github.actor }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}

  drift-detection:
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}

      - name: Setup tools
        run: |
          # Install Terraform and Terragrunt
          wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
          unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
          sudo mv terraform /usr/local/bin/
          
          wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Detect drift
        run: |
          # Find all terragrunt.hcl files and check for drift
          find infrastructure -name "terragrunt.hcl" -type f | while read -r config; do
            dir=$(dirname "$config")
            echo "Checking drift in $dir"
            cd "$dir"
            
            terragrunt plan -detailed-exitcode || exit_code=$?
            if [ "$exit_code" == "2" ]; then
              echo "::warning::Drift detected in $dir"
            fi
            
            cd - > /dev/null
          done
```

## Avoiding Anti-Patterns

### Terraform/Terragrunt Best Practices

1. **DRY Principle**
   - Use Terragrunt's `include` blocks to avoid duplication
   - Create `_envcommon` directory for shared configurations
   - Leverage `dependency` blocks instead of hard-coding values

2. **State Management**
   - Always use remote state with S3 and DynamoDB locking
   - Enable state file encryption
   - Use separate state files per component (avoid monolithic state)
   - Enable versioning on S3 state bucket

3. **Module Versioning**
   - Pin all module versions explicitly
   - Use semantic versioning for internal modules
   - Test module updates in dev environment first

4. **Security**
   - Never commit secrets to version control
   - Use AWS Secrets Manager or Parameter Store
   - Enable default encryption for all resources
   - Use assume role for cross-account access

5. **Resource Naming**
   - Use consistent naming conventions
   - Include environment and region in resource names
   - Avoid special characters that might cause issues

6. **Dependency Management**
   - Use Terragrunt's `dependency` blocks
   - Implement `mock_outputs` for plan operations
   - Order dependencies correctly to avoid cycles

7. **Error Handling**
   - Implement retry logic for transient failures
   - Use `prevent_destroy` lifecycle for critical resources
   - Implement proper error messages in validations

### Common Anti-Patterns to Avoid

1. **❌ Hardcoding Values**
   ```hcl
   # Bad
   vpc_id = "vpc-12345678"
   
   # Good
   vpc_id = dependency.vpc.outputs.vpc_id
   ```

2. **❌ Not Using Data Sources**
   ```hcl
   # Bad
   ami = "ami-12345678"
   
   # Good
   data "aws_ami" "latest" {
     most_recent = true
     owners      = ["amazon"]
     # filters...
   }
   ```

3. **❌ Ignoring Cost Optimization**
   - Always use lifecycle policies for S3
   - Implement auto-scaling for compute resources
   - Use spot instances where appropriate
   - Enable CloudWatch log retention policies

4. **❌ Poor Secret Management**
   ```hcl
   # Bad
   password = "hardcoded_password"
   
   # Good
   password = random_password.this.result
   # Store in Secrets Manager
   ```

5. **❌ Not Planning for Disaster Recovery**
   - Always enable backups
   - Implement cross-region replication for critical data
   - Document RTO/RPO requirements
   - Test disaster recovery procedures

## Performance Optimization for AI Workloads

### Compute Optimization
- Use GPU-enabled instances for ML inference (g4dn family)
- Implement request batching for efficiency
- Use ECS capacity providers for cost optimization
- Enable container insights for performance monitoring

### Storage Optimization
- Use S3 Intelligent-Tiering for model artifacts
- Implement CloudFront for model distribution
- Use EFS for shared model storage across containers
- Enable S3 Transfer Acceleration for large uploads

### Network Optimization
- Use VPC endpoints to reduce latency
- Implement CloudFront for global distribution
- Use AWS Global Accelerator for consistent performance
- Enable enhanced networking on EC2 instances

### Database Optimization
- Use Aurora Serverless v2 for variable workloads
- Implement read replicas for read-heavy operations
- Use ElastiCache for session management
- Enable query performance insights

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Infrastructure Metrics**
   - CPU/Memory utilization
   - Network throughput
   - Disk I/O
   - API Gateway latency

2. **Application Metrics**
   - Request rate
   - Error rate
   - Response time
   - Queue depth

3. **Business Metrics**
   - Active users
   - API calls per second
   - Model inference time
   - Cost per request

### Alerting Strategy

```yaml
alerts:
  - name: high-cpu-utilization
    metric: CPUUtilization
    threshold: 80
    evaluationPeriods: 2
    period: 300
    
  - name: high-error-rate
    metric: 4XXError
    threshold: 10
    evaluationPeriods: 1
    period: 60
    
  - name: database-connection-pool
    metric: DatabaseConnections
    threshold: 80
    evaluationPeriods: 2
    period: 300
```

## Cost Management

### Cost Optimization Strategies

1. **Reserved Capacity**
   - Purchase Reserved Instances for baseline capacity
   - Use Savings Plans for compute resources
   - Reserve Aurora capacity for production

2. **Auto-scaling**
   - Scale down during off-peak hours
   - Use predictive scaling for known patterns
   - Implement proper cooldown periods

3. **Resource Tagging**
   - Tag all resources for cost allocation
   - Use AWS Cost Explorer for analysis
   - Set up budget alerts

4. **Storage Optimization**
   - Use lifecycle policies aggressively
   - Compress data before storage
   - Delete unused snapshots and AMIs

## Security Hardening

### Security Checklist

- [ ] Enable GuardDuty for threat detection
- [ ] Configure AWS Config for compliance
- [ ] Enable CloudTrail for audit logging
- [ ] Implement AWS SSO for access management
- [ ] Use AWS Security Hub for centralized security
- [ ] Enable AWS Shield for DDoS protection
- [ ] Configure AWS Backup for automated backups
- [ ] Implement AWS Systems Manager for patch management
- [ ] Use AWS Certificate Manager for SSL/TLS
- [ ] Enable VPC Flow Logs for network monitoring

## Deployment Strategy

### Blue-Green Deployment

1. Deploy new version to green environment
2. Run smoke tests and validation
3. Switch traffic using Route 53 weighted routing
4. Monitor metrics and error rates
5. Keep blue environment for quick rollback

### Canary Deployment

1. Deploy to small percentage of traffic (5-10%)
2. Monitor error rates and performance
3. Gradually increase traffic percentage
4. Full deployment after validation
5. Automated rollback on threshold breach

## Disaster Recovery Plan

### RTO: 1 hour, RPO: 15 minutes

1. **Backup Strategy**
   - Continuous replication to secondary region
   - Automated snapshots every 15 minutes
   - Cross-region backup copies

2. **Failover Process**
   - Health checks via Route 53
   - Automatic failover to secondary region
   - Database promotion in secondary region
   - DNS update for traffic routing

3. **Recovery Testing**
   - Monthly DR drills
   - Documented runbooks
   - Automated recovery scripts
   - Communication plan

## Maintenance and Updates

### Regular Maintenance Tasks

1. **Weekly**
   - Review CloudWatch alarms
   - Check for security updates
   - Analyze cost reports

2. **Monthly**
   - Update container images
   - Review and rotate secrets
   - Performance optimization review
   - Disaster recovery testing

3. **Quarterly**
   - Update Terraform modules
   - Security audit
   - Capacity planning review
   - Architecture review

## Conclusion

This architecture provides a robust, scalable, and secure foundation for AI tool deployment on AWS using Terragrunt. The modular approach ensures maintainability, while the comprehensive CI/CD pipeline enables safe and efficient deployments. Regular monitoring, cost optimization, and security reviews ensure the infrastructure remains efficient and secure over time.