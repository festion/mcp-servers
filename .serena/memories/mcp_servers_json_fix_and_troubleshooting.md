# MCP Servers JSON Configuration Fix and Troubleshooting

## Issue Fixed
- Fixed invalid JSON syntax in `/mnt/c/GIT/mcp-servers/.mcp.json`
- Removed trailing comma after wikijs-mcp args array that was preventing servers from loading

## MCP Server Status
- **GitHub MCP**: Working correctly via Docker (`ghcr.io/github/github-mcp-server`)
- **WikiJS MCP**: Configured but wasn't loading due to JSON syntax error
- **Proxmox MCP**: Configured but wasn't loading due to JSON syntax error
- **Network-fs**: Working
- **Serena**: Working
- **Hass-mcp**: Working via Docker
- **Filesystem**: Working via npx

## Troubleshooting Steps for MCP Servers
1. Check logs: `/mnt/c/Users/Jeremy/AppData/Roaming/Claude/logs/mcp-server-{name}.log`
2. Validate JSON: `python3 -m json.tool /mnt/c/GIT/mcp-servers/.mcp.json`
3. Test server directly: `{venv}/bin/python {server}/run_server.py --help`
4. Check virtual environment dependencies: `{venv}/bin/pip list`

## Configuration Paths
- WikiJS config: `/mnt/c/GIT/mcp-servers/wikijs-mcp-server/config/wikijs_mcp_config.json`
- Proxmox config: `/mnt/c/GIT/mcp-servers/proxmox-mcp-server/config.json`

## GitHub Token
- Token is valid and authenticated as user "festion"
- Token starts with: ghp_SL4Ninm7...</content>
</invoke>