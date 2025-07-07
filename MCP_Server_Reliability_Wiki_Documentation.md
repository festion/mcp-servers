# MCP Server Reliability Troubleshooting and Multi-Session Architecture

## Overview

This document details the comprehensive troubleshooting and architectural improvements implemented to resolve reliability issues with MCP (Model Context Protocol) servers, specifically the directory polling and Proxmox MCP servers, while designing a multi-session architecture to support concurrent development environments.

## Problem Analysis

### Initial Issues Identified

1. **Directory Polling Server Failures**
   - Non-MCP-compliant custom implementation
   - Multiple instances running simultaneously
   - Improper protocol handling causing connection failures

2. **Proxmox MCP Server Configuration Errors**
   - Missing required `password_env_var` configuration field
   - Token authentication validation failures
   - Startup errors preventing server initialization

3. **Multi-Session Conflicts**
   - No process isolation between terminal sessions
   - Shared configuration files causing conflicts
   - Orphaned processes accumulating over time
   - Port binding conflicts in concurrent sessions

### Root Cause Analysis

The MCP servers were designed for single-session use and lacked proper:
- Process lifecycle management
- Session isolation mechanisms
- Configuration conflict resolution
- Resource cleanup procedures

## Solution Architecture

### Multi-Session Management System

#### Session Manager

A comprehensive session management system providing:

**Core Features:**
- **Process Isolation**: Unique PID tracking per terminal session
- **Configuration Isolation**: Session-specific config directories
- **Automatic Cleanup**: Detection and removal of orphaned processes
- **Resource Management**: Dynamic port allocation and conflict prevention

**Session Directory Structure:**
```
/tmp/mcp-sessions/
├── pids/
│   └── {session_id}/
│       ├── proxmox.pid
│       ├── directory-polling.pid
│       └── ...
├── configs/
│   └── {session_id}/
│       ├── proxmox-config.json
│       └── ...
└── logs/
    └── {session_id}/
        ├── proxmox.log
        └── ...
```

**Session ID Generation:**
- Based on terminal session (`SSH_TTY` or `tty`)
- Sanitized for filesystem compatibility
- Unique across concurrent sessions

#### Key Functions

1. **Session Initialization**
   ```bash
   mcp-session-manager.sh init
   ```

2. **Process Management**
   ```bash
   # Start server with isolation
   mcp-session-manager.sh start <server_name> '<command>'
   
   # Stop server for current session
   mcp-session-manager.sh stop <server_name>
   ```

3. **Status Monitoring**
   ```bash
   # View session status and active servers
   mcp-session-manager.sh status
   ```

4. **Cleanup Operations**
   ```bash
   # Clean orphaned processes
   mcp-session-manager.sh cleanup
   ```

### Server-Specific Fixes

#### Proxmox MCP Server

**Configuration Fixes:**
- Added missing `password_env_var` field to `config.json`
- Implemented session-specific configuration copying
- Enhanced environment variable validation

**Multi-Session Enhancements:**
```bash
# Session isolation variables
SESSION_ID="${MCP_SESSION_ID:-$(echo "${SSH_TTY:-$(tty)}" | sed 's/[^a-zA-Z0-9]/_/g')}"
PID_FILE="${MCP_PID_FILE:-/tmp/mcp-sessions/pids/$SESSION_ID/proxmox.pid}"

# Session-specific configuration
SESSION_CONFIG_DIR="${MCP_CONFIG_DIR:-/tmp/mcp-sessions/configs/$SESSION_ID}"
cp config.json "$SESSION_CONFIG_DIR/proxmox-config.json"
```

**Error Handling:**
- Proper cleanup on exit signals (SIGINT, SIGTERM)
- PID file management with automatic cleanup
- Enhanced logging with session identification

#### Directory Polling Server Replacement

**Problem Resolution:**
- Replaced non-MCP-compliant custom polling server
- Implemented proper MCP protocol using filesystem server
- Maintained directory monitoring functionality

**New Implementation:**
```bash
# Use filesystem MCP server as MCP-compliant alternative
exec node "$FILESYSTEM_SERVER" /home/dev/workspace
```

**Benefits:**
- Full MCP protocol compliance
- Native integration with Claude Code
- Reliable connection handling
- Session isolation support

### Configuration Management

#### Session-Specific Configurations

Each session maintains isolated configurations to prevent conflicts:

