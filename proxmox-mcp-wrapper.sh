#!/bin/bash
# Proxmox MCP Server Wrapper with Multi-Session Support
set -euo pipefail

cd /home/dev/workspace

# Multi-session support
SESSION_ID="${MCP_SESSION_ID:-$(echo "${SSH_TTY:-$(tty 2>/dev/null || echo unknown)}" | sed 's/[^a-zA-Z0-9]/_/g')}"
PID_FILE="${MCP_PID_FILE:-/tmp/mcp-sessions/pids/$SESSION_ID/proxmox.pid}"

# Environment setup
export PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.137}"
export PROXMOX_USER="${PROXMOX_USER:-root@pam}"
export PROXMOX_TOKEN="${PROXMOX_TOKEN:-PVEAPIToken=root@pam!homelab=redflower805}"
export PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-placeholder}"

# Validate configuration
if [ "$PROXMOX_TOKEN" = "your_proxmox_token_here" ]; then
    echo "ERROR: Proxmox MCP server requires configuration. Please set PROXMOX_TOKEN environment variable."
    echo "Example: export PROXMOX_TOKEN='PVEAPIToken=user@pam!tokenid=token-secret'"
    exit 1
fi

# Logging setup
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || {
    mcp_info() { echo "[INFO] PROXMOX: $*"; }
    mcp_warn() { echo "[WARN] PROXMOX: $*"; }
    mcp_error() { echo "[ERROR] PROXMOX: $*"; }
}

mcp_info "PROXMOX" "Starting Proxmox MCP server for session: $SESSION_ID"
mcp_info "PROXMOX" "Host: $PROXMOX_HOST, User: $PROXMOX_USER"

# Check server availability
SERVER_DIR="/home/dev/workspace/mcp-servers/mcp-servers/proxmox-mcp-server"
if [ ! -d "$SERVER_DIR" ]; then
    mcp_error "Proxmox MCP server not found at: $SERVER_DIR"
    exit 1
fi

cd "$SERVER_DIR"

# Session-specific configuration
SESSION_CONFIG_DIR="${MCP_CONFIG_DIR:-/tmp/mcp-sessions/configs/$SESSION_ID}"
mkdir -p "$SESSION_CONFIG_DIR"

# Copy base config and customize for session
cp config.json "$SESSION_CONFIG_DIR/proxmox-config.json"

# Load environment from .env if exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Cleanup function
cleanup() {
    mcp_info "PROXMOX" "Shutting down Proxmox MCP server for session: $SESSION_ID"
    [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

# Record PID
mkdir -p "$(dirname "$PID_FILE")"
echo $$ > "$PID_FILE"

# Start server with proper error handling
mcp_info "PROXMOX" "Starting Proxmox MCP server..."
exec python3 run_server.py run "$SESSION_CONFIG_DIR/proxmox-config.json"