#!/bin/bash
cd /home/dev/workspace

# Load Home Assistant credentials from secure storage
source /home/dev/workspace/github-token-manager.sh
if ! load_credentials hass; then
    echo "ERROR: Failed to load Home Assistant credentials"
    echo "Please run:"
    echo "  /home/dev/workspace/github-token-manager.sh store hass token <your_hass_token>"
    echo "  /home/dev/workspace/github-token-manager.sh store hass url <your_hass_url>"
    exit 1
fi

# Diagnostic mode - run connectivity test first
echo "Running Home Assistant connectivity test..."
if ! ./hass-mcp-diagnostic.sh >/dev/null 2>&1; then
    echo "WARNING: Home Assistant connectivity test failed"
    echo "Running diagnostic to identify issues..."
    ./hass-mcp-diagnostic.sh
    echo ""
    echo "To fix this issue:"
    echo "1. Ensure Home Assistant is running at $HA_URL"
    echo "2. Check firewall settings"
    echo "3. Update HA_URL environment variable if using different host/port"
    echo "4. Set a valid HA_TOKEN if testing against real instance"
    echo ""
    echo "Continuing with limited functionality (API calls will fail)..."
fi

# Token validation is handled by the token manager above

# Log startup attempt
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || true
mcp_info "HOME_ASSISTANT" "Starting Home Assistant MCP server for URL: $HA_URL" 2>/dev/null || echo "Starting Home Assistant MCP server"

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