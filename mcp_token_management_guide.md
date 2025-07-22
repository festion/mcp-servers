# MCP Token Management System

## Overview

The MCP Token Management System provides secure, centralized credential storage for all Model Context Protocol (MCP) servers in the infrastructure. This system eliminates the need for hardcoded tokens and ensures production credentials persist across shell sessions and system reboots.

## Problem Solved

### Previous Issues
- **Hardcoded test tokens** in multiple scripts causing authentication failures
- **Environment variable inconsistency** leading to frequent token re-entry
- **Security vulnerabilities** from tokens stored in plain text files
- **Manual token management** requiring constant attention

### Solution Benefits
- **Unified credential management** for all MCP servers
- **Secure storage** with proper file permissions (600)
- **Automatic validation** of token formats and URLs
- **Persistent credentials** that survive system restarts
- **Backup functionality** for credential updates

## Architecture

### Storage Structure
```
/home/dev/.mcp_tokens/
├── github_token          # GitHub personal access token
├── hass_token           # Home Assistant long-lived token
├── hass_url             # Home Assistant URL
├── proxmox_token        # Proxmox API token
├── proxmox_host         # Proxmox server hostname/IP
├── proxmox_user         # Proxmox user@realm
├── wikijs_token         # WikiJS API token
├── wikijs_url           # WikiJS instance URL
└── backups/             # Automatic backups directory
```

### File Permissions
- **Directory**: `700` (owner read/write/execute only)
- **Token files**: `600` (owner read/write only)
- **Backup files**: `600` (owner read/write only)

## Supported Services

### 1. GitHub MCP Server
- **Token Format**: `ghp_[36 alphanumeric characters]`
- **Validation**: GitHub API connectivity test
- **Variables**: `GITHUB_PERSONAL_ACCESS_TOKEN`

### 2. Home Assistant MCP Server
- **Token Format**: JWT (long-lived access token)
- **URL Format**: `http://hostname:port` or `https://hostname:port`
- **Variables**: `HA_TOKEN`, `HA_URL`

### 3. Proxmox MCP Server
- **Token Format**: `PVEAPIToken=user@realm!token=uuid`
- **Host Format**: IP address or FQDN
- **User Format**: `user@realm`
- **Variables**: `PROXMOX_TOKEN`, `PROXMOX_HOST`, `PROXMOX_USER`

### 4. WikiJS MCP Server
- **Token Format**: JWT (API token)
- **URL Format**: `http://hostname:port` or `https://hostname:port`
- **Variables**: `WIKIJS_TOKEN`, `WIKIJS_URL`

## Usage Guide

### Initial Setup

1. **Store credentials for all services**:
   ```bash
   # GitHub
   /home/dev/workspace/github-token-manager.sh store github token ghp_your_token_here
   
   # Home Assistant
   /home/dev/workspace/github-token-manager.sh store hass token your_hass_token_here
   /home/dev/workspace/github-token-manager.sh store hass url http://your.hass.host:8123
   
   # Proxmox
   /home/dev/workspace/github-token-manager.sh store proxmox token 'PVEAPIToken=user@realm!token=uuid'
   /home/dev/workspace/github-token-manager.sh store proxmox host your.proxmox.host
   /home/dev/workspace/github-token-manager.sh store proxmox user root@pam
   
   # WikiJS
   /home/dev/workspace/github-token-manager.sh store wikijs token your_wikijs_token_here
   /home/dev/workspace/github-token-manager.sh store wikijs url http://your.wikijs.host:3000
   ```

2. **Setup automatic loading** (optional):
   ```bash
   /home/dev/workspace/github-token-manager.sh setup
   ```

### Daily Operations

#### Load Credentials
```bash
# Load all service credentials
/home/dev/workspace/github-token-manager.sh load all

# Load specific service
/home/dev/workspace/github-token-manager.sh load github
/home/dev/workspace/github-token-manager.sh load hass
/home/dev/workspace/github-token-manager.sh load proxmox
/home/dev/workspace/github-token-manager.sh load wikijs
```

