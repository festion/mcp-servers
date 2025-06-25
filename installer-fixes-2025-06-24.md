# MCP Global Installer Fixes - June 24, 2025

## Issues Fixed

### 1. Slow Copy Operation Due to Deep Directory Nesting

**Problem**: The `shutil.copytree` operation was hanging when copying server directories that contained `venv` folders with 399+ nested directories, causing the installer to appear frozen.

**Root Cause**: The installer was copying all files and directories without filtering, including:
- Virtual environment directories (`venv/`) with deep Python package nesting
- Cache directories (`__pycache__/`)
- Git directories (`.git/`)
- Node modules (`node_modules/`)

**Solution**: Added an ignore function to `shutil.copytree` to skip unnecessary directories:

```python
def ignore_dirs(dir, files):
    ignored = {f for f in files if f in {'venv', '__pycache__', '.git', '.pytest_cache', 'node_modules'}}
    if ignored:
        logger.debug(f"Ignoring directories in {dir}: {ignored}")
    return ignored

shutil.copytree(server_src, install_dir, dirs_exist_ok=True, ignore=ignore_dirs)
```

**File**: `global-mcp-installer.py:247-256`

### 2. Proxmox MCP Virtual Environment Corruption

**Problem**: The proxmox-mcp server had an "Exec format error" when trying to execute the Python interpreter in its virtual environment.

**Root Cause**: The virtual environment Python executable was corrupted - instead of being a proper binary or symlink, it was a text file containing just "python3.11".

**Solution**: 
1. Removed the corrupted virtual environment: `rm -rf proxmox-mcp-server/venv`
2. Recreated a proper virtual environment: `python3 -m venv proxmox-mcp-server/venv --without-pip`

**Verification**: The new venv Python executable now works correctly: `Python 3.11.2`

## Impact

- **Performance**: Server installation is now significantly faster, completing in seconds instead of appearing to hang
- **Reliability**: The installer can now handle servers with existing virtual environments without corruption
- **Debugging**: Added debug logging to show which directories are being ignored during copy operations

## Files Modified

- `global-mcp-installer.py` - Added directory filtering to copytree operation
- `proxmox-mcp-server/venv/` - Recreated corrupted virtual environment

## Testing

- Successfully tested installation of `wikijs-mcp` server
- Verified proxmox-mcp Python interpreter is now functional
- Confirmed installer completes without hanging or errors