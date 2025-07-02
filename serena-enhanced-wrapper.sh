#!/bin/bash
# Enhanced Serena MCP Server 
# Properly implements MCP protocol with enhanced features

# Set working directory
cd /home/dev/workspace

# Logging setup
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || {
    mcp_info() { echo "[INFO] SERENA-ENHANCED: $*"; }
    mcp_warn() { echo "[WARN] SERENA-ENHANCED: $*"; }
    mcp_error() { echo "[ERROR] SERENA-ENHANCED: $*"; }
}

mcp_info "Starting Enhanced Serena MCP server"

# Check if Serena directory exists
if [ ! -d "/home/dev/workspace/serena" ]; then
    mcp_error "Serena directory not found at /home/dev/workspace/serena"
    exit 1
fi

cd /home/dev/workspace/serena

# Check if proper MCP server exists
if [ ! -f "scripts/mcp_server.py" ]; then
    mcp_error "Serena MCP server script not found at scripts/mcp_server.py"
    exit 1
fi

# Enhanced configuration for Serena
export SERENA_MODE="enhanced"
export SERENA_CONTEXT="mcp-enhanced"
export SERENA_LOG_LEVEL="info"

# Start Serena MCP server with proper environment
mcp_info "Starting Serena MCP server with enhanced configuration"

if command -v uv >/dev/null 2>&1; then
    # Use uv if available (preferred)
    exec uv run python scripts/mcp_server.py
else
    # Fallback to system Python
    exec python3 scripts/mcp_server.py
fi