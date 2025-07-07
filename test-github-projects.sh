#!/bin/bash
export GITHUB_PERSONAL_ACCESS_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-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}"

echo "Testing GitHub MCP server with projects toolset..."
echo "Token: ${GITHUB_PERSONAL_ACCESS_TOKEN:0:15}..."

# Test with projects toolset only
echo "=== Testing with projects toolset ==="
timeout 10 docker run --rm -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" local-github-mcp stdio --toolsets projects <<< '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq -r '.result.tools[]? | select(.name | contains("project")) | .name' 2>/dev/null | head -5

# Test with all toolsets
echo "=== Testing with all toolsets ==="
timeout 10 docker run --rm -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" local-github-mcp stdio --toolsets all <<< '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq -r '.result.tools[]? | select(.name | contains("project")) | .name' 2>/dev/null | head -5