#!/bin/bash
cd /home/dev/workspace/serena-real

# Check if serena-real exists, if not fall back to serena stub
if [ ! -d "/home/dev/workspace/serena-real" ]; then
    cd /home/dev/workspace/serena
    python mcp_server.py
else
    # Start the real Serena MCP server with appropriate settings
    uv run serena-mcp-server --context ide-assistant --project /home/dev/workspace
fi