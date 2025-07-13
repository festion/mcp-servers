# Proxmox MCP Server - Production Setup Guide

## Overview

This guide will help you set up the Proxmox MCP Server with real Proxmox credentials for production use. The server supports both API token authentication (recommended) and password authentication.

## Current Status

- ✅ Server accessible at: `192.168.1.137:8006`
- ✅ Diagnostic mode working
- ✅ API token authentication implemented
- ✅ Password authentication supported
- ✅ MCP functionality verified

## Quick Setup

Run the interactive setup script:

```bash
cd /home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server
./setup_production_credentials.sh
```

## Manual Setup

### Method 1: API Token Authentication (Recommended)

**Step 1: Create API Token in Proxmox**

1. Open Proxmox web interface: https://192.168.1.137:8006
2. Login with your admin credentials
3. Navigate to: **Datacenter → Permissions → API Tokens**
4. Click **"Add"** to create a new token
5. Configure the token:
   - **User**: `root@pam` (or your preferred user)
   - **Token ID**: `homelab` (or any name you prefer)
   - **Expire**: Set to "Never" or appropriate date
   - **Privilege Separation**: **UNCHECKED** (to inherit user permissions)
   - **Comment**: "MCP Server Token"
6. **Copy the generated token** (it will look like: `PVEAPIToken=root@pam!homelab=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

**Step 2: Configure Environment**

Choose one of these methods:

**Option A: Environment Variable**
```bash
export PROXMOX_TOKEN="PVEAPIToken=root@pam!homelab=your-actual-token-here"
```

**Option B: Update .env file**
```bash
echo 'PROXMOX_TOKEN="PVEAPIToken=root@pam!homelab=your-actual-token-here"' >> .env
```

### Method 2: Password Authentication

**Configure Password**

```bash
export PROXMOX_PASSWORD="your-root-password"
# OR
echo 'PROXMOX_PASSWORD="your-root-password"' >> .env
```

## Testing

### Test API Connectivity

```bash
cd /home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server
python test_api_connectivity.py
```

Expected output for successful connection:
```
🔍 Testing Proxmox API Connectivity...
==================================================
📊 Server: 192.168.1.137:8006
👤 User: root@pam
🔐 Auth Method: token
🎫 Token: PVEAPIToken=root@pam!homelab...
🔗 SSL Verify: False

🚀 Testing connection...
✅ Connection successful!

📋 Testing API calls...
✅ Version: 8.0
✅ Nodes: 1 found
   - proxmox: online
✅ Cluster: 1 items
✅ Resources: 5 found
   - qemu: 2
   - lxc: 1
   - storage: 2

🎉 All tests passed! Proxmox API connectivity is working.
```

### Test MCP Functionality

```bash
python test_mcp_functionality.py
```

### Test Server Startup

```bash
python test_startup.py
```

### Test Wrapper Script

```bash
timeout 10s bash /home/dev/workspace/proxmox-mcp-wrapper.sh
```

## Configuration Files

### config.json
The main configuration file supports both authentication methods:

```json
{
  "servers": {
    "proxmox-primary": {
      "host": "192.168.1.137",
      "username": "root",
      "realm": "pam",
      "token_env_var": "PROXMOX_TOKEN",
      "password_env_var": "PROXMOX_PASSWORD",
      "port": 8006,
      "verify_ssl": false,
      "timeout": 30
    }
  },
  "default_server": "proxmox-primary",
  "security": {
    "max_vms_per_operation": 10,
    "max_storage_gb": 500,
    "allowed_operations": ["snapshot", "backup", "monitor", "manage_vms", "cleanup"],
    "enable_destructive_operations": true
  },
  "logging": {
    "level": "INFO"
  }
}
```

### .env file
Example environment variables:

```bash
# API Token (preferred)
PROXMOX_TOKEN="PVEAPIToken=root@pam!homelab=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# OR Password authentication
# PROXMOX_PASSWORD="your-password"

# Optional overrides
PROXMOX_HOST=192.168.1.137
PROXMOX_USERNAME=root
PROXMOX_PORT=8006
PROXMOX_VERIFY_SSL=false
```

## Security Considerations

1. **Use API Tokens**: API tokens are more secure than passwords and can be easily revoked
2. **Token Permissions**: Ensure tokens have only the necessary permissions
3. **Environment Variables**: Store credentials in environment variables, not config files
4. **SSL Verification**: Enable `verify_ssl: true` if you have proper SSL certificates
5. **Token Rotation**: Regularly rotate API tokens

## Troubleshooting

### Connection Issues

1. **Verify Proxmox is accessible**:
   ```bash
   ping 192.168.1.137
   curl -k https://192.168.1.137:8006/
   ```

2. **Check credentials**:
   ```bash
   curl -k -H "Authorization: $PROXMOX_TOKEN" https://192.168.1.137:8006/api2/json/version
   ```

3. **Check firewall**: Ensure port 8006 is accessible

4. **Check logs**: Look for authentication errors in server output

### Common Error Messages

- **"Authentication failed with status 401"**: Invalid or expired credentials
- **"Network error during authentication"**: Connection issues
- **"Password environment variable not set"**: Missing environment variable

## Production Deployment

1. **Set real credentials** using the methods above
2. **Test connectivity** with `python test_api_connectivity.py`
3. **Update wrapper script** environment variables
4. **Test MCP integration** with Claude Code

## API Token Permissions

The API token should have the following permissions for full functionality:

- **Datastore**: Admin (for backup operations)
- **Pool**: Admin (for resource management)  
- **VM**: Admin (for VM operations)
- **System**: Audit (for system information)
- **SDN**: Admin (if using Software Defined Networking)

## Next Steps

After successful setup:

1. Integrate with Claude Code MCP configuration
2. Test all MCP tools and operations
3. Configure backup and monitoring workflows
4. Set up automated maintenance tasks

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Proxmox API documentation
3. Check MCP server logs for detailed error messages