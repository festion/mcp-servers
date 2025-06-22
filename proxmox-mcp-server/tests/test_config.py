"""
Tests for configuration management.
"""

import os
import tempfile
import json
import pytest
from pydantic import ValidationError

from proxmox_mcp.config import (
    ProxmoxMCPConfig,
    ProxmoxServerConfig,
    SecurityConfig,
    MonitoringConfig,
    AutomationConfig,
    create_sample_config
)
from proxmox_mcp.exceptions import ProxmoxConfigurationError


class TestProxmoxServerConfig:
    """Test ProxmoxServerConfig class."""
    
    def test_valid_config(self):
        """Test valid server configuration."""
        config = ProxmoxServerConfig(
            host="proxmox.example.com",
            username="root",
            password_env_var="PROXMOX_PASSWORD"
        )
        
        assert config.host == "proxmox.example.com"
        assert config.port == 8006
        assert config.username == "root"
        assert config.realm == "pam"
        assert config.verify_ssl is False
        assert config.timeout == 30
    
    def test_password_validation(self):
        """Test password validation."""
        # Should fail when neither password nor password_env_var is provided
        with pytest.raises(ValidationError):
            ProxmoxServerConfig(
                host="proxmox.example.com",
                username="root"
            )
    
    def test_get_connection_params(self, monkeypatch):
        """Test connection parameters resolution."""
        monkeypatch.setenv("TEST_PASSWORD", "secret123")
        
        config = ProxmoxServerConfig(
            host="proxmox.example.com",
            username="root",
            password_env_var="TEST_PASSWORD"
        )
        
        params = config.get_connection_params()
        
        assert params["host"] == "proxmox.example.com"
        assert params["username"] == "root"
        assert params["password"] == "secret123"
    
    def test_missing_env_var(self):
        """Test missing environment variable."""
        config = ProxmoxServerConfig(
            host="proxmox.example.com",
            username="root",
            password_env_var="MISSING_PASSWORD"
        )
        
        with pytest.raises(ProxmoxConfigurationError):
            config.get_connection_params()


class TestSecurityConfig:
    """Test SecurityConfig class."""
    
    def test_default_config(self):
        """Test default security configuration."""
        config = SecurityConfig()
        
        assert config.allow_vm_operations is True
        assert config.allow_storage_operations is True
        assert config.max_snapshot_age_days == 90
        assert config.memory_usage_threshold == 90.0
        assert config.require_confirmation_for_destructive_ops is True
    
    def test_threshold_validation(self):
        """Test threshold validation."""
        # Valid thresholds
        config = SecurityConfig(
            memory_usage_threshold=85.0,
            storage_usage_threshold=80.0
        )
        assert config.memory_usage_threshold == 85.0
        
        # Invalid thresholds
        with pytest.raises(ValidationError):
            SecurityConfig(memory_usage_threshold=150.0)


class TestMonitoringConfig:
    """Test MonitoringConfig class."""
    
    def test_default_config(self):
        """Test default monitoring configuration."""
        config = MonitoringConfig()
        
        assert config.enable_monitoring is True
        assert config.check_interval_seconds == 300
        assert config.cpu_threshold == 80.0
        assert config.memory_threshold == 85.0
        assert config.storage_threshold == 90.0


class TestProxmoxMCPConfig:
    """Test main configuration class."""
    
    def test_valid_config(self, monkeypatch):
        """Test valid main configuration."""
        monkeypatch.setenv("PROXMOX_PASSWORD", "secret123")
        
        config_data = {
            "servers": {
                "main": {
                    "host": "proxmox.example.com",
                    "username": "root",
                    "password_env_var": "PROXMOX_PASSWORD"
                }
            },
            "default_server": "main"
        }
        
        config = ProxmoxMCPConfig(**config_data)
        
        assert len(config.servers) == 1
        assert config.default_server == "main"
        assert "main" in config.servers
    
    def test_default_server_validation(self):
        """Test default server validation."""
        config_data = {
            "servers": {
                "main": {
                    "host": "proxmox.example.com",
                    "username": "root",
                    "password_env_var": "PROXMOX_PASSWORD"
                }
            },
            "default_server": "nonexistent"
        }
        
        with pytest.raises(ValidationError):
            ProxmoxMCPConfig(**config_data)
    
    def test_get_server_config(self, monkeypatch):
        """Test getting server configuration."""
        monkeypatch.setenv("PROXMOX_PASSWORD", "secret123")
        
        config_data = {
            "servers": {
                "main": {
                    "host": "proxmox.example.com",
                    "username": "root", 
                    "password_env_var": "PROXMOX_PASSWORD"
                },
                "backup": {
                    "host": "backup.example.com",
                    "username": "backup",
                    "password_env_var": "PROXMOX_PASSWORD"
                }
            },
            "default_server": "main"
        }
        
        config = ProxmoxMCPConfig(**config_data)
        
        # Get default server
        main_config = config.get_server_config()
        assert main_config.host == "proxmox.example.com"
        
        # Get specific server
        backup_config = config.get_server_config("backup")
        assert backup_config.host == "backup.example.com"
        
        # Get nonexistent server
        with pytest.raises(ProxmoxConfigurationError):
            config.get_server_config("nonexistent")
    
    def test_from_file(self, monkeypatch):
        """Test loading configuration from file."""
        monkeypatch.setenv("PROXMOX_PASSWORD", "secret123")
        
        config_data = {
            "servers": {
                "main": {
                    "host": "proxmox.example.com",
                    "username": "root",
                    "password_env_var": "PROXMOX_PASSWORD"
                }
            },
            "default_server": "main"
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(config_data, f)
            config_path = f.name
        
        try:
            config = ProxmoxMCPConfig.from_file(config_path)
            assert config.default_server == "main"
        finally:
            os.unlink(config_path)
    
    def test_from_file_missing(self):
        """Test loading from missing file."""
        with pytest.raises(ProxmoxConfigurationError):
            ProxmoxMCPConfig.from_file("nonexistent.json")
    
    def test_from_file_invalid_json(self):
        """Test loading invalid JSON."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write("invalid json content")
            config_path = f.name
        
        try:
            with pytest.raises(ProxmoxConfigurationError):
                ProxmoxMCPConfig.from_file(config_path)
        finally:
            os.unlink(config_path)


class TestCreateSampleConfig:
    """Test sample configuration creation."""
    
    def test_create_sample_config(self):
        """Test sample configuration generation."""
        sample = create_sample_config()
        
        assert "servers" in sample
        assert "main" in sample["servers"]
        assert "default_server" in sample
        assert sample["default_server"] == "main"
        
        # Verify main server config
        main_server = sample["servers"]["main"]
        assert "host" in main_server
        assert "username" in main_server
        assert "password_env_var" in main_server
        
        # Verify security config
        assert "security" in sample
        security = sample["security"]
        assert "allow_vm_operations" in security
        assert "require_confirmation_for_destructive_ops" in security
        
        # Verify monitoring config
        assert "monitoring" in sample
        monitoring = sample["monitoring"]
        assert "enable_monitoring" in monitoring
        assert "cpu_threshold" in monitoring
        
        # Verify automation config
        assert "automation" in sample
        automation = sample["automation"]
        assert "enable_automation" in automation