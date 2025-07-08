#!/bin/bash
# Load GitHub token from secure storage
eval "$(/home/dev/workspace/github-token-manager.sh load github 2>/dev/null)" || {
    echo "ERROR: Failed to load GitHub token"
    echo "Please run: /home/dev/workspace/github-token-manager.sh store github token <your_token>"
    exit 1
}

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "GITHUB" "Starting GitHub MCP server with token: ${GITHUB_PERSONAL_ACCESS_TOKEN:0:15}..." 2>/dev/null || echo "Starting GitHub MCP server"

exec docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
  local-github-mcp \
  stdio --toolsets context,projects,repos,issues,pull_requests
