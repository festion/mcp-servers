# MCP Library Bug Report

## Summary
The MCP Python library version 1.10.1 has a critical bug that prevents any MCP server from listing tools correctly. The error `'tuple' object has no attribute 'name'` occurs when the `tools/list` method is called.

## Bug Details
- **Affected Version**: MCP Python library 1.10.1
- **Error Message**: `'tuple' object has no attribute 'name'`
- **Impact**: Complete failure of tool listing functionality in ALL MCP servers
- **Location**: Deep within the MCP library's tool serialization/processing code

## Investigation Results

### What We Tested
1. **Original complex tool definitions** - Failed with tuple error
2. **Simplified tool definitions** - Failed with tuple error  
3. **Single tool only** - Failed with tuple error
4. **Empty tools list** - Still failed with tuple error
5. **Minimal test server** - Failed with tuple error

### Key Findings
- The bug is NOT in the tool creation code
- The bug is NOT specific to the code-linter server
- The bug occurs even with empty tool lists
- The bug is in the MCP library's internal processing of the `@server.list_tools()` decorator
- Somewhere in the library, Tool objects are being incorrectly converted to tuples

### Root Cause
The MCP library's internal code is converting `types.Tool` objects to tuples during the JSON-RPC serialization process, but then attempting to access the `.name` attribute as if they were still Tool objects.

## Reproduction Steps
1. Install MCP library version 1.10.1: `pip install mcp==1.10.1`
2. Create any MCP server with a `@server.list_tools()` handler
3. Start the server and send a `tools/list` JSON-RPC request
4. Observe the error: `'tuple' object has no attribute 'name'`

## Current Status
- **Code-linter server**: Tool definitions are correct but non-functional due to library bug
- **Workaround**: None available - bug is too deep in the library
- **Impact**: Server starts successfully but tools cannot be listed or used

## Recommended Actions
1. **Report bug** to MCP library maintainers
2. **Downgrade** to earlier MCP library version if possible
3. **Wait** for library fix before using the code-linter server
4. **Test** with newer MCP library versions when available

## Test Environment
- Python: 3.11
- MCP Library: 1.10.1
- Platform: Linux
- Date: 2025-06-30

## Files Affected
- All MCP servers using version 1.10.1
- Specifically: `/home/dev/workspace/mcp-servers/mcp-servers/code-linter-mcp-server/`

## Next Steps
Monitor MCP library releases for a fix to this critical bug. The code-linter server implementation is correct and will work once the library bug is resolved.