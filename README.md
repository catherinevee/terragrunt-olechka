# Olechka AWS Environment - Terragrunt Project

This project contains a complete, production-ready AWS environment infrastructure defined using Terragrunt and Terraform modules from the Terraform Registry.

## 🏗️ Architecture Overview

The environment is designed as a multi-tier application with the following components:

### Core Infrastructure
- **VPC** with public and private subnets across 3 availability zones
- **NAT Gateways** for private subnet internet access
- **Security Groups** with least-privilege access rules
- **Application Load Balancer** for traffic distribution

### Application Layer
- **EC2 Instances** running Apache web servers
- **Auto Scaling Groups** for high availability
- **Target Groups** for load balancer health checks

### Data Layer
- **RDS PostgreSQL** database with encryption and monitoring
- **S3 Buckets** for application data and logs
- **Lifecycle Policies** for cost optimization

### Security & Compliance
- **WAF** with AWS managed rules
- **Inspector** for security assessments
- **Macie** for data discovery and protection
- **IAM Roles** with least privilege access
- **Encryption** at rest and in transit

## 📁 Project Structure

```
terragrunt-olechka/
├── common.hcl                           # Common variables and configuration
├── terragrunt.hcl                       # Root Terragrunt configuration
├── eu-west-1/                           # eu-west-1 region environment
│   ├── README.md                        # Environment-specific documentation
│   ├── deploy.sh                        # Bash deployment script
│   ├── deploy.ps1                       # PowerShell deployment script
│   ├── terragrunt.hcl                   # Environment root configuration
│   ├── _envcommon/                      # Common environment configuration
│   │   ├── provider.hcl                 # AWS provider configuration
│   │   └── versions.hcl                 # Terraform and provider versions
│   ├── network/                         # Networking components
│   │   ├── vpc/                         # VPC and subnets
│   │   ├── securitygroup/               # Security groups
│   │   └── elb/                         # Application Load Balancer
│   ├── compute/                         # Compute resources
│   │   └── ec2/                         # EC2 instances
│   ├── database/                        # Database resources
│   │   └── rds/                         # RDS PostgreSQL
│   ├── storage/                         # Storage resources
│   │   ├── s3/                          # Application data bucket
│   │   └── s3-logs/                     # Logs bucket
│   ├── iam/                             # Identity and Access Management
│   │   └── role/                        # IAM roles
│   └── security/                        # Security services
│       ├── waf/                         # Web Application Firewall
│       ├── inspector/                   # Security Inspector
│       └── macie/                       # Data discovery and protection
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terragrunt** installed (version 0.54.0 or later)
3. **Terraform** installed (version 1.13.0)
4. **AWS Account** with appropriate permissions

### Configuration

1. **Update AWS Account ID**: Edit `common.hcl` and replace `123456789012` with your actual AWS account ID.

2. **Create SSH Key Pair**: Create an SSH key pair named "olechka-key" in the AWS console.

3. **SSL Certificate**: Create or import an SSL certificate in AWS Certificate Manager and update the ARN in `eu-west-1/network/elb/terragrunt.hcl`.

### Deployment

#### Option 1: Using Deployment Scripts

**Linux/macOS:**
```bash
cd eu-west-1
chmod +x deploy.sh
./deploy.sh
```

**Windows:**
```powershell
cd eu-west-1
.\deploy.ps1
```

#### Option 2: Manual Deployment

```bash
# Navigate to the environment directory
cd eu-west-1

# Deploy all modules
terragrunt run-all apply

# Or deploy specific modules
cd network/vpc
terragrunt apply

cd ../compute/ec2
terragrunt apply
```

## 🔧 Configuration Details

### Terraform Modules Used

All modules are sourced from the Terraform Registry for reliability and maintenance:

- **VPC**: `terraform-aws-modules/vpc/aws` (v5.8.1)
- **Security Groups**: `terraform-aws-modules/security-group/aws` (v5.1.2)
- **EC2**: `terraform-aws-modules/ec2-instance/aws` (v5.6.1)
- **RDS**: `terraform-aws-modules/rds/aws` (v6.6.0)
- **S3**: `terraform-aws-modules/s3-bucket/aws` (v4.1.2)
- **ALB**: `terraform-aws-modules/alb/aws` (v9.9.2)
- **WAF**: `terraform-aws-modules/waf/aws` (v1.0.0)
- **IAM**: `terraform-aws-modules/iam/aws` (v5.30.0)

### Provider Configuration

- **AWS Provider**: Version 6.2.0
- **Terraform**: Version 1.13.0
- **Region**: eu-west-1 (Ireland)

### Security Features

- **Encryption at Rest**: All storage and databases encrypted with AWS KMS
- **Encryption in Transit**: HTTPS/TLS for all web traffic
- **Network Security**: Private subnets with controlled internet access
- **Access Control**: IAM roles with least privilege principle
- **Web Protection**: WAF with AWS managed security rules
- **Security Monitoring**: Continuous security assessment with Inspector and Macie

## 📊 Monitoring and Logging

### CloudWatch Integration
- **Metrics**: Automatic collection for all AWS services
- **Logs**: Centralized logging for applications and infrastructure
- **Alarms**: Configurable alarms for critical metrics

### RDS Performance Insights
- **Database Monitoring**: Real-time database performance metrics
- **Query Analysis**: Slow query identification and optimization

### ALB Access Logs
- **Traffic Analysis**: Detailed request logs for load balancer
- **Security Monitoring**: Detection of suspicious traffic patterns

## 💰 Cost Optimization

### Resource Sizing
- **t3.micro instances**: Cost-effective for development and testing
- **db.t3.micro RDS**: Small database instances for non-production
- **S3 Lifecycle Policies**: Automatic data tiering to reduce costs

### Recommendations for Production
- **Reserved Instances**: Purchase reserved instances for predictable workloads
- **Auto Scaling**: Implement auto scaling based on demand
- **RDS Multi-AZ**: Enable multi-AZ for high availability
- **CloudFront**: Add CDN for global content delivery

## 🔍 Troubleshooting

### Common Issues

1. **Certificate ARN Error**
   - Ensure SSL certificate exists in ACM
   - Verify certificate ARN in ALB configuration

2. **Key Pair Not Found**
   - Create SSH key pair named "olechka-key"
   - Ensure key pair exists in eu-west-1 region

3. **IAM Permissions**
   - Verify AWS credentials have sufficient permissions
   - Check CloudTrail for permission denied errors

4. **VPC Dependency Issues**
   - Deploy VPC first before other resources
   - Verify subnet configurations

### Debug Commands

```bash
# Check Terragrunt configuration
terragrunt validate-inputs

# View planned changes
terragrunt plan

# Check AWS credentials
aws sts get-caller-identity

# View CloudWatch logs
aws logs describe-log-groups
```

## 🧹 Cleanup

To destroy the entire environment:

```bash
cd eu-west-1
terragrunt run-all destroy
```

**⚠️ Warning**: This will permanently delete all resources and data.

## 📚 Additional Resources

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-learning/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS service documentation
3. Check CloudWatch logs and metrics
4. Verify IAM permissions and policies

---

**Note**: This infrastructure is designed for educational and development purposes. For production use, please review and adjust security configurations, resource sizing, and backup strategies according to your specific requirements.