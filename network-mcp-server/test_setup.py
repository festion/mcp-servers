#!/usr/bin/env python3
"""Test script to verify Network MCP Server functionality."""

import asyncio
import json
import tempfile
import os
from pathlib import Path

async def test_config_loading():
    """Test configuration loading."""
    print("🧪 Testing configuration loading...")
    
    # Create test config
    test_config = {
        "shares": {
            "test_share": {
                "type": "smb",
                "host": "test.example.com",
                "share_name": "test",
                "username": "test_user",
                "password": "test_pass",
                "domain": "TEST"
            }
        },
        "security": {
            "allowed_extensions": [".txt", ".py"],
            "max_file_size": "10MB",
            "enable_write": True,
            "enable_delete": False
        }
    }
    
    # Write to temp file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(test_config, f)
        config_path = f.name
    
    try:
        from network_mcp.server import load_config
        config = load_config(config_path)
        
        assert "test_share" in config.shares
        assert config.shares["test_share"].host == "test.example.com"
        assert config.security.max_file_size == "10MB"
        
        print("✅ Configuration loading test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Configuration loading test failed: {e}")
        return False
    finally:
        os.unlink(config_path)

async def test_security_validation():
    """Test security validation."""
    print("🧪 Testing security validation...")
    
    try:
        from network_mcp.config import SecurityConfig
        from network_mcp.security import SecurityValidator
        from network_mcp.exceptions import ValidationError, PermissionError
        
        config = SecurityConfig(
            allowed_extensions=[".txt", ".py"],
            blocked_extensions=[".exe"],
            enable_write=False,
            enable_delete=False
        )
        
        validator = SecurityValidator(config)
        
        # Test valid extension
        validator.validate_file_extension("test.txt")
        
        # Test blocked extension
        try:
            validator.validate_file_extension("malware.exe")
            print("❌ Should have blocked .exe extension")
            return False
        except ValidationError:
            pass  # Expected
        
        # Test write operation when disabled
        try:
            validator.validate_write_operation("test.txt")
            print("❌ Should have blocked write operation")
            return False
        except PermissionError:
            pass  # Expected
        
        print("✅ Security validation test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Security validation test failed: {e}")
        return False

async def test_mcp_server_creation():
    """Test MCP server creation."""
    print("🧪 Testing MCP server creation...")
    
    try:
        from network_mcp.config import NetworkMCPConfig, SMBShareConfig, SecurityConfig
        from network_mcp.server import NetworkMCPServer
        
        # Create minimal config
        smb_config = SMBShareConfig(
            host="test.example.com",
            share_name="test",
            username="test",
            password="test"
        )
        
        config = NetworkMCPConfig(
            shares={"test": smb_config},
            security=SecurityConfig()
        )
        
        # Create server (don't start it)
        server = NetworkMCPServer(config)
        
        assert server.config.shares["test"].host == "test.example.com"
        assert server.security is not None
        
        print("✅ MCP server creation test passed!")
        return True
        
    except Exception as e:
        print(f"❌ MCP server creation test failed: {e}")
        return False

async def test_cli_commands():
    """Test CLI command creation."""
    print("🧪 Testing CLI commands...")
    
    try:
        # Test sample config creation
        with tempfile.TemporaryDirectory() as temp_dir:
            sample_path = os.path.join(temp_dir, "sample_config.json")
            
            from network_mcp.cli import create_sample_config
            create_sample_config(sample_path)
            
            assert os.path.exists(sample_path)
            
            # Verify it's valid JSON
            with open(sample_path, 'r') as f:
                config_data = json.load(f)
            
            assert "shares" in config_data
            assert "security" in config_data
            
        print("✅ CLI commands test passed!")
        return True
        
    except Exception as e:
        print(f"❌ CLI commands test failed: {e}")
        return False

async def main():
    """Run all tests."""
    print("🚀 Network MCP Server Test Suite")
    print("=" * 50)
    
    tests = [
        test_config_loading,
        test_security_validation,
        test_mcp_server_creation,
        test_cli_commands
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        try:
            if await test():
                passed += 1
        except Exception as e:
            print(f"❌ Test {test.__name__} crashed: {e}")
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} passed")
    
    if passed == total:
        print("🎉 All tests passed! Network MCP Server is ready.")
        return True
    else:
        print("⚠️  Some tests failed. Please check the implementation.")
        return False

if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)
