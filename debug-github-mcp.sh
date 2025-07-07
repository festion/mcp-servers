#!/bin/bash
export GITHUB_PERSONAL_ACCESS_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-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}"

echo "=== Testing GitHub MCP Server ==="
echo "Token: ${GITHUB_PERSONAL_ACCESS_TOKEN:0:15}..."

echo "=== Testing with projects toolset ==="
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | timeout 10 docker run --rm -i -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" local-github-mcp stdio --toolsets projects

echo ""
echo "=== Testing with context toolset ==="
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | timeout 10 docker run --rm -i -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" local-github-mcp stdio --toolsets context