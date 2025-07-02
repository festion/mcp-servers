#!/bin/bash
cd /home/dev/workspace

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "NETWORK_FS" "Starting Network-FS MCP server" 2>/dev/null || echo "Starting Network-FS MCP server"

# Check if Network-FS MCP server is available
if [ -d "/home/dev/workspace/mcp-servers/mcp-servers/network-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/mcp-servers/network-mcp-server
    mcp_info "NETWORK_FS" "Found Network-FS server, starting with config" 2>/dev/null || echo "Found Network-FS server"
    uv run python run_server.py run --config config.json 2>/dev/null || python3 run_server.py run --config config.json
else
    mcp_error "NETWORK_FS" "Network-FS MCP server not found" 2>/dev/null || echo "ERROR: Network-FS MCP server not found"
    exit 1
fi
