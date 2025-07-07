#!/bin/bash
cd /home/dev/workspace

# Environment variables with defaults
export HA_URL="${HA_URL:-http://192.168.1.175:8123}"
export HA_TOKEN="${HA_TOKEN:-your_hass_token_here}"

# Check if token is configured
if [ "$HA_TOKEN" = "your_hass_token_here" ]; then
    echo "ERROR: Home Assistant MCP server requires configuration. Please set HA_TOKEN environment variable."
    echo "Example: export HA_TOKEN='your-home-assistant-long-lived-access-token'"
    exit 1
fi

# Check if Home Assistant MCP server is available
if [ -d "/home/dev/workspace/home-assistant-mcp-server" ]; then
    cd /home/dev/workspace/home-assistant-mcp-server
    
    # Try Docker first (recommended), then fall back to Python/uv
    if command -v docker >/dev/null 2>&1; then
        # Use Docker if available
        docker run -i --rm -e HA_URL -e HA_TOKEN voska/hass-mcp 2>/dev/null || {
            echo "Docker image not available locally, trying to pull..."
            docker pull voska/hass-mcp >/dev/null 2>&1 && docker run -i --rm -e HA_URL -e HA_TOKEN voska/hass-mcp
        } || {
            echo "Docker execution failed, falling back to Python..."
            # Fall back to Python execution
            if command -v uv >/dev/null 2>&1; then
                uv run python -m app
            else
                python3 -m app
            fi
        }
    else
        # No Docker, use Python directly
        if command -v uv >/dev/null 2>&1; then
            uv run python -m app
        else
            python3 -m app
        fi
    fi
else
    echo "Home Assistant MCP server not found at /home/dev/workspace/home-assistant-mcp-server"
    exit 1
fi