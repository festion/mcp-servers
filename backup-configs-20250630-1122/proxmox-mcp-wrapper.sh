#!/bin/bash
cd /home/dev/workspace
export PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.137}"
export PROXMOX_USER="${PROXMOX_USER:-root@pam}"
export PROXMOX_TOKEN="${PROXMOX_TOKEN:-your_proxmox_token_here}"

# Check if token is configured
if [ "$PROXMOX_TOKEN" = "your_proxmox_token_here" ]; then
    echo "ERROR: Proxmox MCP server requires configuration. Please set PROXMOX_TOKEN environment variable."
    echo "Example: export PROXMOX_TOKEN='PVEAPIToken=user@pam!tokenid=token-secret'"
    exit 1
fi

# Check if Proxmox MCP server is available
if [ -d "/home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server
    python3 run_server.py 2>/dev/null || uv run proxmox-mcp-server
else
    echo "Proxmox MCP server not found in mcp-servers directory."
    exit 1
fi