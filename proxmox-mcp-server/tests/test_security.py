"""
Tests for security validation.
"""

import pytest
from datetime import datetime, timedelta

from proxmox_mcp.security import SecurityValidator
from proxmox_mcp.config import SecurityConfig
from proxmox_mcp.exceptions import ProxmoxSecurityError, ProxmoxValidationError


class TestSecurityValidator:
    """Test SecurityValidator class."""
    
    @pytest.fixture
    def security_config(self):
        """Create security configuration for testing."""
        return SecurityConfig(
            allow_vm_operations=True,
            allow_storage_operations=True,
            allow_snapshot_operations=True,
            allow_backup_operations=True,
            allow_system_operations=True,
            max_snapshot_age_days=90,
            max_backup_age_days=30,
            max_cleanup_items_per_operation=50,
            memory_usage_threshold=90.0,
            storage_usage_threshold=85.0,
            require_confirmation_for_destructive_ops=True,
            enable_dry_run_mode=False
        )
    
    @pytest.fixture
    def validator(self, security_config):
        """Create security validator for testing."""
        return SecurityValidator(security_config)
    
    def test_validate_allowed_operation(self, validator):
        """Test validation of allowed operations."""
        # VM operations should be allowed
        assert validator.validate_operation("vm_list") is True
        assert validator.validate_operation("vm_status") is True
        
        # Storage operations should be allowed
        assert validator.validate_operation("storage_list") is True
        
        # System operations should be allowed
        assert validator.validate_operation("system_info") is True
    
    def test_validate_disabled_operation(self):
        """Test validation of disabled operations."""
        config = SecurityConfig(allow_vm_operations=False)
        validator = SecurityValidator(config)
        
        with pytest.raises(ProxmoxSecurityError):
            validator.validate_operation("vm_start")
    
    def test_validate_operation_params(self, validator):
        """Test validation of operation parameters."""
        # Valid VM ID
        assert validator.validate_operation("vm_start", {"vmid": 100}) is True
        
        # Invalid VM ID
        with pytest.raises(ProxmoxValidationError):
            validator.validate_operation("vm_start", {"vmid": 50})  # Too low
        
        with pytest.raises(ProxmoxValidationError):
            validator.validate_operation("vm_start", {"vmid": "invalid"})  # Not integer
    
    def test_validate_resource_limits(self, validator):
        """Test resource limit validation."""
        # Normal resource usage - should pass
        resource_data = {
            "memory": {"usage_percent": 70},
            "storage": {
                "local": {"usage_percent": 60},
                "backup": {"usage_percent": 40}
            }
        }
        
        assert validator.validate_resource_limits("vm_create", resource_data) is True
        
        # High memory usage - should fail for VM creation
        resource_data["memory"]["usage_percent"] = 95
        
        with pytest.raises(ProxmoxSecurityError):
            validator.validate_resource_limits("vm_start", resource_data)
        
        # High storage usage - should fail for VM creation
        resource_data["memory"]["usage_percent"] = 70
        resource_data["storage"]["local"]["usage_percent"] = 90
        
        with pytest.raises(ProxmoxSecurityError):
            validator.validate_resource_limits("vm_create", resource_data)
    
    def test_validate_cleanup_operation(self, validator):
        """Test cleanup operation validation."""
        # Normal cleanup count - should pass
        assert validator.validate_cleanup_operation("snapshot_cleanup", 25, []) is True
        
        # Too many items - should fail
        with pytest.raises(ProxmoxSecurityError):
            validator.validate_cleanup_operation("snapshot_cleanup", 100, [])
    
    def test_validate_snapshot_age_cleanup(self, validator):
        """Test snapshot age validation for cleanup."""
        old_time = datetime.now() - timedelta(days=100)
        recent_time = datetime.now() - timedelta(days=10)
        
        # Old snapshots - should pass
        old_snapshots = [
            {"name": "snap1", "created": old_time.isoformat() + "Z"}
        ]
        
        assert validator.validate_cleanup_operation("snapshot_cleanup", 1, old_snapshots) is True
        
        # Recent snapshots - should fail
        recent_snapshots = [
            {"name": "snap1", "created": recent_time.isoformat() + "Z"}
        ]
        
        with pytest.raises(ProxmoxSecurityError):
            validator.validate_cleanup_operation("snapshot_cleanup", 1, recent_snapshots)
    
    def test_validate_backup_age_cleanup(self, validator):
        """Test backup age validation for cleanup."""
        old_time = datetime.now() - timedelta(days=40)
        recent_time = datetime.now() - timedelta(days=5)
        
        # Old backups - should pass
        old_backups = [
            {"name": "backup1", "created": old_time.isoformat() + "Z"}
        ]
        
        assert validator.validate_cleanup_operation("backup_cleanup", 1, old_backups) is True
        
        # Recent backups - should fail
        recent_backups = [
            {"name": "backup1", "created": recent_time.isoformat() + "Z"}
        ]
        
        with pytest.raises(ProxmoxSecurityError):
            validator.validate_cleanup_operation("backup_cleanup", 1, recent_backups)
    
    def test_validate_destructive_operation(self, validator):
        """Test destructive operation validation."""
        # Without confirmation - should fail
        with pytest.raises(ProxmoxSecurityError):
            validator.validate_destructive_operation("vm_delete", {})
        
        # With confirmation - should pass
        assert validator.validate_destructive_operation("vm_delete", {"confirm": True}) is True
        
        # Non-destructive operation - should pass regardless
        assert validator.validate_destructive_operation("vm_list", {}) is True
    
    def test_dry_run_mode(self):
        """Test dry run mode."""
        config = SecurityConfig(enable_dry_run_mode=True)
        validator = SecurityValidator(config)
        
        assert validator.is_dry_run_enabled() is True
        
        config = SecurityConfig(enable_dry_run_mode=False)
        validator = SecurityValidator(config)
        
        assert validator.is_dry_run_enabled() is False
    
    def test_operation_logging(self, validator):
        """Test operation audit logging."""
        # Perform some operations
        validator.validate_operation("vm_list")
        validator.validate_operation("storage_status")
        
        # Check log entries
        log = validator.get_operation_log()
        assert len(log) == 2
        
        assert log[0]["operation"] == "vm_list"
        assert log[0]["status"] == "validated"
        assert "timestamp" in log[0]
        
        assert log[1]["operation"] == "storage_status"
        assert log[1]["status"] == "validated"
    
    def test_operation_log_limits(self, validator):
        """Test operation log size limits."""
        # Generate many log entries
        for i in range(1100):
            validator.validate_operation("vm_list")
        
        log = validator.get_operation_log()
        
        # Should be limited to 1000 entries
        assert len(log) == 1000
    
    def test_clear_operation_log(self, validator):
        """Test clearing operation log."""
        validator.validate_operation("vm_list")
        
        assert len(validator.get_operation_log()) == 1
        
        validator.clear_operation_log()
        
        assert len(validator.get_operation_log()) == 0