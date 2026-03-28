#!/bin/bash

# Prefer a static PAT (doesn't rotate) over gh CLI OAuth token (rotates and
# goes stale in long-lived MCP server processes).
# Create a classic PAT at: https://github.com/settings/tokens/new
# Required scopes: repo, read:org
if [ -f "/home/dev/.github_token" ]; then
    export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat /home/dev/.github_token)
fi

# Fall back to gh CLI OAuth token if no PAT file exists
if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ] && command -v gh &>/dev/null; then
    TOKEN=$(gh auth token 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        export GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"
    fi
fi

if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "ERROR: No GitHub token available. Create a PAT and store in /home/dev/.github_token, or run 'gh auth login'" >&2
    exit 1
fi

exec mcp-server-github
