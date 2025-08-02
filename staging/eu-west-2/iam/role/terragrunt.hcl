include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = "${get_terragrunt_dir()}/../_envcommon/provider.hcl"
}

include "versions" {
  path = "${get_terragrunt_dir()}/../_envcommon/versions.hcl"
}

terraform {
  source = "tfr://terraform-aws-modules/iam/aws//modules/iam-role?version=5.30.0"
}

inputs = {
  role_name = "olechka-staging-application-role"
  role_description = "Enhanced IAM role for staging application servers"

  # Enhanced trust policy
  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment" = "staging"
          }
        }
      }
    ]
  })

  # Enhanced managed policies
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  # Enhanced inline policies
  inline_policies = {
    application_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "arn:aws:s3:::olechka-staging-app-data-2024/*",
            "arn:aws:s3:::olechka-staging-logs-2024/*"
          ]
          Condition = {
            StringEquals = {
              "aws:RequestTag/Environment" = "staging"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "rds:DescribeDBInstances",
            "rds:DescribeDBClusters"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = [
            "arn:aws:logs:eu-west-2:*:log-group:/aws/ec2/olechka-staging/*",
            "arn:aws:logs:eu-west-2:*:log-group:/aws/rds/olechka-staging/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeInstances",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeVpcs"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ]
          Resource = "*"
        }
      ]
    })
  }

  # Enhanced permissions boundary
  permissions_boundary = "arn:aws:iam::123456789012:policy/olechka-staging-permissions-boundary"

  # Enhanced tags
  tags = {
    Environment = "staging"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "staging-ops"
    DataClassification = "confidential"
    AutoShutdown = "false"
    SecurityLevel = "enhanced"
    RoleType = "application-server"
    PermissionsBoundary = "enabled"
    HighAvailability = "enabled"
  }
} 