# MCP Server Configuration Fix

## Problem
The MCP server is failing to start with error:
```
spawn /mnt/c/my-tools/linter ENOENT
```

This means Claude Desktop is configured to run `/mnt/c/my-tools/linter` (which translates to `C:\my-tools\linter` on Windows), but this file doesn't exist or isn't accessible.

## Root Cause
The MCP configuration in Claude Desktop is pointing to the wrong executable path. It should be pointing to either:
1. The `code-linter-mcp-server` command (if properly installed)
2. A proper wrapper script at the expected location

## Current State Analysis
- ✅ Code Linter MCP Server is built and functional at `C:\GIT\mcp-servers\code-linter-mcp-server\`
- ✅ Configuration file exists at `C:\GIT\mcp-servers\code-linter-mcp-server\config.json`
- ✅ Wrapper script updated at `C:\working\linter.bat`
- ❌ MCP configuration pointing to wrong path `/mnt/c/my-tools/linter`

## Solution Options

### Option 1: Fix MCP Configuration (Recommended)
Update Claude Desktop's MCP configuration to point to the correct command:

```json
{
  "mcpServers": {
    "code-linter": {
      "command": "python",
      "args": [
        "-m", "code_linter_mcp.cli", 
        "run", 
        "--config", 
        "C:\\GIT\\mcp-servers\\code-linter-mcp-server\\config.json"
      ],
      "cwd": "C:\\GIT\\mcp-servers\\code-linter-mcp-server",
      "env": {
        "PYTHONPATH": "C:\\GIT\\mcp-servers\\code-linter-mcp-server\\src"
      }
    }
  }
}
```

### Option 2: Create Expected File
If the MCP configuration can't be changed, create the file at the expected location:
1. Create directory `C:\my-tools\` 
2. Place a working `linter.bat` or `linter.exe` at `C:\my-tools\linter`

### Option 3: Use Working Directory Path
Update MCP configuration to use the corrected script:

```json
{
  "mcpServers": {
    "code-linter": {
      "command": "C:\\working\\linter.bat",
      "args": ["run", "--config", "C:\\GIT\\mcp-servers\\code-linter-mcp-server\\config.json"]
    }
  }
}
```

## Immediate Action Required
The user needs to update their Claude Desktop MCP configuration file (usually located in the Claude app settings) to use one of the above configurations.

## Testing the Fix
After updating the configuration:
1. Restart Claude Desktop
2. Check MCP server logs for successful startup
3. Test MCP server with: "Check if code linters are available"
