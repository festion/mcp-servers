#!/bin/bash
export GITHUB_PERSONAL_ACCESS_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-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}"

# Check if token is configured (allow test token for diagnostics)
if [ "$GITHUB_PERSONAL_ACCESS_TOKEN" = "your_github_token_here" ]; then
    echo "ERROR: GitHub MCP server requires configuration. Please set GITHUB_PERSONAL_ACCESS_TOKEN environment variable."
    echo "Example: export GITHUB_PERSONAL_ACCESS_TOKEN='ghp_your_actual_token'"
    exit 1
fi

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "GITHUB" "Starting GitHub MCP server with token: ${GITHUB_PERSONAL_ACCESS_TOKEN:0:15}..." 2>/dev/null || echo "Starting GitHub MCP server"

exec docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
  local-github-mcp \
  stdio --toolsets context,projects,repos,issues,pull_requests
