#!/bin/bash
# Home Assistant MCP Server Wrapper - Production Environment
# Target: Production Server (192.168.1.155)

export HASS_URL="http://192.168.1.155:8123"
export HASS_TOKEN="prod-ha-token-replace-with-real-token"

# Start the Home Assistant MCP server
exec /home/dev/workspace/home-assistant-mcp-server/dist/index.js