#!/bin/bash
# Vikunja MCP Server Wrapper
# Handles Infisical auth with .env fallback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/../mcp-servers/vikunja-mcp-server"

# Default config
VIKUNJA_URL="${VIKUNJA_URL:-http://192.168.1.143:3456}"

# Try Infisical first (requires active session)
if [ -z "$VIKUNJA_API_TOKEN" ]; then
    TOKEN=$(cd "$SCRIPT_DIR/.." && infisical secrets get VIKUNJA_API_TOKEN --env=prod --plain 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        export VIKUNJA_API_TOKEN="$TOKEN"
        echo "Auth: Infisical" >&2
    fi
fi

# Fall back to .env file
if [ -z "$VIKUNJA_API_TOKEN" ] && [ -f "$SERVER_DIR/.env" ]; then
    export $(grep -v "^#" "$SERVER_DIR/.env" | grep -v "^$" | xargs)
    echo "Auth: .env fallback" >&2
fi

# Validate
if [ -z "$VIKUNJA_API_TOKEN" ]; then
    echo "ERROR: VIKUNJA_API_TOKEN not found in Infisical or .env" >&2
    exit 1
fi

export VIKUNJA_URL

cd "$SERVER_DIR" || exit 1
exec env PYTHONPATH=./src python3 -m vikunja_mcp.server
