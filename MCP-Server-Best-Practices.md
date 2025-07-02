# MCP Server Configuration Best Practices

## Quick Reference Guide

### ✅ Correct Configuration Pattern

```bash
# Add MCP server with direct script path
claude mcp add server-name "/absolute/path/to/script.sh"
```

### ❌ Avoid These Patterns

```bash
# Don't use shell prefixes
claude mcp add server-name "bash /path/to/script.sh"
claude mcp add server-name "sh /path/to/script.sh"
```

## Wrapper Script Template

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

mcp_info "Starting SERVER-NAME MCP server"

# Environment setup
export CONFIG_VAR="value"
export LOG_LEVEL="${LOG_LEVEL:-info}"

# Validation checks
if [ ! -f "/required/file/path" ]; then
    mcp_error "Required file not found"
    exit 1
fi

# Change to service directory if needed
cd /service/directory

# Start server with proper execution
mcp_info "Executing server process"
exec python3 server-script.py
```

## Common Issues & Solutions

### ENOENT Errors
- **Cause**: Bash prefix in command configuration
- **Fix**: Use direct script paths
- **Check**: File permissions and shebang line

### Permission Denied
- **Cause**: Missing executable permissions
- **Fix**: `chmod +x script.sh`
- **Verify**: `ls -la script.sh`

### Working Directory Issues
- **Cause**: Relative path dependencies
- **Fix**: Use absolute paths and explicit `cd` commands
- **Test**: Run script directly to verify paths

### Environment Variables
- **Cause**: Missing required environment setup
- **Fix**: Export all variables in wrapper script
- **Avoid**: Relying on shell session variables

## Testing Checklist

1. **Script Execution**: `/path/to/script.sh` runs without errors
2. **Permissions**: Script is executable (`ls -la`)
3. **Dependencies**: All required tools available (`which python3`)
4. **Environment**: All required variables exported
5. **MCP Integration**: Server responds to MCP protocol

## Verification Commands

```bash
# Test MCP servers
claude mcp list

# Test individual script
/home/dev/workspace/server-wrapper.sh

# Check permissions
ls -la /home/dev/workspace/*wrapper.sh

# Verify MCP integration
/mcp  # In Claude Code interface
```