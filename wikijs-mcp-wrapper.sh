#!/bin/bash
cd /home/dev/workspace
# Load WikiJS credentials from secure storage
source /home/dev/workspace/github-token-manager.sh
if ! load_credentials wikijs; then
    echo "ERROR: Failed to load WikiJS credentials"
    echo "Please run:"
    echo "  /home/dev/workspace/github-token-manager.sh store wikijs token <your_wikijs_token>"
    echo "  /home/dev/workspace/github-token-manager.sh store wikijs url <your_wikijs_url>"
    exit 1
fi

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "WIKIJS" "Starting WikiJS MCP server for URL: $WIKIJS_URL" 2>/dev/null || echo "Starting WikiJS MCP server"

# Check if WikiJS MCP server is available
if [ -d "/home/dev/workspace/mcp-servers/mcp-servers/wikijs-mcp-server" ]; then
    cd /home/dev/workspace/mcp-servers/mcp-servers/wikijs-mcp-server
    python3 run_server.py 2>/dev/null || PYTHONPATH=src python3 -m wikijs_mcp.server
else
    echo "WikiJS MCP server not found in mcp-servers directory."
    exit 1
fi