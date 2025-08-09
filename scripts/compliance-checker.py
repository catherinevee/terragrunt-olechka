#!/usr/bin/env python3
"""
Terragrunt Compliance Checker
Validates Terragrunt configurations against security frameworks and compliance standards
"""

import os
import re
import json
import yaml
import argparse
from pathlib import Path
from typing import Dict, List, Any
from dataclasses import dataclass, asdict
from enum import Enum

class ComplianceFramework(Enum):
    SOC2 = "SOC2"
    ISO27001 = "ISO27001"
    AWS_WELL_ARCHITECTED = "AWS_Well_Architected"
    NIST_CSF = "NIST_CSF"
    PCI_DSS = "PCI_DSS"

@dataclass
class ComplianceCheck:
    framework: ComplianceFramework
    control_id: str
    control_name: str
    requirement: str
    status: str  # PASS, FAIL, PARTIAL, NOT_APPLICABLE
    evidence: List[str]
    recommendations: List[str]
    risk_level: str

class TerragruntComplianceChecker:
    def __init__(self, root_path: str):
        self.root_path = Path(root_path)
        self.checks: List[ComplianceCheck] = []
        
        # Load compliance frameworks
        self.frameworks = {
            ComplianceFramework.SOC2: self.load_soc2_controls(),
            ComplianceFramework.ISO27001: self.load_iso27001_controls(),
            ComplianceFramework.AWS_WELL_ARCHITECTED: self.load_aws_wa_controls(),
        }

    def load_soc2_controls(self) -> Dict[str, Any]:
        """Load SOC 2 security controls"""
        return {
            "CC6.1": {
                "name": "Logical and Physical Access Controls",
                "requirements": [
                    "Multi-factor authentication for privileged access",
                    "Encryption of data in transit and at rest",
                    "Access logging and monitoring"
                ]
            },
            "CC6.2": {
                "name": "System Access Controls", 
                "requirements": [
                    "User access provisioning and deprovisioning",
                    "Privileged access management",
                    "Access review procedures"
                ]
            },
            "CC6.3": {
                "name": "Data Protection",
                "requirements": [
                    "Encryption key management",
                    "Data classification and handling",
                    "Secure data disposal"
                ]
            },
            "CC7.1": {
                "name": "System Monitoring",
                "requirements": [
                    "Security monitoring and alerting",
                    "Log management and retention",
                    "Incident response procedures"
                ]
            }
        }

    def load_iso27001_controls(self) -> Dict[str, Any]:
        """Load ISO 27001 controls"""
        return {
            "A.9.1.1": {
                "name": "Access Control Policy",
                "requirements": [
                    "Documented access control policy",
                    "Regular access reviews",
                    "Principle of least privilege"
                ]
            },
            "A.10.1.1": {
                "name": "Cryptographic Controls",
                "requirements": [
                    "Encryption of sensitive data",
                    "Key management procedures",
                    "Cryptographic key lifecycle"
                ]
            },
            "A.12.4.1": {
                "name": "Event Logging",
                "requirements": [
                    "Security event logging",
                    "Log protection and retention",
                    "Regular log review"
                ]
            }
        }

    def load_aws_wa_controls(self) -> Dict[str, Any]:
        """Load AWS Well-Architected Framework controls"""
        return {
            "SEC-01": {
                "name": "Identity and Access Management",
                "requirements": [
                    "Strong identity foundation",
                    "Principle of least privilege",
                    "Multi-factor authentication"
                ]
            },
            "SEC-02": {
                "name": "Detective Controls",
                "requirements": [
                    "Configure service and application logging",
                    "Analyze logs centrally",
                    "Automate response to events"
                ]
            },
            "SEC-03": {
                "name": "Infrastructure Protection",
                "requirements": [
                    "Control traffic at all layers",
                    "Automate network protection",
                    "Implement inspection and protection"
                ]
            },
            "SEC-04": {
                "name": "Data Protection in Transit and at Rest",
                "requirements": [
                    "Implement secure key management",
                    "Enforce encryption in transit",
                    "Automate data at rest encryption"
                ]
            }
        }

    def check_mfa_requirements(self) -> None:
        """Check MFA requirements across configurations"""
        hcl_files = list(self.root_path.rglob("**/iam/**/terragrunt.hcl"))
        
        evidence = []
        failed_files = []
        
        for file_path in hcl_files:
            try:
                with open(file_path, 'r') as f:
                    content = f.read()
                    
                if 'role_requires_mfa = true' in content:
                    evidence.append(f"MFA enabled in {file_path.relative_to(self.root_path)}")
                elif 'role_requires_mfa = false' in content:
                    failed_files.append(str(file_path.relative_to(self.root_path)))
                    
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
        
        status = "PASS" if not failed_files else "FAIL"
        
        self.checks.append(ComplianceCheck(
            framework=ComplianceFramework.SOC2,
            control_id="CC6.1",
            control_name="Multi-Factor Authentication",
            requirement="MFA required for privileged access",
            status=status,
            evidence=evidence,
            recommendations=[
                "Enable MFA for all IAM roles: role_requires_mfa = true",
                "Implement MFA for Terragrunt execution in CI/CD"
            ] if failed_files else [],
            risk_level="HIGH" if failed_files else "LOW"
        ))

    def check_encryption_at_rest(self) -> None:
        """Check encryption at rest implementation"""
        evidence = []
        issues = []
        
        # Check RDS encryption
        rds_files = list(self.root_path.rglob("**/database/**/terragrunt.hcl"))
        for file_path in rds_files:
            with open(file_path, 'r') as f:
                content = f.read()
                
            if 'storage_encrypted = true' in content:
                evidence.append(f"RDS encryption enabled in {file_path.relative_to(self.root_path)}")
            else:
                issues.append(f"RDS encryption missing in {file_path.relative_to(self.root_path)}")
        
        # Check S3 encryption
        s3_files = list(self.root_path.rglob("**/storage/**/terragrunt.hcl"))
        for file_path in s3_files:
            with open(file_path, 'r') as f:
                content = f.read()
                
            if 'sse_algorithm' in content:
                if 'aws:kms' in content:
                    evidence.append(f"S3 KMS encryption in {file_path.relative_to(self.root_path)}")
                elif 'AES256' in content:
                    issues.append(f"S3 using AWS managed encryption in {file_path.relative_to(self.root_path)}")
        
        status = "PASS" if not issues else "PARTIAL" if evidence else "FAIL"
        
        self.checks.append(ComplianceCheck(
            framework=ComplianceFramework.SOC2,
            control_id="CC6.3",
            control_name="Data Protection - Encryption at Rest",
            requirement="All sensitive data encrypted at rest with customer-managed keys",
            status=status,
            evidence=evidence,
            recommendations=[
                "Enable storage_encrypted = true for all RDS instances",
                "Use customer-managed KMS keys for S3 encryption",
                "Implement key rotation policies"
            ] if issues else [],
            risk_level="HIGH" if issues else "LOW"
        ))

    def check_network_security(self) -> None:
        """Check network security controls"""
        evidence = []
        violations = []
        
        sg_files = list(self.root_path.rglob("**/securitygroup/**/terragrunt.hcl"))
        
        for file_path in sg_files:
            with open(file_path, 'r') as f:
                content = f.read()
                
            # Check for overly permissive rules
            if re.search(r'cidr_blocks.*=.*["\']0\.0\.0\.0/0["\']', content):
                violations.append(f"Open CIDR block in {file_path.relative_to(self.root_path)}")
            else:
                evidence.append(f"Restricted access in {file_path.relative_to(self.root_path)}")
        
        status = "FAIL" if violations else "PASS"
        
        self.checks.append(ComplianceCheck(
            framework=ComplianceFramework.AWS_WELL_ARCHITECTED,
            control_id="SEC-03",
            control_name="Infrastructure Protection",
            requirement="Control traffic at all layers with least privilege",
            status=status,
            evidence=evidence,
            recommendations=[
                "Remove 0.0.0.0/0 CIDR blocks from security groups",
                "Implement security group references instead of CIDR blocks",
                "Use VPC endpoints for AWS services"
            ] if violations else [],
            risk_level="CRITICAL" if violations else "LOW"
        ))

    def check_state_security(self) -> None:
        """Check Terraform state security"""
        evidence = []
        issues = []
        
        # Check root terragrunt.hcl for state configuration
        root_config = self.root_path / "terragrunt.hcl"
        if root_config.exists():
            with open(root_config, 'r') as f:
                content = f.read()
                
            required_flags = [
                'encrypt = true',
                'skip_bucket_ssencryption = false',
                'skip_bucket_enforced_tls = false',
                'skip_bucket_public_access_blocking = false'
            ]
            
            for flag in required_flags:
                if flag in content:
                    evidence.append(f"State security: {flag}")
                else:
                    issues.append(f"Missing state security flag: {flag}")
        
        status = "PASS" if not issues else "PARTIAL" if evidence else "FAIL"
        
        self.checks.append(ComplianceCheck(
            framework=ComplianceFramework.SOC2,
            control_id="CC6.3",
            control_name="Data Protection - State Security",
            requirement="Terraform state must be encrypted and access-controlled",
            status=status,
            evidence=evidence,
            recommendations=[
                "Enable all S3 security flags for state bucket",
                "Implement state bucket access logging",
                "Use customer-managed KMS keys for state encryption"
            ] if issues else [],
            risk_level="CRITICAL" if issues else "LOW"
        ))

    def check_dependency_management(self) -> None:
        """Check dependency management best practices"""
        evidence = []
        issues = []
        
        hcl_files = list(self.root_path.rglob("*.hcl"))
        dependency_files = []
        
        for file_path in hcl_files:
            with open(file_path, 'r') as f:
                content = f.read()
                
            if 'dependency "' in content:
                dependency_files.append(file_path)
                
                if 'mock_outputs' in content:
                    evidence.append(f"Mock outputs in {file_path.relative_to(self.root_path)}")
                else:
                    issues.append(f"Missing mock outputs in {file_path.relative_to(self.root_path)}")
        
        status = "PASS" if not issues else "PARTIAL" if evidence else "FAIL"
        
        self.checks.append(ComplianceCheck(
            framework=ComplianceFramework.AWS_WELL_ARCHITECTED,
            control_id="OPS-01",
            control_name="Dependency Management",
            requirement="Dependencies must have mock outputs for reliable deployments",
            status=status,
            evidence=evidence,
            recommendations=[
                "Add mock_outputs to all dependency blocks",
                "Include mock_outputs_allowed_terraform_commands",
                "Test with mock outputs using terragrunt plan"
            ] if issues else [],
            risk_level="HIGH" if issues else "LOW"
        ))

    def run_all_checks(self) -> None:
        """Run all compliance checks"""
        print("🔍 Running compliance checks...")
        
        self.check_mfa_requirements()
        self.check_encryption_at_rest()
        self.check_network_security()
        self.check_state_security()
        self.check_dependency_management()
        
        print(f"✅ Compliance checks completed. {len(self.checks)} controls evaluated.")

    def generate_compliance_report(self) -> str:
        """Generate comprehensive compliance report"""
        # Calculate compliance scores
        framework_scores = {}
        for framework in ComplianceFramework:
            framework_checks = [c for c in self.checks if c.framework == framework]
            if framework_checks:
                passed = len([c for c in framework_checks if c.status == "PASS"])
                total = len(framework_checks)
                framework_scores[framework.value] = (passed / total) * 100
        
        report = f"""
# Terragrunt Compliance Assessment Report

## Compliance Scores
"""
        
        for framework, score in framework_scores.items():
            status_icon = "✅" if score >= 80 else "⚠️" if score >= 60 else "❌"
            report += f"- {status_icon} **{framework}**: {score:.1f}% compliant\n"
        
        report += "\n## Detailed Findings\n\n"
        
        # Group by framework
        for framework in ComplianceFramework:
            framework_checks = [c for c in self.checks if c.framework == framework]
            if not framework_checks:
                continue
                
            report += f"### {framework.value}\n\n"
            
            for check in framework_checks:
                status_icon = {
                    "PASS": "✅",
                    "FAIL": "❌", 
                    "PARTIAL": "⚠️",
                    "NOT_APPLICABLE": "ℹ️"
                }.get(check.status, "❓")
                
                report += f"#### {status_icon} {check.control_id}: {check.control_name}\n"
                report += f"**Status**: {check.status}\n"
                report += f"**Requirement**: {check.requirement}\n"
                
                if check.evidence:
                    report += f"**Evidence**:\n"
                    for evidence in check.evidence:
                        report += f"- {evidence}\n"
                
                if check.recommendations:
                    report += f"**Recommendations**:\n"
                    for rec in check.recommendations:
                        report += f"- {rec}\n"
                
                report += f"**Risk Level**: {check.risk_level}\n\n"
        
        return report

    def export_compliance_json(self, output_file: str) -> None:
        """Export compliance results as JSON"""
        # Calculate overall compliance score
        total_checks = len(self.checks)
        passed_checks = len([c for c in self.checks if c.status == "PASS"])
        overall_score = (passed_checks / total_checks) * 100 if total_checks > 0 else 0
        
        # Framework-specific scores
        framework_scores = {}
        for framework in ComplianceFramework:
            framework_checks = [c for c in self.checks if c.framework == framework]
            if framework_checks:
                passed = len([c for c in framework_checks if c.status == "PASS"])
                total = len(framework_checks)
                framework_scores[framework.value] = {
                    "score": (passed / total) * 100,
                    "passed": passed,
                    "total": total
                }
        
        compliance_data = {
            "assessment_date": os.popen('date -u +"%Y-%m-%dT%H:%M:%SZ"').read().strip(),
            "overall_compliance_score": round(overall_score, 2),
            "framework_scores": framework_scores,
            "total_controls_checked": total_checks,
            "controls_passed": passed_checks,
            "controls_failed": len([c for c in self.checks if c.status == "FAIL"]),
            "controls_partial": len([c for c in self.checks if c.status == "PARTIAL"]),
            "detailed_findings": [asdict(check) for check in self.checks]
        }
        
        with open(output_file, 'w') as f:
            json.dump(compliance_data, f, indent=2, default=str)

    def generate_remediation_plan(self) -> str:
        """Generate prioritized remediation plan"""
        critical_issues = [c for c in self.checks if c.risk_level == "CRITICAL" and c.status == "FAIL"]
        high_issues = [c for c in self.checks if c.risk_level == "HIGH" and c.status == "FAIL"]
        
        plan = f"""
# Compliance Remediation Plan

## Immediate Actions (Critical Risk)
{len(critical_issues)} issues require immediate attention:

"""
        
        for i, check in enumerate(critical_issues, 1):
            plan += f"{i}. **{check.control_name}** ({check.control_id})\n"
            plan += f"   - Issue: {check.requirement}\n"
            for rec in check.recommendations:
                plan += f"   - Action: {rec}\n"
            plan += "\n"
        
        plan += f"""
## Short-term Actions (High Risk)
{len(high_issues)} issues to address within 1 week:

"""
        
        for i, check in enumerate(high_issues, 1):
            plan += f"{i}. **{check.control_name}** ({check.control_id})\n"
            for rec in check.recommendations:
                plan += f"   - Action: {rec}\n"
            plan += "\n"
        
        return plan