#### Verify Credentials
```bash
# Verify all credentials
/home/dev/workspace/github-token-manager.sh verify all

# Verify specific service
/home/dev/workspace/github-token-manager.sh verify github
```

#### List Stored Credentials
```bash
# Show all stored credentials (masked for security)
/home/dev/workspace/github-token-manager.sh list
```

### Credential Management

#### Update Credentials
```bash
# Update GitHub token
/home/dev/workspace/github-token-manager.sh store github token ghp_new_token_here

# Update Home Assistant URL
/home/dev/workspace/github-token-manager.sh store hass url http://your.new.hass.host:8123
```

#### Backup and Recovery
- **Automatic backups** are created before each credential update
- **Backup location**: `/home/dev/.mcp_tokens/backups/`
- **Backup format**: `{service}_{key}.{timestamp}.backup`

## Integration with MCP Servers

All MCP wrapper scripts have been updated to use the token manager:

### GitHub Wrapper (`github-wrapper.sh`)
```bash
# Load GitHub token from secure storage
source /home/dev/workspace/github-token-manager.sh
if ! load_credentials github; then
    echo "ERROR: Failed to load GitHub token"
    echo "Please run: /home/dev/workspace/github-token-manager.sh store github token <your_token>"
    exit 1
fi
```

### Home Assistant Wrapper (`hass-mcp-wrapper.sh`)
```bash
# Load Home Assistant credentials from secure storage
source /home/dev/workspace/github-token-manager.sh
if ! load_credentials hass; then
    echo "ERROR: Failed to load Home Assistant credentials"
    echo "Please run:"
    echo "  /home/dev/workspace/github-token-manager.sh store hass token <your_hass_token>"
    echo "  /home/dev/workspace/github-token-manager.sh store hass url <your_hass_url>"
    exit 1
fi
```

### Proxmox Wrapper (`proxmox-mcp-wrapper.sh`)
```bash
# Load Proxmox credentials from secure storage
source /home/dev/workspace/github-token-manager.sh
if ! load_credentials proxmox; then
    echo "ERROR: Failed to load Proxmox credentials"
    echo "Please run:"
    echo "  /home/dev/workspace/github-token-manager.sh store proxmox token 'PVEAPIToken=user@realm!token=uuid'"
    echo "  /home/dev/workspace/github-token-manager.sh store proxmox host your.proxmox.host"
    echo "  /home/dev/workspace/github-token-manager.sh store proxmox user root@pam"
    exit 1
fi
```

### WikiJS Wrapper (`wikijs-mcp-wrapper.sh`)
```bash
# Load WikiJS credentials from secure storage
source /home/dev/workspace/github-token-manager.sh
if ! load_credentials wikijs; then
    echo "ERROR: Failed to load WikiJS credentials"
    echo "Please run:"
    echo "  /home/dev/workspace/github-token-manager.sh store wikijs token <your_wikijs_token>"
    echo "  /home/dev/workspace/github-token-manager.sh store wikijs url <your_wikijs_url>"
    exit 1
fi
```

## Security Features

### Validation
- **Token format validation** for each service type
- **URL format validation** for HTTP/HTTPS endpoints
- **Hostname/IP validation** for host addresses
- **User format validation** for Proxmox user@realm format

### Access Control
- **File permissions**: 600 (owner read/write only)
- **Directory permissions**: 700 (owner access only)
- **No group or world access** to credential files

### Backup System
- **Automatic backups** before credential updates
- **Timestamped backups** for audit trail
- **Secure backup storage** with same permissions

## Troubleshooting

### Common Issues

#### Token Not Loading
```bash
# Check if credentials are stored
/home/dev/workspace/github-token-manager.sh list

# Verify credential format
/home/dev/workspace/github-token-manager.sh verify <service>
```

#### Authentication Failures
```bash
# Test GitHub token specifically
/home/dev/workspace/github-token-manager.sh verify github

# Check file permissions
ls -la /home/dev/.mcp_tokens/
```

