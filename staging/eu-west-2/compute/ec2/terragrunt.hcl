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
  name = "olechka-staging-app-server"

  # Enhanced instance configuration for staging
  instance_type               = "t3.medium"
  key_name                    = "olechka-staging-key"
  monitoring                  = true
  vpc_security_group_ids      = [dependency.security_group.outputs.security_group_id]
  subnet_id                   = dependency.vpc.outputs.private_subnets[0]

  # Enhanced user data for staging environment
  user_data = <<-EOF
              #!/bin/bash
              # Update system
              yum update -y
              
              # Install staging tools and dependencies
              yum install -y httpd git nodejs npm docker python3-pip
              systemctl start httpd
              systemctl enable httpd
              systemctl start docker
              systemctl enable docker
              
              # Install monitoring and observability tools
              yum install -y amazon-cloudwatch-agent
              pip3 install awscli boto3
              
              # Install additional monitoring tools
              yum install -y htop iotop nethogs
              
              # Create application directory
              mkdir -p /var/www/olechka-app
              cd /var/www/olechka-app
              
              # Clone application repository (placeholder)
              # git clone https://github.com/olechka/olechka-app.git .
              # git checkout staging
              
              # Install Node.js dependencies
              # npm install
              # npm run build
              
              # Create staging web page
              echo "<h1>Welcome to Olechka's Staging Environment!</h1>" > /var/www/html/index.html
              echo "<p>Environment: Staging</p>" >> /var/www/html/index.html
              echo "<p>Region: eu-west-2</p>" >> /var/www/html/index.html
              echo "<p>Instance Type: t3.medium</p>" >> /var/www/html/index.html
              echo "<p>Timestamp: $(date)</p>" >> /var/www/html/index.html
              echo "<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" >> /var/www/html/index.html
              echo "<p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>" >> /var/www/html/index.html
              
              # Configure CloudWatch agent for comprehensive monitoring
              cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/httpd/access_log",
                          "log_group_name": "/aws/ec2/olechka-staging/httpd-access",
                          "log_stream_name": "{instance_id}"
                        },
                        {
                          "file_path": "/var/log/httpd/error_log",
                          "log_group_name": "/aws/ec2/olechka-staging/httpd-error",
                          "log_stream_name": "{instance_id}"
                        },
                        {
                          "file_path": "/var/log/messages",
                          "log_group_name": "/aws/ec2/olechka-staging/system-logs",
                          "log_stream_name": "{instance_id}"
                        },
                        {
                          "file_path": "/var/log/secure",
                          "log_group_name": "/aws/ec2/olechka-staging/security-logs",
                          "log_stream_name": "{instance_id}"
                        }
                      ]
                    }
                  }
                },
                "metrics": {
                  "metrics_collected": {
                    "disk": {
                      "measurement": ["used_percent"],
                      "metrics_collection_interval": 60,
                      "resources": ["*"]
                    },
                    "mem": {
                      "measurement": ["mem_used_percent"],
                      "metrics_collection_interval": 60
                    }
                  }
                }
              }
              CWCONFIG
              
              # Start CloudWatch agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              systemctl start amazon-cloudwatch-agent
              systemctl enable amazon-cloudwatch-agent
              
              # Create comprehensive health check endpoint
              cat > /var/www/cgi-bin/health <<'HEALTH'
              #!/bin/bash
              echo "Content-Type: text/plain"
              echo ""
              echo "OK"
              echo "Instance: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
              echo "AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
              echo "Timestamp: $(date)"
              echo "Uptime: $(uptime)"
              echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
              echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
              HEALTH
              chmod +x /var/www/cgi-bin/health
              
              # Create detailed status endpoint
              cat > /var/www/cgi-bin/status <<'STATUS'
              #!/bin/bash
              echo "Content-Type: application/json"
              echo ""
              echo "{"
              echo "  \"status\": \"healthy\","
              echo "  \"instance_id\": \"$(curl -s http://169.254.169.254/latest/meta-data/instance-id)\","
              echo "  \"availability_zone\": \"$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)\","
              echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
              echo "  \"uptime\": \"$(uptime -p)\","
              echo "  \"memory_usage\": \"$(free -m | grep Mem | awk '{print int($3/$2 * 100)}')\","
              echo "  \"disk_usage\": \"$(df / | tail -1 | awk '{print $5}' | sed 's/%//')\","
              echo "  \"environment\": \"staging\""
              echo "}"
              STATUS
              chmod +x /var/www/cgi-bin/status
              
              # Configure log rotation
              cat > /etc/logrotate.d/olechka-app <<'LOGROTATE'
              /var/log/olechka-app/*.log {
                  daily
                  missingok
                  rotate 30
                  compress
                  delaycompress
                  notifempty
                  create 644 apache apache
                  postrotate
                      systemctl reload httpd
                  endscript
              }
              LOGROTATE
              
              # Create application log directory
              mkdir -p /var/log/olechka-app
              chown apache:apache /var/log/olechka-app
              
              # Set up cron jobs for maintenance
              echo "0 2 * * * /usr/sbin/logrotate /etc/logrotate.d/olechka-app" | crontab -
              echo "0 3 * * * yum update -y --security" | crontab -
              
              # Configure system limits for staging
              echo "apache soft nofile 65536" >> /etc/security/limits.conf
              echo "apache hard nofile 65536" >> /etc/security/limits.conf
              echo "apache soft nproc 32768" >> /etc/security/limits.conf
              echo "apache hard nproc 32768" >> /etc/security/limits.conf
              
              # Restart services
              systemctl restart httpd
              systemctl restart amazon-cloudwatch-agent
              EOF

  user_data_replace_on_change = true

  # Enhanced root block device configuration
  enable_volume_tags = true
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      throughput  = 500
      volume_size = 50
      tags = {
        Name = "olechka-staging-root-volume"
        Environment = "staging"
        Backup = "required"
        Encryption = "enabled"
      }
    }
  ]

  # Enhanced metadata options
  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags = "enabled"
  }

  # Enhanced monitoring and maintenance
  maintenance_options = {
    auto_recovery = "default"
  }

  # Enhanced CPU options for staging
  cpu_options = {
    core_count       = 2
    threads_per_core = 2
  }

  # Enhanced tagging
  tags = {
    Environment = "staging"
    Project     = "olechka"
    Owner       = "olechka"
    ManagedBy   = "terragrunt"
    CostCenter  = "staging-ops"
    DataClassification = "confidential"
    AutoShutdown = "false"
    Backup = "required"
    InstanceRole = "application-server"
    Monitoring = "enabled"
    HighAvailability = "enabled"
    Backup = "required"
    Encryption = "enabled"
  }
} 