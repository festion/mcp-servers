"""Basic tests for the Network MCP Server."""

import pytest
import json
import tempfile
import os

from network_mcp.config import NetworkMCPConfig, SMBShareConfig, SecurityConfig
from network_mcp.security import SecurityValidator
from network_mcp.exceptions import ValidationError, PermissionError


def test_smb_config_creation():
    """Test SMB configuration creation."""
    config = SMBShareConfig(
        host="192.168.1.100",
        share_name="test_share",
        username="testuser",
        password="testpass",
        domain="TESTDOMAIN"
    )
    
    assert config.host == "192.168.1.100"
    assert config.share_name == "test_share"
    assert config.username == "testuser"
    assert config.port == 445  # default
    assert config.use_ntlm_v2 is True  # default


def test_security_config_defaults():
    """Test security configuration defaults."""
    config = SecurityConfig()
    
    assert config.enable_write is True
    assert config.enable_delete is False
    assert config.max_file_size == "100MB"
    assert ".txt" in config.allowed_extensions
    assert ".exe" in config.blocked_extensions


def test_security_validator_file_extension():
    """Test security validator file extension checking."""
    config = SecurityConfig(
        allowed_extensions=[".txt", ".py"],
        blocked_extensions=[".exe", ".bat"]
    )
    validator = SecurityValidator(config)
    
    # Should pass
    validator.validate_file_extension("test.txt")
    validator.validate_file_extension("script.py")
    
    # Should fail - blocked extension
    with pytest.raises(ValidationError, match="blocked"):
        validator.validate_file_extension("malware.exe")
    
    # Should fail - not in allowed list
    with pytest.raises(ValidationError, match="not in allowed list"):
        validator.validate_file_extension("data.json")


def test_security_validator_paths():
    """Test security validator path checking."""
    config = SecurityConfig(
        allowed_paths=["/safe", "/documents"],
        blocked_paths=["/etc", "/root"]
    )
    validator = SecurityValidator(config)
    
    # Should pass
    validator.validate_file_path("/safe/file.txt")
    validator.validate_file_path("/documents/data.json")
    
    # Should fail - blocked path
    with pytest.raises(ValidationError, match="blocked"):
        validator.validate_file_path("/etc/passwd")
    
    # Should fail - not in allowed paths
    with pytest.raises(ValidationError, match="not in allowed paths"):
        validator.validate_file_path("/tmp/file.txt")


def test_security_validator_operations():
    """Test security validator operation checking."""
    config = SecurityConfig(
        enable_write=False,
        enable_delete=False
    )
    validator = SecurityValidator(config)
    
    # Should fail - write disabled
    with pytest.raises(PermissionError, match="Write operations are disabled"):
        validator.validate_write_operation("/test/file.txt")
    
    # Should fail - delete disabled
    with pytest.raises(PermissionError, match="Delete operations are disabled"):
        validator.validate_delete_operation("/test/file.txt")


def test_network_mcp_config_creation():
    """Test main configuration creation."""
    smb_config = SMBShareConfig(
        host="192.168.1.100",
        share_name="test_share",
        username="testuser",
        password="testpass"
    )
    
    config = NetworkMCPConfig(
        shares={"test": smb_config},
        security=SecurityConfig(),
        logging_level="DEBUG"
    )
    
    assert "test" in config.shares
    assert config.logging_level == "DEBUG"
    assert config.max_connections == 10  # default


def test_config_loading_from_json():
    """Test loading configuration from JSON file."""
    config_data = {
        "shares": {
            "my_share": {
                "type": "smb",
                "host": "192.168.1.100",
                "share_name": "documents",
                "username": "user",
                "password": "pass",
                "domain": "WORKGROUP"
            }
        },
        "security": {
            "allowed_extensions": [".txt", ".py"],
            "max_file_size": "50MB",
            "enable_write": True,
            "enable_delete": False
        },
        "logging_level": "INFO"
    }
    
    # Create temporary config file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(config_data, f)
        config_path = f.name
    
    try:
        from network_mcp.server import load_config
        config = load_config(config_path)
        
        assert "my_share" in config.shares
        assert config.shares["my_share"].host == "192.168.1.100"
        assert config.security.max_file_size == "50MB"
        assert config.logging_level == "INFO"
        
    finally:
        os.unlink(config_path)


if __name__ == "__main__":
    pytest.main([__file__])
