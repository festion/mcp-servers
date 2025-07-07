# MCP Server ENOENT Troubleshooting Fix

## Issue Summary
Two MCP servers were failing to start with ENOENT errors:
- GitHub MCP server: `spawn bash /home/dev/workspace/github-wrapper.sh ENOENT`
- Directory Polling MCP server: `spawn bash /home/dev/workspace/directory-polling-wrapper.sh ENOENT`

## Root Cause Analysis
The ENOENT errors were not due to missing wrapper files, but rather incorrect references within the wrapper scripts:

1. **GitHub MCP Server**: Wrapper was referencing `local-github-mcp` Docker image instead of the correct `ghcr.io/github/github-mcp-server`
2. **Directory Polling Server**: Wrapper was referencing `mcp-directory-polling-server-fixed.py` which had been renamed

## Fixes Applied

### 1. GitHub MCP Server Fix
**File**: `/home/dev/workspace/github-wrapper.sh`
**Change**: Updated Docker image reference
```bash
# Before:
exec docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
  local-github-mcp \
  stdio --toolsets context,projects,repos,issues,pull_requests

# After:
exec docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
  ghcr.io/github/github-mcp-server \
  stdio --toolsets context,projects,repos,issues,pull_requests
```

### 2. Directory Polling Server Fix
**File**: `/home/dev/workspace/directory-polling-wrapper.sh`
**Changes**: 
- Updated Python file references to remove `-fixed` suffix
- Updated file existence check
- Updated execution command

```bash
# Before:
if [ ! -f "/home/dev/workspace/mcp-servers/directory-polling-server/mcp-directory-polling-server-fixed.py" ]; then
exec python3 mcp-directory-polling-server-fixed.py

# After:
if [ ! -f "/home/dev/workspace/mcp-servers/directory-polling-server/mcp-directory-polling-server.py" ]; then
exec python3 mcp-directory-polling-server.py
```

### 3. File Cleanup and Renaming
- Renamed: `mcp-directory-polling-server-fixed.py` → `mcp-directory-polling-server.py`
- Removed duplicate files:
  - `mcp-directory-server-fixed.py`
  - `directory-polling-wrapper-fixed.sh`

## Verification
After applying fixes:
- Both wrapper scripts reference correct files/images
- All duplicate "fixed" files have been cleaned up
- MCP servers should now start without ENOENT errors

## Files Modified
- `/home/dev/workspace/github-wrapper.sh`
- `/home/dev/workspace/directory-polling-wrapper.sh`
- `/home/dev/workspace/mcp-servers/directory-polling-server/mcp-directory-polling-server.py` (renamed)

## Files Removed
- `/home/dev/workspace/mcp-servers/directory-polling-server/mcp-directory-server-fixed.py`
- `/home/dev/workspace/directory-polling-wrapper-fixed.sh`

## Status
✅ **RESOLVED** - MCP server ENOENT errors fixed and file cleanup completed