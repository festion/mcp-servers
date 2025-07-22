#!/bin/bash

echo "=========================================="
echo "Home Assistant MCP Server Diagnostic Tool"
echo "=========================================="
echo

# Check environment variables
echo "1. Configuration Check:"
echo "   HA_URL: ${HA_URL:-http://192.168.1.155:8123}"
echo "   HA_TOKEN: ${HA_TOKEN:0:20}..." # Show first 20 chars only
echo

# Parse URL for testing
HA_URL_CHECK="${HA_URL:-http://192.168.1.155:8123}"
HOST=$(echo $HA_URL_CHECK | sed 's|http[s]*://||' | sed 's|:.*||')
PORT=$(echo $HA_URL_CHECK | sed 's|.*:||' | sed 's|/.*||')

echo "2. Network Connectivity Test:"
echo "   Host: $HOST"
echo "   Port: $PORT"

# Test host reachability
echo -n "   Ping test: "
if ping -c 1 -W 3 "$HOST" >/dev/null 2>&1; then
    echo "✓ Host is reachable"
else
    echo "✗ Host is not reachable"
    exit 1
fi

# Test port connectivity
echo -n "   Port test: "
if timeout 5 bash -c "</dev/tcp/$HOST/$PORT" >/dev/null 2>&1; then
    echo "✓ Port $PORT is open"
else
    echo "✗ Port $PORT is not accessible"
    echo "     This usually means:"
    echo "     - Home Assistant is not running"
    echo "     - Home Assistant is running on a different port"
    echo "     - Firewall is blocking access"
    exit 1
fi

# Test HTTP response
echo -n "   HTTP test: "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$HA_URL_CHECK")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Home Assistant web interface is responding"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "✗ No HTTP response (connection failed)"
    exit 1
else
    echo "⚠ HTTP response code: $HTTP_CODE"
fi

# Test API endpoint
echo -n "   API test: "
if [ -n "$HA_TOKEN" ] && [ "$HA_TOKEN" != "test-home-assistant-token-for-diagnostic" ]; then
    API_RESPONSE=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
                       -H "Content-Type: application/json" \
                       --connect-timeout 5 \
                       "$HA_URL_CHECK/api/")
    if echo "$API_RESPONSE" | grep -q "message.*API running"; then
        echo "✓ Home Assistant API is accessible"
    else
        echo "✗ API authentication failed or API not responding"
        echo "     Response: ${API_RESPONSE:0:100}..."
    fi
else
    echo "⚠ Using test token - cannot verify real API access"
fi

echo
echo "3. MCP Server Component Check:"

# Check if Docker is available
echo -n "   Docker: "
if command -v docker >/dev/null 2>&1; then
    echo "✓ Available"
    echo -n "   Docker image (voska/hass-mcp): "
    if docker images voska/hass-mcp | grep -q voska/hass-mcp; then
        echo "✓ Present"
    else
        echo "⚠ Not found (will try to pull when needed)"
    fi
else
    echo "⚠ Not available (will use Python)"
fi

# Check Python/uv
echo -n "   UV: "
if command -v uv >/dev/null 2>&1; then
    echo "✓ Available"
else
    echo "⚠ Not available (will use python3)"
fi

echo -n "   Python3: "
if command -v python3 >/dev/null 2>&1; then
    echo "✓ Available"
else
    echo "✗ Not available"
fi

# Check if HA MCP server directory exists
echo -n "   HA MCP Server: "
if [ -d "/home/dev/workspace/home-assistant-mcp-server" ]; then
    echo "✓ Directory exists"
    if [ -f "/home/dev/workspace/home-assistant-mcp-server/app/__main__.py" ]; then
        echo "                  ✓ Main module found"
    else
        echo "                  ✗ Main module missing"
    fi
else
    echo "✗ Directory not found"
fi

echo
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="