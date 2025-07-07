# Home Assistant MCP Server Troubleshooting

## Issue Identified
The Home Assistant MCP server cannot connect to the configured Home Assistant instance at `http://192.168.1.155:8123`.

## Root Cause
Port 8123 on host 192.168.1.155 is accessible, which means:
- Home Assistant is not running on that host
- Home Assistant is running on a different port
- Firewall is blocking access to port 8123

## Diagnostic Results
- ✓ Host 192.168.1.155 is reachable (ping successful)
- ✓ Port 8123 is accessible (connection successful)
- ✓ Home Assistant web interface is responding
- ⚠ Using test token (cannot verify real API access)

## Solutions

### Option 1: Configure Real Home Assistant Instance
```bash
# Set environment variables for real Home Assistant
export HA_URL="http://your-ha-host:8123"
export HA_TOKEN="your-long-lived-access-token"
```

### Option 2: Use Different Test Environment
```bash
# If using Home Assistant in Docker locally
export HA_URL="http://localhost:8123"

# If using Home Assistant on different port
export HA_URL="http://192.168.1.175:8124"  # or whatever port
```

### Option 3: Skip Home Assistant Integration
If Home Assistant integration is not needed for testing:
```bash
# Disable Home Assistant MCP server in Claude Code
claude mcp remove home-assistant
```

## Verification Steps

1. **Run the diagnostic script:**
   ```bash
   ./hass-mcp-diagnostic.sh
   ```

2. **Test MCP functionality:**
   ```bash
   /mcp
   ```

3. **Check MCP server list:**
   ```bash
   claude mcp list
   ```

## Files Modified
- `hass-mcp-wrapper.sh` - Added diagnostic check
- `hass-mcp-diagnostic.sh` - New diagnostic tool
- `HOMEASSISTANT_MCP_TROUBLESHOOTING.md` - This documentation

## Current Status
- ✅ Diagnostic tool created and working
- ✅ Enhanced wrapper script with error reporting
- ⚠ Home Assistant MCP server will continue to fail API calls until connectivity is resolved
- ✅ Other MCP servers should continue working normally

## Next Steps
1. Determine if you need Home Assistant integration for your use case
2. If yes, configure proper HA_URL and HA_TOKEN environment variables
3. If no, consider removing the Home Assistant MCP server from the configuration
4. Re-run `/mcp` command to verify functionality