# MCP Server ENOENT Error Troubleshooting Guide

## Overview

This document provides comprehensive troubleshooting guidance for the ENOENT (Error No Entry) errors that were occurring with Claude Code MCP servers, specifically the `serena-enhanced` and `directory-polling` MCP servers.

## Problem Summary

### Issue Description
Multiple MCP servers were failing to start with ENOENT errors, preventing proper integration with Claude Code's MCP (Model Context Protocol) system.

### Affected Servers
- `serena-enhanced` MCP server
- `directory-polling` MCP server
- Various other custom MCP server implementations

### Error Symptoms
```
Error: spawn ENOENT
    at Process.ChildProcess._handle.onexit (node:internal/child_process:284:19)
    at onErrorNT (node:internal/child_process:477:16)
    at processTicksAndRejections (node:internal/process/task_queues:83:21)
```

## Root Cause Analysis

### Primary Issue: Bash Prefix in Command Configuration

The root cause was identified as improper command configuration in Claude Code's MCP server setup. Specifically:

1. **Incorrect Configuration Pattern**:
   ```json
   {
     "command": "bash",
     "args": ["/path/to/wrapper-script.sh"]
   }
   ```

2. **Issue Details**:
   - Using `"bash"` as the command with script path as an argument
   - Claude Code's MCP protocol interpreter was unable to locate the bash executable in the expected context
   - This caused the ENOENT (file not found) error during process spawning

### Secondary Issues

1. **Script Execution Permissions**:
   - Some wrapper scripts lacked proper executable permissions
   - Scripts needed `chmod +x` to be directly executable

2. **Working Directory Context**:
   - Scripts were not properly setting their working directory
   - Relative path dependencies were failing

3. **Environment Variable Propagation**:
   - Environment variables were not properly inherited by spawned processes
   - Configuration variables were missing in the execution context

## Solution Implementation

### 1. Command Configuration Fix

**Before (Problematic)**:
```bash
claude mcp add serena-enhanced "bash /home/dev/workspace/serena-enhanced-wrapper.sh"
```

**After (Fixed)**:
```bash
claude mcp add serena-enhanced "/home/dev/workspace/serena-enhanced-wrapper.sh"
```

### 2. Script Structure Improvements

All wrapper scripts were updated with the following pattern:

```bash
#!/bin/bash
# MCP Server Wrapper Template

# Set working directory explicitly
cd /home/dev/workspace

# Logging setup with fallback
source /home/dev/workspace/mcp-logger.sh 2>/dev/null || {
    mcp_info() { echo "[INFO] SERVER-NAME: $*"; }
    mcp_warn() { echo "[WARN] SERVER-NAME: $*"; }
    mcp_error() { echo "[ERROR] SERVER-NAME: $*"; }
}

# Environment setup
export RELEVANT_ENV_VARS="values"

# Validation checks
if [ ! -f "required-file" ]; then
    mcp_error "Required file not found"
    exit 1
fi

# Start server with proper execution
exec python3 server-script.py
```

### 3. File Permissions Fix

```bash
# Made all wrapper scripts executable
chmod +x /home/dev/workspace/*-wrapper.sh

# Verified permissions
ls -la /home/dev/workspace/*wrapper.sh
```

## Current Server Status (Post-Fix)

### All 9 MCP Servers Status

| Server | Command | Status | Notes |
|--------|---------|--------|-------|
| filesystem | `node /home/dev/workspace/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js /home/dev/workspace` | ✅ Active | Node.js based, unaffected |
| network-fs | `bash /home/dev/workspace/network-mcp-wrapper.sh` | ⚠️ Still using bash prefix | Needs update |
| home-assistant | `/home/dev/workspace/hass-mcp-wrapper.sh` | ✅ Fixed | Direct script execution |
| proxmox | `/home/dev/workspace/proxmox-mcp-wrapper.sh` | ✅ Fixed | Direct script execution |
| serena-enhanced | `/home/dev/workspace/serena-enhanced-wrapper.sh` | ✅ Fixed | ENOENT resolved |
| directory-polling | `/home/dev/workspace/directory-polling-wrapper.sh` | ✅ Fixed | ENOENT resolved |
| wikijs | `/home/dev/workspace/wikijs-mcp-wrapper.sh` | ✅ Fixed | Direct script execution |
| code-linter | `/home/dev/workspace/code-linter-wrapper.sh` | ✅ Fixed | Direct script execution |
| github | `/home/dev/workspace/github-wrapper.sh` | ✅ Fixed | Direct script execution |

