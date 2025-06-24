#!/usr/bin/env python3
"""
Test script to verify Proxmox MCP server can start without hanging.
"""

import sys
import os
from pathlib import Path

# Add src directory to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

def test_server_startup():
    """Test that server can initialize without errors."""
    try:
        from proxmox_mcp.config import ProxmoxMCPConfig
        from proxmox_mcp.server import ProxmoxMCPServer
        
        # Test config loading
        config_path = "config.json"
        print(f"Testing config loading from {config_path}...")
        config = ProxmoxMCPConfig.from_file(config_path)
        print("✅ Config loaded successfully")
        
        # Test server initialization  
        print("Testing server initialization...")
        server = ProxmoxMCPServer(config)
        print("✅ Server initialized successfully")
        
        print("✅ Proxmox MCP Server startup test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Proxmox MCP Server startup test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_server_startup()
    sys.exit(0 if success else 1)