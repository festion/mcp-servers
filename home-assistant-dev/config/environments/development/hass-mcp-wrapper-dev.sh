#!/bin/bash
# Home Assistant MCP Server Wrapper - Development Environment
# Target: LXC 128 (192.168.1.128)

export HASS_URL="http://192.168.1.239:8123"
export HASS_TOKEN="dev-ha-token-replace-with-real-token"

# Start the Home Assistant MCP server
exec /home/dev/workspace/home-assistant-mcp-server/dist/index.js