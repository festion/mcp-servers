#!/bin/bash
cd /home/dev/workspace

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "CODE_LINTER" "Starting Code Linter MCP server" 2>/dev/null || echo "Starting Code Linter MCP server"

# Check if code-linter-mcp is available
if [ -d "/home/dev/workspace/mcp-servers/mcp-servers/code-linter-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/mcp-servers/code-linter-mcp-server
    mcp_info "CODE_LINTER" "Found Code Linter server, starting with config" 2>/dev/null || echo "Found Code Linter server"
    uv run code-linter-mcp-server run --config config.json 2>/dev/null || python3 run_server.py
else
    mcp_error "CODE_LINTER" "Code Linter MCP server not found" 2>/dev/null || echo "ERROR: Code Linter MCP server not found"
    exit 1
fi
