# Directory Polling MCP Server Fix Documentation

## Issue Summary
The directory-polling MCP server was causing 30-second timeout errors in Claude Code because it wasn't implementing the proper MCP (Model Context Protocol) standard.

## Problem Analysis
The original implementation (`mcp-directory-polling-server-simple.py`) used a custom JSON protocol instead of the official MCP JSON-RPC 2.0 specification:
- Missing proper JSON-RPC 2.0 envelope
- No standard MCP method handlers (initialize, tools/list, tools/call)
- Custom request/response format incompatible with MCP clients

## Solution
Created a new implementation (`mcp-directory-polling-server-fixed.py`) that properly implements MCP protocol:

### Key Fixes
1. **JSON-RPC 2.0 Compliance**: All messages follow `{"jsonrpc": "2.0", "id": ..., "method": ..., "params": ...}` format
2. **Standard MCP Methods**:
   - `initialize` - Server capability negotiation
   - `tools/list` - List available tools
   - `tools/call` - Execute tool functions
3. **Proper Error Handling**: Returns standard JSON-RPC error codes
4. **Protocol Versioning**: Supports MCP protocol version 2024-11-05

### Tools Provided
- **scan_directories**: Scan configured directories for files matching patterns
- **get_config**: Get current directory polling configuration  
- **update_watch_directory**: Update or add watch directory configuration

## Implementation Details

### File Structure
```
/home/dev/workspace/mcp-servers/directory-polling-server/
├── mcp-directory-polling-server-fixed.py    # Fixed implementation
├── mcp-directory-polling-server-simple.py   # Original (non-compliant)
└── mcp-directory-polling-server.py          # Legacy version
```

### Configuration
Server uses configuration file: `/home/dev/workspace/production-monitoring-config.json`

Default configuration includes:
- Monitoring `/home/dev/workspace` recursively
- File patterns: `*.md`, `*.py`, `*.js`, `*.json`, `*.yaml`, `*.yml`
- Excludes: `node_modules/**`, `.git/**`, `__pycache__/**`, `*.log`, `*.tmp`
- Size filters: 10 bytes to 1MB

### Wrapper Script Update
Updated `/home/dev/workspace/directory-polling-wrapper.sh` to use the fixed implementation:
```bash
# Before
exec python3 mcp-directory-polling-server-simple.py

# After  
exec python3 mcp-directory-polling-server-fixed.py
```

## Testing Results
✅ Server responds correctly to MCP initialize request  
✅ Implements proper JSON-RPC 2.0 protocol  
✅ No more 30-second timeout errors  
✅ Successfully re-added to Claude Code MCP configuration  

## Resolution Status
**RESOLVED** - Directory polling MCP server now functions correctly with proper MCP protocol compliance.

## Files Modified
- `/home/dev/workspace/mcp-servers/directory-polling-server/mcp-directory-polling-server-fixed.py` (created)
- `/home/dev/workspace/directory-polling-wrapper.sh` (updated)

## MCP Server Configuration
Re-added to Claude Code:
```bash
claude mcp add directory-polling "bash /home/dev/workspace/directory-polling-wrapper.sh"
```

Current MCP servers (9 total):
- network-fs
- filesystem  
- proxmox
- wikijs
- code-linter
- github
- home-assistant
- serena-enhanced
- directory-polling ✅