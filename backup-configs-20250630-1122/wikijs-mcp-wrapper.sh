#!/bin/bash
cd /home/dev/workspace
export WIKIJS_URL="${WIKIJS_URL:-http://your-wikijs-instance}"
export WIKIJS_TOKEN="${WIKIJS_TOKEN:-your_wikijs_token_here}"

# Check if tokens are configured
if [ "$WIKIJS_URL" = "http://your-wikijs-instance" ] || [ "$WIKIJS_TOKEN" = "your_wikijs_token_here" ]; then
    echo "ERROR: WikiJS MCP server requires configuration. Please set WIKIJS_URL and WIKIJS_TOKEN environment variables."
    echo "Example: export WIKIJS_URL='https://wiki.example.com' && export WIKIJS_TOKEN='your-actual-token'"
    exit 1
fi

# Check if WikiJS MCP server is available
if [ -d "/home/dev/workspace/mcp-servers/mcp-servers/wikijs-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/mcp-servers/wikijs-mcp-server
    python3 run_server.py 2>/dev/null || PYTHONPATH=src python3 -m wikijs_mcp.server
else
    echo "WikiJS MCP server not found in mcp-servers directory."
    exit 1
fi