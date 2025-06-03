"""
Tests for security validation.
"""

import pytest
import tempfile
import os

from code_linter_mcp.security import SecurityValidator
from code_linter_mcp.config import SecurityConfig


class TestSecurityValidator:
    """Test SecurityValidator class."""
    
    def test_file_extension_validation(self):
        """Test file extension validation."""
        config = SecurityConfig(allowed_file_extensions=[".py", ".js"])
        validator = SecurityValidator(config)
        
        assert validator.validate_file_extension("test.py") is True
        assert validator.validate_file_extension("test.js") is True
        assert validator.validate_file_extension("test.exe") is False
        assert validator.validate_file_extension("test.dll") is False
    
    def test_file_path_validation(self):
        """Test file path validation."""
        config = SecurityConfig()
        validator = SecurityValidator(config)
        
        # Valid paths
        assert validator.validate_file_path("test.py") is True
        assert validator.validate_file_path("src/test.py") is True
        
        # Invalid paths (path traversal)
        assert validator.validate_file_path("../test.py") is False
        assert validator.validate_file_path("/etc/passwd") is False
        assert validator.validate_file_path("..\\test.py") is False
    
    def test_content_validation(self):
        """Test content validation."""
        config = SecurityConfig(allow_network=False)
        validator = SecurityValidator(config)
        
        # Safe content
        safe_content = """
def hello():
    print("Hello, world!")
        """
        assert validator.validate_content(safe_content) is True
        
        # Suspicious content
        suspicious_content = """
import subprocess
subprocess.run("rm -rf /", shell=True)
        """
        assert validator.validate_content(suspicious_content) is False
    
    def test_operation_validation(self):
        """Test operation validation."""
        config = SecurityConfig()
        validator = SecurityValidator(config)
        
        # Allowed operations
        assert validator.validate_operation("lint") is True
        assert validator.validate_operation("validate") is True
        assert validator.validate_operation("check") is True
        
        # Should be case insensitive
        assert validator.validate_operation("LINT") is True
    
    def test_file_size_validation(self):
        """Test file size validation."""
        config = SecurityConfig(max_file_size="1KB")  # 1024 bytes
        validator = SecurityValidator(config)
        
        # Create a temporary file under the limit
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
            f.write("x" * 500)  # 500 bytes
            small_file = f.name
        
        # Create a temporary file over the limit  
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
            f.write("x" * 2000)  # 2000 bytes
            large_file = f.name
        
        try:
            assert validator.validate_file_size(small_file) is True
            assert validator.validate_file_size(large_file) is False
        finally:
            os.unlink(small_file)
            os.unlink(large_file)
