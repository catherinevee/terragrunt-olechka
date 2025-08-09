#!/usr/bin/env python3
"""
Terragrunt Configuration Security Audit Script
Automatically scans Terragrunt configurations for security issues and compliance violations
"""

import os
import re
import json
import glob
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Any
from dataclasses import dataclass
from enum import Enum

class Severity(Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"

@dataclass
class Finding:
    severity: Severity
    category: str
    issue: str
    location: str
    line_number: int
    impact: str
    recommendation: str
    code_snippet: str

class TerragruntSecurityAuditor:
    def __init__(self, root_path: str):
        self.root_path = Path(root_path)
        self.findings: List[Finding] = []
        
        # Security patterns to detect
        self.security_patterns = {
            'hardcoded_account_id': r'123456789012',
            'open_cidr': r'0\.0\.0\.0/0',
            'hardcoded_password': r'password\s*=\s*["\'][^"\']*["\']',
            'missing_encryption': r'encrypt\s*=\s*false',
            'no_mfa': r'role_requires_mfa\s*=\s*false',
            'wildcard_trust': r'arn:aws:iam::\*:root',
            'aes256_only': r'sse_algorithm\s*=\s*["\']AES256["\']',
            'skip_final_snapshot': r'skip_final_snapshot\s*=\s*true',
            'deletion_protection_off': r'deletion_protection\s*=\s*false'
        }
        
        # Required security flags for remote state
        self.required_state_flags = [
            'skip_bucket_ssencryption = false',
            'skip_bucket_enforced_tls = false', 
            'skip_bucket_public_access_blocking = false',
            'skip_bucket_versioning = false'
        ]

    def scan_file(self, file_path: Path) -> None:
        """Scan a single HCL file for security issues"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
                
            relative_path = file_path.relative_to(self.root_path)
            
            # Check each security pattern
            for pattern_name, pattern in self.security_patterns.items():
                matches = re.finditer(pattern, content, re.IGNORECASE | re.MULTILINE)
                for match in matches:
                    line_num = content[:match.start()].count('\n') + 1
                    line_content = lines[line_num - 1].strip()
                    
                    self.add_finding_for_pattern(
                        pattern_name, str(relative_path), line_num, line_content
                    )
            
            # Check for missing mock outputs in dependency blocks
            self.check_dependency_mock_outputs(content, str(relative_path))
            
            # Check remote state security
            if 'remote_state' in content:
                self.check_remote_state_security(content, str(relative_path))
                
        except Exception as e:
            print(f"Error scanning {file_path}: {e}")

    def add_finding_for_pattern(self, pattern_name: str, location: str, line_num: int, code: str) -> None:
        """Add finding based on detected pattern"""
        findings_map = {
            'hardcoded_account_id': Finding(
                severity=Severity.CRITICAL,
                category="Configuration Management",
                issue="Hardcoded placeholder AWS Account ID",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Configuration will fail in production, security policies reference non-existent resources",
                recommendation="Replace with get_env('AWS_ACCOUNT_ID') or AWS CLI lookup",
                code_snippet=code
            ),
            'open_cidr': Finding(
                severity=Severity.CRITICAL,
                category="Network Security",
                issue="Overly permissive CIDR block (0.0.0.0/0)",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Exposes infrastructure to internet-wide attacks",
                recommendation="Restrict to VPN/office IP ranges only",
                code_snippet=code
            ),
            'hardcoded_password': Finding(
                severity=Severity.CRITICAL,
                category="Secrets Management",
                issue="Hardcoded password in configuration",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Credential exposure, security breach risk",
                recommendation="Use AWS Secrets Manager or environment variables",
                code_snippet=code
            ),
            'no_mfa': Finding(
                severity=Severity.HIGH,
                category="Access Control",
                issue="MFA not required for IAM role assumption",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Unauthorized access if credentials compromised",
                recommendation="Set role_requires_mfa = true",
                code_snippet=code
            ),
            'wildcard_trust': Finding(
                severity=Severity.CRITICAL,
                category="Access Control",
                issue="IAM role trusts any AWS account (*)",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Privilege escalation risk from external accounts",
                recommendation="Restrict to specific account ARNs only",
                code_snippet=code
            ),
            'aes256_only': Finding(
                severity=Severity.HIGH,
                category="Encryption",
                issue="Using AWS managed encryption instead of customer-managed KMS",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Limited key rotation control, no fine-grained access control",
                recommendation="Use customer-managed KMS keys with sse_algorithm = 'aws:kms'",
                code_snippet=code
            ),
            'skip_final_snapshot': Finding(
                severity=Severity.HIGH,
                category="Data Protection",
                issue="Database final snapshot disabled",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Data loss risk during database deletion",
                recommendation="Set skip_final_snapshot = false and configure snapshot identifier",
                code_snippet=code
            ),
            'deletion_protection_off': Finding(
                severity=Severity.HIGH,
                category="Data Protection",
                issue="Database deletion protection disabled",
                location=f"{location}:{line_num}",
                line_number=line_num,
                impact="Accidental database deletion risk",
                recommendation="Set deletion_protection = true for production databases",
                code_snippet=code
            )
        }
        
        if pattern_name in findings_map:
            self.findings.append(findings_map[pattern_name])

    def check_dependency_mock_outputs(self, content: str, location: str) -> None:
        """Check for missing mock outputs in dependency blocks"""
        dependency_blocks = re.findall(r'dependency\s+"[^"]+"\s*\{([^}]+)\}', content, re.DOTALL)
        
        for i, block in enumerate(dependency_blocks):
            if 'mock_outputs' not in block:
                self.findings.append(Finding(
                    severity=Severity.HIGH,
                    category="Dependency Management",
                    issue="Missing mock outputs in dependency block",
                    location=f"{location}:dependency_block_{i+1}",
                    line_number=0,
                    impact="Terragrunt plan/init failures when dependencies don't exist",
                    recommendation="Add mock_outputs with expected output structure",
                    code_snippet=block[:100] + "..."
                ))

    def check_remote_state_security(self, content: str, location: str) -> None:
        """Check remote state security configuration"""
        if 'remote_state' in content:
            for flag in self.required_state_flags:
                if flag not in content:
                    self.findings.append(Finding(
                        severity=Severity.CRITICAL,
                        category="State Security",
                        issue=f"Missing state security flag: {flag}",
                        location=location,
                        line_number=0,
                        impact="S3 state bucket vulnerable to unauthorized access",
                        recommendation=f"Add {flag} to remote_state config block",
                        code_snippet="remote_state { ... }"
                    ))

    def scan_directory(self) -> None:
        """Scan all HCL files in the directory tree"""
        hcl_files = list(self.root_path.rglob("*.hcl"))
        
        print(f"🔍 Scanning {len(hcl_files)} HCL files...")
        
        for file_path in hcl_files:
            self.scan_file(file_path)
        
        print(f"✅ Scan completed. Found {len(self.findings)} issues.")

    def generate_report(self) -> str:
        """Generate detailed security report"""
        # Group findings by severity
        critical = [f for f in self.findings if f.severity == Severity.CRITICAL]
        high = [f for f in self.findings if f.severity == Severity.HIGH]
        medium = [f for f in self.findings if f.severity == Severity.MEDIUM]
        low = [f for f in self.findings if f.severity == Severity.LOW]
        
        report = f"""
# Terragrunt Security Audit Report
Generated: {os.popen('date').read().strip()}

## Executive Summary
- 🔴 Critical Issues: {len(critical)}
- 🟠 High Priority: {len(high)}
- 🟡 Medium Priority: {len(medium)}
- 🟢 Low Priority: {len(low)}

**Risk Score: {self.calculate_risk_score()}/100**

## Critical Issues (Immediate Action Required)
"""
        
        for finding in critical:
            report += f"""
### {finding.issue}
**Location:** {finding.location}
**Impact:** {finding.impact}
**Code:** `{finding.code_snippet}`
**Fix:** {finding.recommendation}

"""
        
        report += "\n## High Priority Issues\n"
        for finding in high:
            report += f"""
### {finding.issue}
**Location:** {finding.location}
**Impact:** {finding.impact}
**Fix:** {finding.recommendation}

"""
        
        return report

    def calculate_risk_score(self) -> int:
        """Calculate overall risk score (0-100, higher = more risk)"""
        score = 0
        score += len([f for f in self.findings if f.severity == Severity.CRITICAL]) * 25
        score += len([f for f in self.findings if f.severity == Severity.HIGH]) * 15
        score += len([f for f in self.findings if f.severity == Severity.MEDIUM]) * 5
        score += len([f for f in self.findings if f.severity == Severity.LOW]) * 1
        
        return min(score, 100)

    def export_json(self, output_file: str) -> None:
        """Export findings as JSON for automation"""
        findings_data = []
        for finding in self.findings:
            findings_data.append({
                'severity': finding.severity.value,
                'category': finding.category,
                'issue': finding.issue,
                'location': finding.location,
                'line_number': finding.line_number,
                'impact': finding.impact,
                'recommendation': finding.recommendation,
                'code_snippet': finding.code_snippet
            })
        
        with open(output_file, 'w') as f:
            json.dump({
                'scan_date': os.popen('date -u +"%Y-%m-%dT%H:%M:%SZ"').read().strip(),
                'total_findings': len(self.findings),
                'risk_score': self.calculate_risk_score(),
                'findings': findings_data
            }, f, indent=2)

def main():
    parser = argparse.ArgumentParser(description='Terragrunt Security Auditor')
    parser.add_argument('--path', default='.', help='Path to scan (default: current directory)')
    parser.add_argument('--output', help='Output file for detailed report')
    parser.add_argument('--json', help='Export findings as JSON')
    parser.add_argument('--fix', action='store_true', help='Generate fix scripts')
    
    args = parser.parse_args()
    
    auditor = TerragruntSecurityAuditor(args.path)
    auditor.scan_directory()
    
    # Generate report
    report = auditor.generate_report()
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"📄 Detailed report saved to {args.output}")
    else:
        print(report)
    
    if args.json:
        auditor.export_json(args.json)
        print(f"📊 JSON export saved to {args.json}")
    
    # Print summary
    critical_count = len([f for f in auditor.findings if f.severity == Severity.CRITICAL])
    if critical_count > 0:
        print(f"\n🚨 URGENT: {critical_count} critical security issues found!")
        print("Run the emergency security fix script immediately.")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())