### Configuration Commands Used

```bash
# Remove problematic configurations
claude mcp remove serena-enhanced
claude mcp remove directory-polling

# Add fixed configurations
claude mcp add serena-enhanced "/home/dev/workspace/serena-enhanced-wrapper.sh"
claude mcp add directory-polling "/home/dev/workspace/directory-polling-wrapper.sh"

# Verify current configuration
claude mcp list
```

## Best Practices for MCP Server Configuration

### 1. Command Configuration

✅ **DO**: Use direct script paths
```bash
claude mcp add server-name "/absolute/path/to/script.sh"
```

❌ **DON'T**: Use shell prefixes
```bash
claude mcp add server-name "bash /path/to/script.sh"
```

### 2. Script Structure

✅ **DO**: Include proper shebang and make executable
```bash
#!/bin/bash
# Script content...
chmod +x script.sh
```

✅ **DO**: Set working directory explicitly
```bash
cd /absolute/working/directory
```

✅ **DO**: Include error handling and logging
```bash
if [ ! -f "required-file" ]; then
    echo "[ERROR] Required file not found"
    exit 1
fi
```

### 3. Environment Management

✅ **DO**: Export required environment variables
```bash
export CONFIG_VAR="value"
export LOG_LEVEL="info"
```

✅ **DO**: Use absolute paths for all file references
```bash
CONFIG_FILE="/absolute/path/to/config.json"
```

### 4. Process Execution

✅ **DO**: Use `exec` for the final command
```bash
exec python3 server.py
```

This ensures proper process replacement and signal handling.

## Verification Steps

### 1. Test Individual Scripts
```bash
# Run each wrapper script directly
/home/dev/workspace/serena-enhanced-wrapper.sh
/home/dev/workspace/directory-polling-wrapper.sh
```

### 2. Test MCP Integration
```bash
# Use Claude Code's MCP test command
/mcp

# Check server status
claude mcp list
```

### 3. Monitor Logs
```bash
# Check for startup errors
tail -f /var/log/claude-mcp.log  # if logging is configured
```

## Common Troubleshooting Steps

### If ENOENT Errors Persist:

1. **Check File Permissions**:
   ```bash
   ls -la /path/to/script.sh
   chmod +x /path/to/script.sh
   ```

2. **Verify Shebang Line**:
   ```bash
   head -1 script.sh  # Should show #!/bin/bash
   ```

3. **Test Script Execution**:
   ```bash
   /path/to/script.sh  # Should run without errors
   ```

4. **Check Dependencies**:
   ```bash
   which python3
   which node
   which uv  # if used
   ```

5. **Remove and Re-add MCP Server**:
   ```bash
   claude mcp remove problematic-server
   claude mcp add problematic-server "/absolute/path/to/script.sh"
   ```

### Environment-Specific Issues:

1. **Working Directory Problems**:
   - Always use absolute paths
   - Set working directory explicitly in scripts

2. **Environment Variable Issues**:
   - Export all required variables in wrapper scripts
   - Don't rely on shell session variables

3. **Process Spawning Issues**:
   - Use `exec` for final command execution
   - Avoid complex shell constructs in wrapper scripts

## Future Prevention

1. **Template Usage**: Use the provided wrapper script template for new MCP servers
2. **Testing Protocol**: Always test scripts individually before MCP integration
3. **Documentation**: Document any environment-specific requirements
4. **Monitoring**: Implement proper logging for all MCP servers

## Related Files

- `/home/dev/workspace/CLAUDE.md` - Main MCP server configuration documentation
- `/home/dev/workspace/*-wrapper.sh` - Individual MCP server wrapper scripts
- `/home/dev/workspace/mcp-logger.sh` - Shared logging utilities

## Revision History

- **2025-07-02**: Initial documentation of ENOENT fixes and troubleshooting guide
- **2025-06-30**: Original ENOENT errors identified and initial fixes applied