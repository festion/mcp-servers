#!/bin/bash
cd /home/dev/workspace

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "SERENA" "Starting Serena MCP server" 2>/dev/null || echo "Starting Serena MCP server"

# Check if real Serena exists, if not fall back to stub
if [ -d "/home/dev/workspace/serena" ]; then
    cd /home/dev/workspace/serena
    # Check if this is the real Serena (has mcp_server.py in scripts/)
    if [ -f "scripts/mcp_server.py" ]; then
        mcp_info "SERENA" "Using real Serena implementation" 2>/dev/null || echo "Using real Serena implementation"
        # Use uv to run with proper dependencies
        if command -v uv >/dev/null 2>&1; then
            uv run python scripts/mcp_server.py
        else
            PYTHONPATH=src python3 scripts/mcp_server.py
        fi
    else
        mcp_warn "SERENA" "Real Serena found but missing mcp_server.py, checking for alternative startup" 2>/dev/null || echo "Warning: mcp_server.py not found"
        # Try alternative startup methods
        if command -v uv >/dev/null 2>&1; then
            uv run serena-mcp-server --context ide-assistant --project /home/dev/workspace
        else
            echo "ERROR: uv not found and mcp_server.py missing"
            exit 1
        fi
    fi
else
    # Fall back to stub if available
    if [ -d "/home/dev/workspace/serena-stub-backup" ]; then
        cd /home/dev/workspace/serena-stub-backup
        mcp_warn "SERENA" "Using stub implementation" 2>/dev/null || echo "Warning: Using stub implementation"
        python3 mcp_server.py
    else
        mcp_error "SERENA" "No Serena implementation found" 2>/dev/null || echo "ERROR: No Serena implementation found"
        exit 1
    fi
fi