#!/bin/bash
cd /home/dev/workspace

# Load tokens from secure storage
if [ -f "/home/dev/.mcp_tokens/wikijs_url" ]; then
    export WIKIJS_URL=$(cat /home/dev/.mcp_tokens/wikijs_url)
else
    export WIKIJS_URL="${WIKIJS_URL:-http://192.168.1.90:3000}"
fi

if [ -f "/home/dev/.mcp_tokens/wikijs_token" ]; then
    export WIKIJS_TOKEN=$(cat /home/dev/.mcp_tokens/wikijs_token)
else
    export WIKIJS_TOKEN="${WIKIJS_TOKEN:-your_wikijs_token_here}"
fi

# Check if tokens are configured
if [ "$WIKIJS_URL" = "http://your-wikijs-instance" ] || [ "$WIKIJS_TOKEN" = "your_wikijs_token_here" ]; then
    echo "ERROR: WikiJS MCP server requires configuration. Please set WIKIJS_URL and WIKIJS_TOKEN environment variables or store in /home/dev/.mcp_tokens/"
    echo "Example: echo 'http://192.168.1.90:3000' > /home/dev/.mcp_tokens/wikijs_url && echo 'your-token' > /home/dev/.mcp_tokens/wikijs_token && chmod 600 /home/dev/.mcp_tokens/wikijs_*"
    exit 1
fi

# Check if WikiJS MCP server is available
if [ -d "/home/dev/workspace/mcp-servers/wikijs-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/wikijs-mcp-server
    python3 run_server.py 2>/dev/null || PYTHONPATH=src python3 -m wikijs_mcp.server
else
    echo "WikiJS MCP server not found in mcp-servers directory."
    exit 1
fi