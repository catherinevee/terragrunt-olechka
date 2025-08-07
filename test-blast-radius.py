#!/usr/bin/env python3
"""
Test script for Blast Radius integration

This script tests the Blast Radius integration to ensure it's working correctly.
"""

import os
import sys
import subprocess
from pathlib import Path


def test_python_dependencies():
    """Test if required Python packages are installed"""
    print("🔍 Testing Python dependencies...")
    
    required_packages = [
        'blastradius',
        'pyhcl',
        'graphviz',
        'flask'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            print(f"  ✅ {package}")
        except ImportError:
            print(f"  ❌ {package} (missing)")
            missing_packages.append(package)
    
    if missing_packages:
        print(f"\n❌ Missing packages: {', '.join(missing_packages)}")
        print("Install with: pip install -r requirements.txt")
        return False
    
    print("✅ All Python dependencies are installed")
    return True


def test_blast_radius_command():
    """Test if blast-radius command is available"""
    print("\n🔍 Testing Blast Radius command...")
    
    try:
        result = subprocess.run(
            ["blast-radius", "--help"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print("✅ Blast Radius command is available")
            return True
        else:
            print("❌ Blast Radius command failed")
            return False
            
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print("❌ Blast Radius command not found")
        return False


def test_terragrunt_environments():
    """Test if terragrunt environments are found"""
    print("\n🔍 Testing Terragrunt environments...")
    
    root_path = Path(".")
    environments = []
    
    # Look for directories with terragrunt.hcl files
    for item in root_path.iterdir():
        if item.is_dir() and (item / "terragrunt.hcl").exists():
            environments.append(item.name)
    
    # Also check for environment subdirectories
    for item in root_path.iterdir():
        if item.is_dir():
            for subitem in item.iterdir():
                if subitem.is_dir() and (subitem / "terragrunt.hcl").exists():
                    environments.append(subitem.name)
    
    if environments:
        print(f"✅ Found {len(environments)} environments:")
        for env in environments:
            print(f"  - {env}")
        return True
    else:
        print("❌ No terragrunt environments found")
        return False


def test_integration_script():
    """Test if the integration script works"""
    print("\n🔍 Testing integration script...")
    
    script_path = Path("blast-radius-integration.py")
    
    if not script_path.exists():
        print("❌ blast-radius-integration.py not found")
        return False
    
    try:
        result = subprocess.run(
            [sys.executable, "blast-radius-integration.py", "--help"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print("✅ Integration script is working")
            return True
        else:
            print("❌ Integration script failed")
            print(f"Error: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Integration script error: {e}")
        return False


def test_docker_compose():
    """Test if Docker Compose file exists"""
    print("\n🔍 Testing Docker Compose configuration...")
    
    compose_file = Path("docker-compose.blast-radius.yml")
    
    if compose_file.exists():
        print("✅ Docker Compose file exists")
        
        # Test if Docker is available
        try:
            result = subprocess.run(
                ["docker", "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                print("✅ Docker is available")
                return True
            else:
                print("❌ Docker is not available")
                return False
                
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print("❌ Docker is not available")
            return False
    else:
        print("❌ Docker Compose file not found")
        return False


def test_makefile():
    """Test if Makefile includes Blast Radius commands"""
    print("\n🔍 Testing Makefile integration...")
    
    makefile_path = Path("Makefile")
    
    if not makefile_path.exists():
        print("❌ Makefile not found")
        return False
    
    try:
        with open(makefile_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        blast_commands = [
            'blast-radius',
            'blast-serve',
            'blast-export',
            'blast-docker'
        ]
        
        missing_commands = []
        
        for command in blast_commands:
            if command in content:
                print(f"  ✅ {command}")
            else:
                print(f"  ❌ {command} (missing)")
                missing_commands.append(command)
        
        if missing_commands:
            print(f"\n❌ Missing Makefile commands: {', '.join(missing_commands)}")
            return False
        
        print("✅ All Blast Radius Makefile commands are present")
        return True
        
    except Exception as e:
        print(f"❌ Error reading Makefile: {e}")
        return False


def main():
    """Main test function"""
    print("🚀 Testing Blast Radius Integration for Terragrunt-Olechka")
    print("=" * 60)
    
    tests = [
        test_python_dependencies,
        test_blast_radius_command,
        test_terragrunt_environments,
        test_integration_script,
        test_docker_compose,
        test_makefile
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        try:
            if test():
                passed += 1
        except Exception as e:
            print(f"❌ Test failed with error: {e}")
    
    print("\n" + "=" * 60)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Blast Radius integration is ready to use.")
        print("\nNext steps:")
        print("  make blast-export    # Generate diagrams")
        print("  make blast-serve     # Serve interactive diagrams")
        print("  make blast-docker    # Use Docker")
    else:
        print("⚠️  Some tests failed. Please check the errors above.")
        print("\nTroubleshooting:")
        print("  pip install -r requirements.txt  # Install dependencies")
        print("  docker --version                 # Check Docker")
        print("  blast-radius --help              # Check Blast Radius")
    
    return passed == total


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 