#!/bin/bash
cd /home/dev/workspace
export PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.137}"
export PROXMOX_USER="${PROXMOX_USER:-root@pam}"
export PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-redflower805}"

# Check if password is configured (allow test password for diagnostics)
if [ "$PROXMOX_PASSWORD" = "your_proxmox_password_here" ]; then
    echo "ERROR: Proxmox MCP server requires configuration. Please set PROXMOX_PASSWORD environment variable."
    echo "Example: export PROXMOX_PASSWORD='your-password-here'"
    exit 1
fi

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "PROXMOX" "Starting Proxmox MCP server with host: ${PROXMOX_HOST}..." 2>/dev/null || echo "Starting Proxmox MCP server"

# Check if Proxmox MCP server is available
if [ -d "/home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server
    # Load environment variables from .env file
    if [ -f ".env" ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi
    python3 run_server.py run config.json 2>/dev/null || uv run proxmox-mcp-server
else
    echo "Proxmox MCP server not found in mcp-servers directory."
    exit 1
fi