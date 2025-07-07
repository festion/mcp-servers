#!/bin/bash
# MCP Integration Test Script
# Tests adding and configuring all MCP servers with Claude

set -e

# Source logging functions
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true

echo "=== MCP Integration Test ==="
echo "Testing adding all MCP servers to Claude configuration"

# Function to add and test an MCP server
test_mcp_server() {
    local name="$1"
    local command="$2"
    
    echo ""
    echo "Testing $name..."
    mcp_info "INTEGRATION" "Testing $name server: $command" 2>/dev/null || echo "Testing $name server"
    
    # Remove if already exists
    claude mcp remove "$name" 2>/dev/null || true
    
    # Add the server
    if claude mcp add "$name" "$command"; then
        echo "✅ $name added successfully"
        mcp_info "INTEGRATION" "$name server added successfully" 2>/dev/null || true
        return 0
    else
        echo "❌ $name failed to add"
        mcp_error "INTEGRATION" "$name server failed to add" 2>/dev/null || true
        return 1
    fi
}

# Test all MCP servers
echo ""
echo "Adding all MCP servers to Claude configuration..."

# Test each server
test_mcp_server "filesystem" "node /home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js /home/dev/workspace"
test_mcp_server "network-fs" "bash /home/dev/workspace/network-mcp-wrapper.sh"
test_mcp_server "code-linter" "bash /home/dev/workspace/code-linter-wrapper.sh"
test_mcp_server "proxmox" "bash /home/dev/workspace/proxmox-mcp-wrapper.sh"
test_mcp_server "home-assistant" "bash /home/dev/workspace/hass-mcp-wrapper.sh"
test_mcp_server "wikijs" "bash /home/dev/workspace/wikijs-mcp-wrapper.sh"
test_mcp_server "serena" "bash /home/dev/workspace/serena-mcp-wrapper.sh"
test_mcp_server "github" "bash /home/dev/workspace/github-wrapper.sh"

echo ""
echo "=== Final MCP Configuration ==="
claude mcp list

echo ""
echo "=== Integration Test Summary ==="
mcp_info "INTEGRATION" "Integration test completed" 2>/dev/null || echo "Integration test completed"

echo ""
echo "You can now test MCP functionality with individual servers using commands like:"
echo "  claude --mcp-server filesystem <command>"
echo "  claude --mcp-server network-fs <command>"
echo "  etc."