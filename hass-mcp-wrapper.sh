#!/bin/bash
cd /home/dev/workspace

# Environment variables with defaults
export HA_URL="${HA_URL:-http://192.168.1.155:8123}"
export HA_TOKEN="${HA_TOKEN:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiOTJkNDM5Yjg2OTU0YWFmOTAwZmVhZmMyMmI1NjlhNCIsImlhdCI6MTc1MTQ5NjEyMiwiZXhwIjoyMDY2ODU2MTIyfQ.VnAswhqcZsIR4grBirx2IjdI3bvxCC2A0fKwVv4OXkQ}"

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

# Check if token is configured (allow test token for diagnostics)
if [ "$HA_TOKEN" = "your_hass_token_here" ]; then
    echo "ERROR: Home Assistant MCP server requires configuration. Please set HA_TOKEN environment variable."
    echo "Example: export HA_TOKEN='your-home-assistant-long-lived-access-token'"
    exit 1
fi

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