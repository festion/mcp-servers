#!/bin/bash
cd /home/dev/workspace
export WIKIJS_URL="${WIKIJS_URL:-http://192.168.1.90:3000}"
export WIKIJS_TOKEN="${WIKIJS_TOKEN:-eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcGkiOjIsImdycCI6MSwiaWF0IjoxNzUwNjg5NzQ0LCJleHAiOjE3NTMyODE3NDQsImF1ZCI6InVybjp3aWtpLmpzIiwiaXNzIjoidXJuOndpa2kuanMifQ.rcGzUI_zmRmFhin90HM2BuB6n4CcCUYY2kHBL7aYg2C114U1GkAD_UHIEmo-6lH-qFESgh34MBTs_6-WUCxDQIg-Y2rPeKZqY8nnFrwrrFwXu6s3cyomHw4QclHWa1_OKs0BCausZWYWkgLagELx3WNw42Zs8YqH0yfjYqNQFy-Vh1jAphtoloFtKRZ0DIWSYE-oxwDywu3Qkh5XFIf0hZKOAu3XKD8da0G3WFpw4JB9v7ubHYNHJBdzp8RpLov-f6Xh5AYGuel1N4PCIbVRegpCKUVbHwZgYHrkTWwae-8D_9tphg1zAbGoQQ2bU-IPsFfcyFg8RDYViJiH2qaL0g}"

# Check if tokens are configured (allow test tokens for diagnostics)
if [ "$WIKIJS_URL" = "http://your-wikijs-instance" ] || [ "$WIKIJS_TOKEN" = "your_wikijs_token_here" ]; then
    echo "ERROR: WikiJS MCP server requires configuration. Please set WIKIJS_URL and WIKIJS_TOKEN environment variables."
    echo "Example: export WIKIJS_URL='https://wiki.example.com' && export WIKIJS_TOKEN='your-actual-token'"
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