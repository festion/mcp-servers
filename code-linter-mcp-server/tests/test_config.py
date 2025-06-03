"""
Tests for the Code Linter MCP Server configuration.
"""

import pytest
import json
import tempfile
import os
from pathlib import Path

from code_linter_mcp.config import (
    CodeLinterConfig, 
    LinterConfig, 
    LanguageConfig,
    SecurityConfig,
    parse_file_size
)
from code_linter_mcp.exceptions import ConfigurationError


class TestLinterConfig:
    """Test LinterConfig model."""
    
    def test_linter_config_defaults(self):
        """Test LinterConfig with default values."""
        config = LinterConfig()
        
        assert config.enabled is True
        assert config.command is None
        assert config.args == []
        assert config.config_file is None
        assert config.severity_levels == ["error", "warning"]
        assert config.max_line_length is None
        assert config.timeout == 30
    
    def test_linter_config_custom(self):
        """Test LinterConfig with custom values."""
        config = LinterConfig(
            enabled=False,
            command="custom-linter",
            args=["--strict"],
            timeout=60
        )
        
        assert config.enabled is False
        assert config.command == "custom-linter"
        assert config.args == ["--strict"]
        assert config.timeout == 60


class TestLanguageConfig:
    """Test LanguageConfig model."""
    
    def test_language_config_creation(self):
        """Test LanguageConfig creation."""
        linters = {
            "flake8": LinterConfig(),
            "black": LinterConfig(args=["--check"])
        }
        
        config = LanguageConfig(
            extensions=[".py"],
            linters=linters,
            default_linters=["flake8"]
        )
        
        assert config.extensions == [".py"]
        assert len(config.linters) == 2
        assert config.default_linters == ["flake8"]


class TestSecurityConfig:
    """Test SecurityConfig model."""
    
    def test_security_config_defaults(self):
        """Test SecurityConfig with default values."""
        config = SecurityConfig()
        
        assert ".py" in config.allowed_file_extensions
        assert ".json" in config.allowed_file_extensions
        assert config.max_file_size == "10MB"
        assert config.allow_network is False
        assert config.sandbox_mode is True
    
    def test_security_config_custom(self):
        """Test SecurityConfig with custom values."""
        config = SecurityConfig(
            allowed_file_extensions=[".py", ".js"],
            max_file_size="5MB",
            allow_network=True
        )
        
        assert config.allowed_file_extensions == [".py", ".js"]
        assert config.max_file_size == "5MB"
        assert config.allow_network is True


class TestCodeLinterConfig:
    """Test CodeLinterConfig model."""
    
    def test_config_with_defaults(self):
        """Test CodeLinterConfig uses defaults when no languages provided."""
        config = CodeLinterConfig()
        
        # Should have default languages
        assert "python" in config.languages
        assert "go" in config.languages
        assert "javascript" in config.languages
        
        # Check Python config
        python_config = config.languages["python"]
        assert ".py" in python_config.extensions
        assert "flake8" in python_config.linters
        assert "black" in python_config.linters
    
    def test_config_loading_from_dict(self):
        """Test loading configuration from dictionary."""
        config_data = {
            "languages": {
                "python": {
                    "extensions": [".py"],
                    "linters": {
                        "flake8": {"enabled": True}
                    },
                    "default_linters": ["flake8"]
                }
            },
            "log_level": "DEBUG",
            "concurrent_linters": 2
        }
        
        config = CodeLinterConfig(**config_data)
        
        assert config.log_level == "DEBUG"
        assert config.concurrent_linters == 2
        assert "python" in config.languages
        assert config.languages["python"].extensions == [".py"]


class TestParseFileSize:
    """Test parse_file_size function."""
    
    def test_parse_bytes(self):
        """Test parsing bytes."""
        assert parse_file_size("100B") == 100
        assert parse_file_size("100") == 100  # Should default to bytes
    
    def test_parse_kilobytes(self):
        """Test parsing kilobytes."""
        assert parse_file_size("1KB") == 1024
        assert parse_file_size("2KB") == 2048
    
    def test_parse_megabytes(self):
        """Test parsing megabytes."""
        assert parse_file_size("1MB") == 1024 * 1024
        assert parse_file_size("10MB") == 10 * 1024 * 1024
    
    def test_parse_invalid_format(self):
        """Test parsing invalid format raises error."""
        with pytest.raises(ValueError):
            parse_file_size("invalid")
        
        with pytest.raises(ValueError):
            parse_file_size("10XB")


class TestConfigurationLoading:
    """Test configuration file loading."""
    
    def test_load_valid_config_file(self):
        """Test loading a valid configuration file."""
        config_data = {
            "languages": {
                "python": {
                    "extensions": [".py"],
                    "linters": {
                        "flake8": {"enabled": True}
                    },
                    "default_linters": ["flake8"]
                }
            }
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(config_data, f)
            temp_path = f.name
        
        try:
            # Test loading the config
            from code_linter_mcp.server import load_config
            config = load_config(temp_path)
            
            assert isinstance(config, CodeLinterConfig)
            assert "python" in config.languages
        finally:
            os.unlink(temp_path)
    
    def test_load_nonexistent_file(self):
        """Test loading non-existent file raises error."""
        from code_linter_mcp.server import load_config
        
        with pytest.raises(FileNotFoundError):
            load_config("nonexistent.json")
