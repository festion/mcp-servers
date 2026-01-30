#!/bin/bash
cd /home/dev/workspace

# Load tokens from secure storage
if [ -f "/home/dev/.mcp_tokens/hass_url" ]; then
    export HA_URL=$(cat /home/dev/.mcp_tokens/hass_url)
else
    export HA_URL="${HA_URL:-https://homeassistant.internal.lakehouse.wtf}"
fi

if [ -f "/home/dev/.mcp_tokens/hass_token" ]; then
    export HA_TOKEN=$(cat /home/dev/.mcp_tokens/hass_token)
else
    export HA_TOKEN="${HA_TOKEN:-your_hass_token_here}"
fi

# Check if token is configured
if [ "$HA_TOKEN" = "your_hass_token_here" ]; then
    echo "ERROR: Home Assistant MCP server requires configuration." >&2
    echo "Please set HA_TOKEN environment variable or store token in /home/dev/.mcp_tokens/hass_token" >&2
    echo "Example: echo 'your-token' > /home/dev/.mcp_tokens/hass_token && chmod 600 /home/dev/.mcp_tokens/hass_token" >&2
    exit 1
fi

# Use Docker (recommended and simplest approach)
if command -v docker >/dev/null 2>&1; then
    exec docker run -i --rm -e HA_URL -e HA_TOKEN voska/hass-mcp
else
    echo "ERROR: Docker is required for the Home Assistant MCP server" >&2
    exit 1
fi
