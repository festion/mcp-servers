#!/bin/bash
# Fixed Directory Polling MCP Server Wrapper
# Proper MCP protocol implementation with multi-session support
set -euo pipefail

cd /home/dev/workspace

# Multi-session support
SESSION_ID="${MCP_SESSION_ID:-$(echo "${SSH_TTY:-$(tty 2>/dev/null || echo unknown)}" | sed 's/[^a-zA-Z0-9]/_/g')}"
PID_FILE="${MCP_PID_FILE:-/tmp/mcp-sessions/pids/$SESSION_ID/directory-polling.pid}"

# Logging setup
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || {
    mcp_info() { echo "[INFO] DIRECTORY-POLLING: $*"; }
    mcp_warn() { echo "[WARN] DIRECTORY-POLLING: $*"; }
    mcp_error() { echo "[ERROR] DIRECTORY-POLLING: $*"; }
}

mcp_info "DIRECTORY-POLLING" "Starting Directory Polling MCP server for session: $SESSION_ID"

# Check if filesystem MCP server is available (as fallback)
FILESYSTEM_SERVER="/home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js"
if [ ! -f "$FILESYSTEM_SERVER" ]; then
    mcp_error "Filesystem MCP server not found at: $FILESYSTEM_SERVER"
    exit 1
fi

# Session-specific working directory
SESSION_WORK_DIR="${MCP_CONFIG_DIR:-/tmp/mcp-sessions/configs/$SESSION_ID}/filesystem"
mkdir -p "$SESSION_WORK_DIR"

# Cleanup function
cleanup() {
    mcp_info "DIRECTORY-POLLING" "Shutting down Directory Polling MCP server for session: $SESSION_ID"
    [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

# Record PID
mkdir -p "$(dirname "$PID_FILE")"
echo $$ > "$PID_FILE"

# Use filesystem MCP server as proper MCP-compliant alternative
mcp_info "DIRECTORY-POLLING" "Using filesystem MCP server as directory polling replacement"
mcp_info "DIRECTORY-POLLING" "Monitoring workspace: /home/dev/workspace"

exec node "$FILESYSTEM_SERVER" /home/dev/workspace