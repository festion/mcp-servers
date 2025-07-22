#!/bin/bash
# Home Assistant MCP Server Wrapper - Testing Environment  
# Target: LXC 129 (192.168.1.129)

export HASS_URL="http://192.168.1.129:8123"
export HASS_TOKEN="test-ha-token-replace-with-real-token"

# Start the Home Assistant MCP server
exec /home/dev/workspace/home-assistant-mcp-server/dist/index.js