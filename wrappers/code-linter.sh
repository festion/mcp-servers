#!/bin/bash
cd /home/dev/workspace

# Check if code-linter-mcp is available
if [ -d "/home/dev/workspace/mcp-servers/code-linter-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/code-linter-mcp-server
    python3 run_server.py --config code_linter_config.json
else
    echo "Code Linter MCP server not found in mcp-servers directory."
    exit 1
fi
