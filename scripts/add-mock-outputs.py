#!/usr/bin/env python3
"""
Mock Outputs Addition Script
Automatically adds mock outputs to all dependency blocks in Terragrunt configurations
"""

import os
import re
import shutil
from pathlib import Path

# Mock outputs templates
MOCK_OUTPUTS_TEMPLATES = {
    'vpc': '''
  mock_outputs = {
    vpc_id                      = "vpc-mock-12345678"
    vpc_arn                     = "arn:aws:ec2:region:account:vpc/vpc-mock-12345678"
    vpc_cidr_block             = "10.0.0.0/16"
    private_subnets            = ["subnet-mock-private-1", "subnet-mock-private-2", "subnet-mock-private-3"]
    public_subnets             = ["subnet-mock-public-1", "subnet-mock-public-2", "subnet-mock-public-3"]
    database_subnets           = ["subnet-mock-db-1", "subnet-mock-db-2", "subnet-mock-db-3"]
    private_subnets_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets_cidr_blocks  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    database_subnets_cidr_blocks = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
    nat_gateway_ids            = ["nat-mock-1", "nat-mock-2", "nat-mock-3"]
    internet_gateway_id        = "igw-mock-12345678"
    route_table_ids            = ["rt-mock-private-1", "rt-mock-private-2", "rt-mock-private-3"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"''',
    
    'security_group': '''
  mock_outputs = {
    security_group_id   = "sg-mock-12345678"
    security_group_arn  = "arn:aws:ec2:region:account:security-group/sg-mock-12345678"
    security_group_name = "mock-security-group"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"''',
    
    'kms': '''
  mock_outputs = {
    key_arn           = "arn:aws:kms:region:account:key/mock-key-id"
    key_id            = "mock-key-id"
    alias_arn         = "arn:aws:kms:region:account:alias/mock-alias"
    alias_name        = "alias/mock-alias"
    key_policy        = "{}"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"''',
    
    'iam': '''
  mock_outputs = {
    arn          = "arn:aws:iam::account:role/mock-role"
    name         = "mock-role"
    unique_id    = "AROAMOCK12345678"
    role_policy  = "{}"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"''',
    
    'alb': '''
  mock_outputs = {
    lb_arn      = "arn:aws:elasticloadbalancing:region:account:loadbalancer/app/mock-alb/1234567890123456"
    lb_dns_name = "mock-alb-1234567890.region.elb.amazonaws.com"
    lb_zone_id  = "Z123456789012345678901"
    target_group_arns = ["arn:aws:elasticloadbalancing:region:account:targetgroup/mock-tg/1234567890123456"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "show", "providers"]
  mock_outputs_merge_strategy_with_state  = "shallow"'''
}

def detect_dependency_type(dependency_name: str, config_path: str) -> str:
    """Detect the type of dependency based on name and path"""
    dependency_name = dependency_name.lower()
    config_path = config_path.lower()
    
    if 'vpc' in dependency_name or 'vpc' in config_path:
        return 'vpc'
    elif 'security' in dependency_name or 'securitygroup' in config_path:
        return 'security_group'
    elif 'kms' in dependency_name or 'kms' in config_path:
        return 'kms'
    elif 'iam' in dependency_name or 'iam' in config_path or 'role' in config_path:
        return 'iam'
    elif 'alb' in dependency_name or 'elb' in config_path or 'load' in config_path:
        return 'alb'
    else:
        return 'vpc'  # Default fallback

def add_mock_outputs_to_file(file_path: Path) -> bool:
    """Add mock outputs to dependency blocks in a file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Find dependency blocks without mock_outputs
        dependency_pattern = r'dependency\s+"([^"]+)"\s*\{([^}]+)\}'
        dependencies = re.findall(dependency_pattern, content, re.DOTALL)
        
        modified = False
        new_content = content
        
        for dep_name, dep_content in dependencies:
            if 'mock_outputs' not in dep_content:
                print(f"  📝 Adding mock outputs for dependency '{dep_name}'")
                
                # Extract config_path
                config_path_match = re.search(r'config_path\s*=\s*["\']([^"\']+)["\']', dep_content)
                config_path = config_path_match.group(1) if config_path_match else ""
                
                # Detect dependency type
                dep_type = detect_dependency_type(dep_name, config_path)
                mock_template = MOCK_OUTPUTS_TEMPLATES.get(dep_type, MOCK_OUTPUTS_TEMPLATES['vpc'])
                
                # Find the dependency block and add mock outputs
                old_block = f'dependency "{dep_name}" {{{dep_content}}}'
                new_block = f'dependency "{dep_name}" {{{dep_content.rstrip()}\n{mock_template}\n}}'
                
                new_content = new_content.replace(old_block, new_block)
                modified = True
        
        if modified:
            # Write the updated content
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            return True
            
    except Exception as e:
        print(f"  ❌ Error processing {file_path}: {e}")
        return False
    
    return False

def main():
    print("🔧 Mock Outputs Addition Script")
    print("Adding mock outputs to all dependency blocks...")
    print()
    
    # Find all terragrunt.hcl files
    hcl_files = list(Path('.').rglob('**/terragrunt.hcl'))
    
    # Filter out root files and templates
    hcl_files = [f for f in hcl_files if '_templates' not in str(f) and 'backup' not in str(f)]
    
    print(f"📁 Found {len(hcl_files)} terragrunt.hcl files")
    
    # Create backup
    backup_dir = f"mock-outputs-backup-{os.popen('date +%Y%m%d-%H%M%S').read().strip()}"
    os.makedirs(backup_dir, exist_ok=True)
    
    modified_files = []
    
    for file_path in hcl_files:
        print(f"\n🔍 Processing: {file_path}")
        
        # Create backup
        backup_path = Path(backup_dir) / file_path.name
        shutil.copy2(file_path, backup_path)
        
        # Add mock outputs
        if add_mock_outputs_to_file(file_path):
            modified_files.append(str(file_path))
            print(f"  ✅ Mock outputs added")
        else:
            print(f"  ℹ️  No changes needed")
    
    print(f"\n🎉 Processing completed!")
    print(f"📦 Backup created in: {backup_dir}")
    print(f"✅ Modified {len(modified_files)} files")
    
    if modified_files:
        print(f"\n📋 Modified files:")
        for file_path in modified_files:
            print(f"  - {file_path}")
        
        print(f"\n🚀 Next steps:")
        print("1. Review changes: git diff")
        print("2. Test configurations: terragrunt run-all plan")
        print("3. Apply if tests pass: terragrunt run-all apply")
    
    return 0

if __name__ == "__main__":
    exit(main())