def main():
    parser = argparse.ArgumentParser(description='Terragrunt Compliance Checker')
    parser.add_argument('--path', default='.', help='Path to scan (default: current directory)')
    parser.add_argument('--report', help='Output file for compliance report')
    parser.add_argument('--json', help='Export compliance data as JSON')
    parser.add_argument('--remediation', help='Generate remediation plan')
    parser.add_argument('--framework', choices=['SOC2', 'ISO27001', 'AWS_WA'], 
                       help='Focus on specific compliance framework')
    
    args = parser.parse_args()
    
    checker = TerragruntComplianceChecker(args.path)
    checker.run_all_checks()
    
    # Generate reports
    if args.report:
        report = checker.generate_compliance_report()
        with open(args.report, 'w') as f:
            f.write(report)
        print(f"📋 Compliance report saved to {args.report}")
    
    if args.json:
        checker.export_compliance_json(args.json)
        print(f"📊 Compliance data exported to {args.json}")
    
    if args.remediation:
        plan = checker.generate_remediation_plan()
        with open(args.remediation, 'w') as f:
            f.write(plan)
        print(f"🔧 Remediation plan saved to {args.remediation}")
    
    # Print summary
    critical_count = len([c for c in checker.checks if c.risk_level == "CRITICAL" and c.status == "FAIL"])
    high_count = len([c for c in checker.checks if c.risk_level == "HIGH" and c.status == "FAIL"])
    
    print(f"\n📊 Compliance Summary:")
    print(f"   🔴 Critical Issues: {critical_count}")
    print(f"   🟠 High Risk Issues: {high_count}")
    
    if critical_count > 0:
        print(f"\n🚨 CRITICAL: {critical_count} critical compliance violations found!")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())