**Proxmox Configuration Template:**
```json
{
  "servers": {
    "proxmox-primary": {
      "host": "your.proxmox.host",
      "username": "username",
      "realm": "pam",
      "token_env_var": "PROXMOX_TOKEN",
      "password_env_var": "PROXMOX_PASSWORD",
      "port": 8006,
      "verify_ssl": false,
      "timeout": 30
    }
  },
  "default_server": "proxmox-primary",
  "security": {
    "max_vms_per_operation": 10,
    "max_storage_gb": 500,
    "allowed_operations": ["snapshot", "backup", "monitor", "manage_vms", "cleanup"],
    "enable_destructive_operations": true
  },
  "logging": {
    "level": "INFO"
  }
}
```

#### Environment Variable Management

**Proxmox Server Environment:**
```bash
export PROXMOX_HOST="${PROXMOX_HOST:-your.proxmox.host}"
export PROXMOX_USER="${PROXMOX_USER:-username@realm}"
export PROXMOX_TOKEN="${PROXMOX_TOKEN:-your-token-here}"
export PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-placeholder}"
```

### Logging and Monitoring

#### Centralized Logging System

**Log Structure:**
- **Main Log**: Primary application log
- **Error Log**: Error-specific logging
- **Session Logs**: Per-session isolated logs

**Logging Functions:**
```bash
mcp_info "SERVER_NAME" "Message"
mcp_warn "SERVER_NAME" "Warning message"
mcp_error "SERVER_NAME" "Error message"
```

#### Session Monitoring

**Status Tracking:**
- Real-time process status monitoring
- PID file validation and cleanup
- Resource usage tracking per session

## Implementation Benefits

### Reliability Improvements

1. **Process Stability:**
   - Eliminated orphaned process accumulation
   - Proper signal handling and cleanup
   - Session-aware process management

2. **Configuration Integrity:**
   - Session-isolated configurations prevent conflicts
   - Automatic configuration copying and customization
   - Environment variable validation

3. **Error Recovery:**
   - Graceful handling of connection failures
   - Automatic retry mechanisms
   - Comprehensive error logging

### Multi-Session Support

1. **Concurrent Development:**
   - Multiple terminal sessions can run simultaneously
   - Independent MCP server instances per session
   - No resource conflicts between sessions

2. **Development Workflow:**
   - Supports multiple project development
   - Session-specific logging and monitoring
   - Independent configuration management

3. **Resource Management:**
   - Dynamic port allocation
   - Session-aware resource tracking
   - Automatic cleanup on session termination

## Usage Guidelines

### For Developers

#### Starting a New Development Session

1. **Initialize Session:**
   ```bash
   mcp-session-manager.sh init
   ```

2. **Check Session Status:**
   ```bash
   mcp-session-manager.sh status
   ```

3. **Use MCP Servers Normally:**
   ```bash
   claude mcp list
   /mcp
   ```

#### Troubleshooting

1. **Check Server Status:**
   ```bash
   mcp-session-manager.sh status
   ```

2. **Review Logs:**
   ```bash
   tail -f /path/to/logs/mcp-main.log
   ```

3. **Clean Up Issues:**
   ```bash
   mcp-session-manager.sh cleanup
   ```

#### Best Practices

1. **Session Management:**
   - Always run `init` when starting a new terminal session
   - Use `status` to monitor server health
   - Run `cleanup` if experiencing issues

2. **Development Workflow:**
   - Each terminal session operates independently
   - Monitor logs for debugging
   - Restart individual servers if needed

3. **Resource Cleanup:**
   - Sessions automatically clean up on exit
   - Manual cleanup available for troubleshooting
   - Monitor for orphaned processes

## Troubleshooting Reference

### Common Issues

1. **Server Won't Start:**
   - Check configuration files
   - Verify environment variables
   - Review error logs

2. **Session Conflicts:**
   - Run session cleanup
   - Check for orphaned processes
   - Restart affected services

3. **Performance Issues:**
   - Monitor resource usage
   - Check for memory leaks
   - Review concurrent session count

### Diagnostic Commands

```bash
# Check all MCP servers
claude mcp list

# Session diagnostics
mcp-session-manager.sh status

# Process monitoring
ps aux | grep -E "(proxmox|directory-polling)"

# Log analysis
tail -50 /path/to/logs/mcp-main.log
```

## Conclusion

The implemented multi-session architecture successfully resolves the reliability issues with MCP servers while providing a robust foundation for concurrent development workflows. The solution provides:

- **Reliability**: Stable server operation with proper error handling
- **Scalability**: Support for multiple concurrent development sessions
- **Maintainability**: Clear separation of concerns and comprehensive logging
- **Usability**: Simple commands for session management and troubleshooting

This architecture supports the development team's need for multiple concurrent terminal sessions while ensuring MCP server reliability and preventing resource conflicts.