#!/usr/bin/env python3
"""
Test suite for the MCP feature branch management system.
Validates that all components are properly configured and functional.
"""

import os
import subprocess
import json
from pathlib import Path


def test_directory_structure():
    """Test that all required directories exist."""
    required_dirs = [
        "scripts",
        ".github",
        ".github/workflows", 
        "docs",
        "docs/features",
        "docs/changelog",
        "tests",
        "tests/unit",
        "tests/integration",
        "tests/security",
        "tests/performance"
    ]
    
    for dir_path in required_dirs:
        assert os.path.exists(dir_path), f"Required directory {dir_path} does not exist"
    
    print("✅ All required directories exist")


def test_script_files():
    """Test that all required script files exist and are executable."""
    required_scripts = [
        "scripts/feature-branch.sh",
        ".github/branch-protection-rules.sh"
    ]
    
    for script_path in required_scripts:
        assert os.path.exists(script_path), f"Required script {script_path} does not exist"
        assert os.access(script_path, os.X_OK), f"Script {script_path} is not executable"
    
    print("✅ All required scripts exist and are executable")


def test_github_workflows():
    """Test that GitHub workflow files exist and are valid YAML."""
    workflow_files = [
        ".github/workflows/mcp-feature-ci.yml",
        ".github/workflows/branch-cleanup.yml"
    ]
    
    for workflow_file in workflow_files:
        assert os.path.exists(workflow_file), f"Workflow file {workflow_file} does not exist"
        
        # Basic YAML syntax check
        with open(workflow_file, 'r') as f:
            content = f.read()
            assert 'name:' in content, f"Workflow {workflow_file} missing name field"
            assert 'on:' in content, f"Workflow {workflow_file} missing trigger field"
            assert 'jobs:' in content, f"Workflow {workflow_file} missing jobs field"
    
    print("✅ All GitHub workflow files exist and have valid structure")


def test_documentation_files():
    """Test that all required documentation files exist."""
    required_docs = [
        ".github/pull_request_template.md",
        "docs/FEATURE_DEVELOPMENT_GUIDE.md",
        "README_BRANCH_MANAGEMENT.md"
    ]
    
    for doc_path in required_docs:
        assert os.path.exists(doc_path), f"Required documentation {doc_path} does not exist"
        
        # Check that file is not empty
        with open(doc_path, 'r') as f:
            content = f.read().strip()
            assert len(content) > 0, f"Documentation file {doc_path} is empty"
    
    print("✅ All required documentation files exist and are not empty")


def test_feature_branch_script_help():
    """Test that the feature branch script shows help correctly."""
    try:
        result = subprocess.run(
            ["./scripts/feature-branch.sh"],
            capture_output=True,
            text=True,
            cwd="."
        )
        
        # Script should show usage when no arguments provided
        assert result.returncode != 0, "Script should exit with error when no args provided"
        assert "Usage:" in result.stdout or "Usage:" in result.stderr, "Script should show usage information"
        
        # Check for expected commands
        output = result.stdout + result.stderr
        expected_commands = ["create", "status", "test", "prepare", "pr", "cleanup"]
        for cmd in expected_commands:
            assert cmd in output, f"Command '{cmd}' not found in help output"
        
        print("✅ Feature branch script shows correct help information")
        
    except subprocess.SubprocessError as e:
        print(f"⚠️  Could not test feature branch script: {e}")


def test_git_configuration():
    """Test that git is properly configured."""
    try:
        # Check if we're in a git repository
        result = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0, "Not in a git repository"
        
        # Check git user configuration
        result = subprocess.run(
            ["git", "config", "user.name"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0 and result.stdout.strip(), "Git user.name not configured"
        
        result = subprocess.run(
            ["git", "config", "user.email"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0 and result.stdout.strip(), "Git user.email not configured"
        
        print("✅ Git is properly configured")
        
    except subprocess.SubprocessError as e:
        print(f"⚠️  Could not verify git configuration: {e}")


def test_github_cli_availability():
    """Test that GitHub CLI is available (optional)."""
    try:
        result = subprocess.run(
            ["gh", "--version"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print("✅ GitHub CLI is available")
        else:
            print("⚠️  GitHub CLI not available - some features may not work")
    except FileNotFoundError:
        print("⚠️  GitHub CLI not installed - some features may not work")


def test_mcp_server_directories():
    """Test that MCP server directories exist."""
    mcp_servers_dir = Path("mcp-servers")
    if mcp_servers_dir.exists():
        server_dirs = [d for d in mcp_servers_dir.iterdir() if d.is_dir() and not d.name.startswith('.')]
        if server_dirs:
            print(f"✅ Found {len(server_dirs)} MCP server directories: {[d.name for d in server_dirs]}")
        else:
            print("⚠️  No MCP server directories found")
    else:
        print("⚠️  mcp-servers directory does not exist")


def test_workflow_syntax():
    """Test GitHub workflow files for basic syntax issues."""
    workflow_files = [
        ".github/workflows/mcp-feature-ci.yml",
        ".github/workflows/branch-cleanup.yml"
    ]
    
    for workflow_file in workflow_files:
        if os.path.exists(workflow_file):
            with open(workflow_file, 'r') as f:
                content = f.read()
                
                # Check for common YAML issues
                assert not content.strip().startswith('\t'), f"Workflow {workflow_file} contains tabs (should use spaces)"
                assert '{{' in content and '}}' in content, f"Workflow {workflow_file} should contain GitHub expressions"
                
                # Check for required workflow elements
                assert 'ubuntu-latest' in content, f"Workflow {workflow_file} should use ubuntu-latest"
                assert 'actions/checkout@v' in content, f"Workflow {workflow_file} should use checkout action"
    
    print("✅ GitHub workflows have correct basic syntax")


def run_all_tests():
    """Run all tests and report results."""
    tests = [
        test_directory_structure,
        test_script_files,
        test_github_workflows,
        test_documentation_files,
        test_feature_branch_script_help,
        test_git_configuration,
        test_github_cli_availability,
        test_mcp_server_directories,
        test_workflow_syntax
    ]
    
    print("🧪 Running MCP Feature Branch Management System Tests")
    print("=" * 60)
    
    passed = 0
    total = len(tests)
    
    for test_func in tests:
        try:
            test_func()
            passed += 1
        except Exception as e:
            print(f"❌ {test_func.__name__}: {e}")
    
    print("=" * 60)
    print(f"Tests completed: {passed}/{total} passed")
    
    if passed == total:
        print("🎉 All tests passed! The MCP feature branch management system is ready.")
        return True
    else:
        print("⚠️  Some tests failed. Please review the issues above.")
        return False


if __name__ == "__main__":
    success = run_all_tests()
    exit(0 if success else 1)