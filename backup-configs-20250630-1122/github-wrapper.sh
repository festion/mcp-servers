#!/bin/bash
export GITHUB_PERSONAL_ACCESS_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-your_github_token_here}"

# Check if token is configured
if [ "$GITHUB_PERSONAL_ACCESS_TOKEN" = "your_github_token_here" ]; then
    echo "ERROR: GitHub MCP server requires configuration. Please set GITHUB_PERSONAL_ACCESS_TOKEN environment variable."
    echo "Example: export GITHUB_PERSONAL_ACCESS_TOKEN='ghp_your_actual_token'"
    exit 1
fi

docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" ghcr.io/github/github-mcp-server
