#!/usr/bin/env python3
"""
Test script to verify Proxmox MCP server functionality.
Tests the CLI commands and configuration validation.
"""

import subprocess
import sys
import os
import json
from pathlib import Path

def run_command(cmd):
    """Run a command and return success status and output."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)

def test_proxmox_mcp_server():
    """Test Proxmox MCP server functionality."""
    print("Testing Proxmox MCP Server Functionality...")
    print("=" * 50)
    
    tests_passed = 0
    total_tests = 0
    
    # Test 1: Version command
    total_tests += 1
    print("Test 1: Version command")
    success, stdout, stderr = run_command("proxmox-mcp-server --version")
    if success and "Proxmox MCP Server" in stdout:
        print("✅ Version command works")
        tests_passed += 1
    else:
        print(f"❌ Version command failed: {stderr}")
    
    # Test 2: Info command
    total_tests += 1
    print("\nTest 2: Info command")
    success, stdout, stderr = run_command("proxmox-mcp-server info")
    if success and "Available Tools" in stdout:
        print("✅ Info command works")
        tests_passed += 1
    else:
        print(f"❌ Info command failed: {stderr}")
    
    # Test 3: Create config command
    total_tests += 1
    print("\nTest 3: Create config command")
    test_config_path = "test_config_generated.json"
    success, stdout, stderr = run_command(f"proxmox-mcp-server create-config --output {test_config_path}")
    if success and os.path.exists(test_config_path):
        print("✅ Config creation works")
        tests_passed += 1
        
        # Verify config is valid JSON
        try:
            with open(test_config_path, 'r') as f:
                config = json.load(f)
            if "servers" in config and "security" in config:
                print("✅ Generated config is valid JSON with expected structure")
            else:
                print("❌ Generated config missing expected sections")
        except json.JSONDecodeError:
            print("❌ Generated config is not valid JSON")
        
        # Clean up
        os.remove(test_config_path)
    else:
        print(f"❌ Config creation failed: {stderr}")
    
    # Test 4: Validate config command
    total_tests += 1
    print("\nTest 4: Validate config command")
    # Use the existing test_config.json if it exists
    config_path = "test_config.json" if os.path.exists("test_config.json") else "config.json"
    success, stdout, stderr = run_command(f"proxmox-mcp-server validate-config {config_path}")
    if success and "Configuration is valid" in stdout:
        print("✅ Config validation works")
        tests_passed += 1
    else:
        print(f"❌ Config validation failed: {stderr}")
    
    # Test 5: Help command
    total_tests += 1
    print("\nTest 5: Help command")
    success, stdout, stderr = run_command("proxmox-mcp-server --help")
    if success and "usage:" in stdout.lower():
        print("✅ Help command works")
        tests_passed += 1
    else:
        print(f"❌ Help command failed: {stderr}")
    
    # Summary
    print("\n" + "=" * 50)
    print(f"Test Results: {tests_passed}/{total_tests} tests passed")
    
    if tests_passed == total_tests:
        print("✅ All Proxmox MCP Server tests passed!")
        return True
    else:
        print(f"❌ {total_tests - tests_passed} tests failed")
        return False

if __name__ == "__main__":
    success = test_proxmox_mcp_server()
    sys.exit(0 if success else 1)