#### Missing Credentials
```bash
# Re-store credentials
/home/dev/workspace/github-token-manager.sh store <service> <key> <value>

# Verify storage
/home/dev/workspace/github-token-manager.sh verify <service>
```

### Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Invalid GitHub token format" | Token doesn't match `ghp_` pattern | Verify token from GitHub settings |
| "Invalid URL format" | URL missing protocol or malformed | Use `http://` or `https://` prefix |
| "Invalid host format" | Host not IP or hostname | Use valid IP or FQDN |
| "Invalid Proxmox user format" | User missing @realm | Use format `user@realm` |
| "Invalid Proxmox token format" | Token missing PVEAPIToken prefix | Use format `PVEAPIToken=...` |

## Migration from Legacy System

### Previous Configuration
- Hardcoded tokens in wrapper scripts
- Environment variables set manually
- Test tokens mixed with production tokens

### Migration Steps
1. **Remove old environment variables**:
   ```bash
   unset GITHUB_PERSONAL_ACCESS_TOKEN
   unset HA_TOKEN HA_URL
   unset PROXMOX_TOKEN PROXMOX_HOST PROXMOX_USER
   unset WIKIJS_TOKEN WIKIJS_URL
   ```

2. **Store production credentials**:
   ```bash
   # Use the store commands from the Usage Guide above
   ```

3. **Test MCP servers**:
   ```bash
   # Test each wrapper script
   /home/dev/workspace/github-wrapper.sh
   /home/dev/workspace/hass-mcp-wrapper.sh
   /home/dev/workspace/proxmox-mcp-wrapper.sh
   /home/dev/workspace/wikijs-mcp-wrapper.sh
   ```

## Maintenance

### Regular Tasks
1. **Monthly credential verification**:
   ```bash
   /home/dev/workspace/github-token-manager.sh verify all
   ```

2. **Backup cleanup** (older than 90 days):
   ```bash
   find /home/dev/.mcp_tokens/backups/ -name "*.backup" -mtime +90 -delete
   ```

3. **Permission verification**:
   ```bash
   chmod 700 /home/dev/.mcp_tokens/
   chmod 600 /home/dev/.mcp_tokens/*
   ```

### Token Rotation
When rotating tokens (recommended every 90 days):

1. **Generate new token** in respective service
2. **Update stored credential**:
   ```bash
   /home/dev/workspace/github-token-manager.sh store <service> <key> <new_value>
   ```
3. **Verify functionality**:
   ```bash
   /home/dev/workspace/github-token-manager.sh verify <service>
   ```
4. **Revoke old token** in service settings

## Command Reference

### Store Commands
```bash
# GitHub
github-token-manager.sh store github token <token>

# Home Assistant
github-token-manager.sh store hass token <token>
github-token-manager.sh store hass url <url>

# Proxmox
github-token-manager.sh store proxmox token <token>
github-token-manager.sh store proxmox host <host>
github-token-manager.sh store proxmox user <user>

# WikiJS
github-token-manager.sh store wikijs token <token>
github-token-manager.sh store wikijs url <url>
```

### Management Commands
```bash
# Load credentials
github-token-manager.sh load [service|all]

# Verify credentials
github-token-manager.sh verify [service|all]

# List stored credentials
github-token-manager.sh list

# Setup auto-load
github-token-manager.sh setup
```

## Implementation History

### Version 1.0 (GitHub Only)
- Basic GitHub token storage
- Simple validation
- Manual loading

### Version 2.0 (Multi-Service)
- Support for all MCP servers
- Enhanced validation
- Automatic backups
- Unified command interface

### Current Production Status
- **GitHub**: ✅ Production ready with valid token
- **Home Assistant**: ✅ Production ready
- **Proxmox**: ✅ Production ready
- **WikiJS**: ✅ Production ready

## Related Documentation

- [MCP Server Setup Guide](/infrastructure/mcp-setup)
- [Security Best Practices](/security/token-management)
- [Infrastructure Monitoring](/monitoring/mcp-health)

---

*Last updated: 2025-07-08*
*System: MCP Token Management v2.0*
*Status: Production Ready*