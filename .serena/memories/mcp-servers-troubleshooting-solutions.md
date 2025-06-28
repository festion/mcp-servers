# MCP Servers Troubleshooting Solutions

## Configuration File Locations
- Main Claude Code config: `/home/jeremy/.config/claude-code/settings.json`
- Parent override config: `/mnt/c/GIT/.mcp.json` (HIGHEST PRIORITY)
- Project config: `/mnt/c/GIT/mcp-servers/wikijs-mcp-server/.claude_code_config.json`
- Server configs: `/home/jeremy/.mcp-servers/config/`

## Fixed Issues

### 1. Network-MCP
**Problem**: Missing --config flag and invalid SMB configuration
**Solution**: 
- Add `--config` flag: `"args": ["run", "--config", "/path/to/config.json"]`
- Fix SMB config structure:
```json
{
  "shares": {
    "sharename": {
      "type": "smb",
      "host": "192.168.1.155",
      "share_name": "config",
      "username": "user",
      "password": "pass",
      "domain": "WORKGROUP",
      "port": 445,
      "use_ntlm_v2": true,
      "timeout": 30
    }
  }
}
```

### 2. Code-Linter-MCP
**Problem**: Missing --config flag
**Solution**: Add `--config` flag: `"args": ["run", "--config", "/path/to/config.json"]`

### 3. Proxmox-MCP
**Problem**: Invalid URL format in host field
**Solution**: Use only hostname/IP without protocol:
```json
{
  "servers": {
    "default": {
      "host": "192.168.1.137",
      "port": 8006,
      "username": "root@pam",
      "password": "password"
    }
  },
  "default_server": "default"
}
```

### 4. WikiJS-MCP
**Problem**: Python module import error in virtual environment
**Solution**: Create .pth file: `/home/jeremy/.mcp/servers/wikijs-mcp/venv/lib/python3.11/site-packages/wikijs-mcp.pth`
Content: `/home/jeremy/.mcp/servers/wikijs-mcp/src`

## Remaining Issues

### Docker-based Servers (github, hass-mcp)
**Problem**: Docker daemon not running in WSL2
**Solution**: Start Docker service: `sudo service docker start`

### Proxmox Authentication
**Problem**: 401 authentication error
**Possible Solutions**:
- Verify credentials are correct
- Check if two-factor authentication is enabled
- Ensure API access is enabled for the user

## Important Notes
- Claude Code may cache configurations - restart after changes
- Config hierarchy: Parent .mcp.json > claude-code/settings.json > project configs
- Use absolute paths in all configurations
- Virtual environment servers need PYTHONPATH or .pth files for module resolution