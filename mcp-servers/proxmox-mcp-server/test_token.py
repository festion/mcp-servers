#!/usr/bin/env python3
"""Test script for Proxmox API token authentication."""

import asyncio
import sys
import os
from pathlib import Path

# Add the source directory to Python path
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

from proxmox_mcp.config import ProxmoxServerConfig

async def test_token():
    """Test API token authentication."""
    
    # Set token directly without shell parsing issues
    token = "PVEAPIToken=root@pam!mcp-server=969028e3-4df2-4cbf-866f-a66af4d2bb4e"
    
    config = ProxmoxServerConfig(
        host="192.168.1.137",
        port=8006,
        username="root",
        token=token,
        realm="pam",
        verify_ssl=False,
        timeout=30
    )
    
    print(f"Testing connection with token: {token[:20]}...")
    
    from proxmox_mcp.proxmox_client import ProxmoxClient
    
    try:
        async with ProxmoxClient(config) as client:
            version_info = await client.get_version()
            print(f"✅ Connection successful!")
            print(f"Proxmox VE version: {version_info.get('data', {}).get('version', 'Unknown')}")
            
            # Test a basic API call
            nodes = await client.get_nodes()
            print(f"Found {len(nodes)} nodes")
            
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False
    
    return True

if __name__ == "__main__":
    success = asyncio.run(test_token())
    sys.exit(0 if success else 1)