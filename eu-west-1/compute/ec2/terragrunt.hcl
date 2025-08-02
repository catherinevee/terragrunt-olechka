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
  name = "olechka-app-server"

  instance_type               = "t3.micro"
  key_name                    = "olechka-key"
  monitoring                  = true
  vpc_security_group_ids      = [dependency.security_group.outputs.security_group_id]
  subnet_id                   = dependency.vpc.outputs.private_subnets[0]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Olechka's AWS Environment!</h1>" > /var/www/html/index.html
              EOF

  user_data_replace_on_change = true

  enable_volume_tags = true
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      throughput  = 200
      volume_size = 20
      tags = {
        Name = "olechka-root-volume"
      }
    }
  ]

  tags = {
    Environment = "production"
    Project     = "olechka"
    Owner       = "olechka"
  }
} 