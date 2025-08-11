#!/bin/bash
# Mass Security Group Remediation Script
# Fixes overly permissive security groups across all environments

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔒 Security Group Remediation Script${NC}"
echo "Fixing overly permissive security groups..."

# Define secure CIDR blocks
SECURE_CIDRS="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
OFFICE_CIDR="${OFFICE_CIDR:-203.0.113.0/24}"  # Set this environment variable

# Find all security group files
SG_FILES=$(find . -path "*/network/securitygroup/terragrunt.hcl" -type f)

echo -e "${YELLOW}📁 Found security group files:${NC}"
echo "$SG_FILES"
echo

# Backup security group files
BACKUP_DIR="sg-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

for file in $SG_FILES; do
    cp "$file" "$BACKUP_DIR/$(basename $(dirname $(dirname $file)))-$(basename $(dirname $file))-terragrunt.hcl"
done

echo -e "${GREEN}✅ Backup created in $BACKUP_DIR${NC}"

# Fix each security group file
for file in $SG_FILES; do
    echo -e "${YELLOW}🔧 Processing: $file${NC}"
    
    # Check if file has 0.0.0.0/0
    if grep -q "0\.0\.0\.0/0" "$file"; then
        echo -e "${RED}  ❌ Found overly permissive rules${NC}"
        
        # Create temporary file with fixes
        temp_file=$(mktemp)
        
        # Replace SSH access (port 22) with restricted access
        sed 's/cidr_blocks = "0\.0\.0\.0\/0"/cidr_blocks = "'$SECURE_CIDRS','$OFFICE_CIDR'"/g' "$file" > "$temp_file"
        
        # For HTTP/HTTPS on ALB security groups, keep 0.0.0.0/0 but add comments
        if [[ $file == *"elb"* ]] || [[ $file == *"alb"* ]]; then
            sed -i 's/cidr_blocks = "'$SECURE_CIDRS','$OFFICE_CIDR'"/cidr_blocks = "0.0.0.0\/0"  # ALB: Internet access required/g' "$temp_file"
        fi
        
        # Move temp file back
        mv "$temp_file" "$file"
        
        echo -e "${GREEN}  ✅ Fixed overly permissive rules${NC}"
    else
        echo -e "${GREEN}  ✅ No issues found${NC}"
    fi
done

echo
echo -e "${GREEN}🎉 Security group remediation completed!${NC}"
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Review changes: git diff"
echo "2. Test configuration: terragrunt run-all plan"
echo "3. Apply changes: terragrunt run-all apply"
echo
echo -e "${RED}⚠️  Remember to update OFFICE_CIDR environment variable with your actual office IP range${NC}"