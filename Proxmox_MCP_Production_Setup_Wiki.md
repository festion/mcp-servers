# Proxmox MCP Server - Production Setup Guide

## Overview

This guide will help you set up the Proxmox MCP Server with real Proxmox credentials for production use. The server supports both API authentication (recommended) and alternative authentication methods.

## Current Status

- ✅ Server accessible and operational
- ✅ Diagnostic mode working
- ✅ API authentication implemented
- ✅ Alternative authentication supported
- ✅ MCP functionality verified

## Quick Setup

Run the interactive setup script:

```bash
cd /path/to/proxmox-mcp-server
./setup_production_credentials.sh
```

## Manual Setup

### Method 1: API Authentication (Recommended)

**Step 1: Create API Credentials in Proxmox**

1. Open Proxmox web interface
2. Login with your admin credentials
3. Navigate to: **Datacenter → Permissions → API Tokens**
4. Click **"Add"** to create a new set of credentials
5. Configure:
   - **User**: Select appropriate user
   - **Token ID**: Choose meaningful identifier
   - **Expire**: Set to appropriate date or "Never"
   - **Privilege Separation**: **UNCHECKED** (to inherit user permissions)
   - **Comment**: "MCP Server Access"

6. **Copy the generated credentials**

**Step 2: Configure Environment**

Choose one of these methods:

**Option A: Environment Variable**
```bash
export PROXMOX_AUTH="[Your-API-Credentials]"
```

**Option B: Update .env file**
```bash
echo 'PROXMOX_AUTH="[Your-Credentials]"' >> .env
```

### Method 2: Alternative Authentication

**Configure Alternative Method**

```bash
export PROXMOX_FALLBACK="[Alternative-Credentials]"
# OR
echo 'PROXMOX_FALLBACK="[Alternative-Credentials]"' >> .env
```

## Testing

### Test API Connectivity

```bash
cd /path/to/proxmox-mcp-server
python test_api_connectivity.py
```

Expected output for successful connection:
```
🔍 Testing Proxmox API Connectivity...
==================================================
📊 Server: your-proxmox-server:8006
👤 User: your-username
🔐 Auth Method: api
🔗 SSL Verify: False

🚀 Testing connection...
✅ Connection successful!

📋 Testing API calls...
✅ Version: 8.0
✅ Nodes: X found
✅ Cluster: X items
✅ Resources: X found

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
timeout 10s bash /path/to/proxmox-mcp-wrapper.sh
```

## Configuration Files

### config.json
The main configuration file supports both authentication methods:

```json
{
  "servers": {
    "proxmox-primary": {
      "host": "your-proxmox-server",
      "username": "your-username",
      "realm": "pam",
      "auth_env_var": "PROXMOX_AUTH",
      "fallback_env_var": "PROXMOX_FALLBACK",
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
# API Authentication (preferred)
PROXMOX_AUTH="[Your-API-Credentials]"

# OR Alternative authentication
# PROXMOX_FALLBACK="[Alternative-Credentials]"

# Optional overrides
PROXMOX_HOST=your-proxmox-server
PROXMOX_USERNAME=your-username
PROXMOX_PORT=8006
PROXMOX_VERIFY_SSL=false
```

## Security Considerations

1. **Use API Authentication**: More secure and can be easily revoked
2. **Credential Permissions**: Ensure credentials have only necessary permissions
3. **Environment Variables**: Store credentials in environment variables, not config files
4. **SSL Verification**: Enable `verify_ssl: true` if you have proper SSL certificates
5. **Credential Rotation**: Regularly rotate API credentials

## Troubleshooting

### Connection Issues

1. **Verify Proxmox is accessible**:
   ```bash
   ping your-proxmox-server
   curl -k https://your-proxmox-server:8006/
   ```

2. **Check credentials**:
   ```bash
   curl -k -H "Authorization: $PROXMOX_AUTH" https://your-proxmox-server:8006/api2/json/version
   ```

3. **Check firewall**: Ensure port 8006 is accessible

4. **Check logs**: Look for authentication errors in server output

### Common Error Messages

- **"Authentication failed with status 401"**: Invalid or expired credentials
- **"Network error during authentication"**: Connection issues
- **"Environment variable not set"**: Missing environment variable

## Production Deployment

1. **Set real credentials** using the methods above
2. **Test connectivity** with `python test_api_connectivity.py`
3. **Update wrapper script** environment variables
4. **Test MCP integration** with Claude Code

## Required Permissions

The API credentials should have the following permissions for full functionality:

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

---

*This setup guide provides step-by-step instructions for configuring the Proxmox MCP Server for production use with proper authentication and security practices.*