include "root" {
  path = find_in_parent_folders()
}

include "provider" {
  path = "${get_terragrunt_dir()}/../_envcommon/provider.hcl"
}

include "versions" {
  path = "${get_terragrunt_dir()}/../_envcommon/versions.hcl"
}

dependency "vpc" {
  config_path = "../../network/vpc"
}

dependency "security_group" {
  config_path = "../../network/securitygroup"
}

terraform {
  source = "tfr://terraform-aws-modules/ec2-instance/aws//?version=5.6.1"
}

inputs = {
  name = "olechka-dev-app-server"

  # Enhanced instance configuration for dev
  instance_type               = "t3.small"
  key_name                    = "olechka-dev-key"
  monitoring                  = true
  vpc_security_group_ids      = [dependency.security_group.outputs.security_group_id]
  subnet_id                   = dependency.vpc.outputs.private_subnets[0]

  # Enhanced user data for dev environment
  user_data = <<-EOF
              #!/bin/bash
              # Update system
              yum update -y
              
              # Install development tools
              yum install -y httpd git nodejs npm docker
              systemctl start httpd
              systemctl enable httpd
              systemctl start docker
              systemctl enable docker
              
              # Install monitoring tools
              yum install -y amazon-cloudwatch-agent
              
              # Create application directory
              mkdir -p /var/www/olechka-app
              cd /var/www/olechka-app
              
              # Clone application repository (placeholder)
              # git clone https://github.com/olechka/olechka-app.git .
              
              # Install Node.js dependencies
              # npm install
              
              # Create simple web page for testing
              echo "<h1>Hello from Olechka's Development Environment!</h1>" > /var/www/html/index.html
              echo "<p>Environment: Development</p>" >> /var/www/html/index.html
              echo "<p>Region: eu-west-2</p>" >> /var/www/html/index.html
              echo "<p>Instance Type: t3.small</p>" >> /var/www/html/index.html
              echo "<p>Timestamp: $(date)</p>" >> /var/www/html/index.html
              
              # Configure CloudWatch agent
              cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/httpd/access_log",
                          "log_group_name": "/aws/ec2/olechka-dev/httpd-access",
                          "log_stream_name": "{instance_id}"
                        },
                        {
                          "file_path": "/var/log/httpd/error_log",
                          "log_group_name": "/aws/ec2/olechka-dev/httpd-error",
                          "log_stream_name": "{instance_id}"
                        }
                      ]
                    }
                  }
                }
              }
              CWCONFIG
              
              # Start CloudWatch agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              systemctl start amazon-cloudwatch-agent
              systemctl enable amazon-cloudwatch-agent
              
              # Create health check endpoint
              echo "#!/bin/bash" > /var/www/cgi-bin/health
              echo "echo 'Content-Type: text/plain'" >> /var/www/cgi-bin/health
              echo "echo ''" >> /var/www/cgi-bin/health
              echo "echo 'OK'" >> /var/www/cgi-bin/health
              chmod +x /var/www/cgi-bin/health
              EOF

  user_data_replace_on_change = true

  # Enhanced root block device configuration
  enable_volume_tags = true
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      throughput  = 300
      volume_size = 30
      tags = {
        Name = "olechka-dev-root-volume"
        Environment = "development"
        Backup = "true"
      }
    }
  ]

  # Enhanced metadata options
  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }

  # Enhanced monitoring and maintenance
  maintenance_options = {
    auto_recovery = "default"
  }

  # Enhanced tagging
  tags = {
    Environment = "development"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "dev-ops"
    DataClassification = "internal"
    AutoShutdown = "true"
    Backup = "true"
    InstanceRole = "application-server"
    Monitoring = "enabled"
  }
} 