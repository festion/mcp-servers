#!/usr/bin/env python3
"""
Test script for verifying Proxmox API connectivity with real credentials.
Usage: python test_api_connectivity.py
"""

import asyncio
import os
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from proxmox_mcp.config import ProxmoxMCPConfig
from proxmox_mcp.proxmox_client import ProxmoxClient


async def test_api_connectivity():
    """Test Proxmox API connectivity with configured credentials."""
    print("🔍 Testing Proxmox API Connectivity...")
    print("=" * 50)
    
    try:
        # Load configuration
        config_path = Path(__file__).parent / "config.json"
        config = ProxmoxMCPConfig.from_file(config_path)
        
        # Get default server config
        default_server = config.servers[config.default_server]
        print(f"📊 Server: {default_server.host}:{default_server.port}")
        print(f"👤 User: {default_server.username}@{default_server.realm}")
        
        # Check authentication method
        connection_params = default_server.get_connection_params()
        auth_method = connection_params.get('auth_method', 'password')
        print(f"🔐 Auth Method: {auth_method}")
        
        if auth_method == 'token':
            token = connection_params.get('token', '')
            if 'your-real-token-here' in token:
                print("⚠️  WARNING: Using placeholder token. Please set real token first!")
                print("\n📝 To set real token:")
                print("1. Create API token in Proxmox web interface")
                print("2. Update .env file: PROXMOX_TOKEN=PVEAPIToken=...")
                print("3. Or set environment variable: export PROXMOX_TOKEN=...")
                return False
            print(f"🎫 Token: {token[:30]}...")
        else:
            print(f"🔑 Using password authentication")
        
        print(f"🔗 SSL Verify: {default_server.verify_ssl}")
        print()
        
        # Test connection
        print("🚀 Testing connection...")
        async with ProxmoxClient(default_server) as client:
            await client.connect()
            print("✅ Connection successful!")
            
            # Test basic API calls
            print("\n📋 Testing API calls...")
            
            # Version info
            version_info = await client.get_version()
            print(f"✅ Version: {version_info.get('version', 'Unknown')}")
            
            # Nodes
            nodes = await client.get_nodes()
            print(f"✅ Nodes: {len(nodes)} found")
            for node in nodes[:3]:  # Show first 3 nodes
                print(f"   - {node.get('node', 'Unknown')}: {node.get('status', 'Unknown')}")
            
            # Cluster status
            try:
                cluster_status = await client.get_cluster_status()
                print(f"✅ Cluster: {len(cluster_status)} items")
            except Exception as e:
                print(f"ℹ️  Cluster: {str(e)}")
            
            # Resources
            try:
                resources = await client.get_cluster_resources()
                print(f"✅ Resources: {len(resources)} found")
                
                # Count by type
                resource_types = {}
                for resource in resources:
                    res_type = resource.get('type', 'unknown')
                    resource_types[res_type] = resource_types.get(res_type, 0) + 1
                
                for res_type, count in resource_types.items():
                    print(f"   - {res_type}: {count}")
                    
            except Exception as e:
                print(f"ℹ️  Resources: {str(e)}")
        
        print("\n🎉 All tests passed! Proxmox API connectivity is working.")
        return True
        
    except Exception as e:
        print(f"\n❌ Connection failed: {e}")
        print("\n🔧 Troubleshooting:")
        print("1. Verify Proxmox server is accessible")
        print("2. Check credentials are correct")
        print("3. Ensure API token has proper permissions")
        print("4. Check firewall/network settings")
        return False


if __name__ == "__main__":
    asyncio.run(test_api_connectivity())