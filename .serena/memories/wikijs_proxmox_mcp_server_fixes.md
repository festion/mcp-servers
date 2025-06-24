# WikiJS and Proxmox MCP Server Fixes

## Overview
Both WikiJS and Proxmox MCP servers were not starting due to configuration and setup issues following the MCP ecosystem restructure.

## WikiJS MCP Server Issues and Fixes

### Issues:
1. **Package not installed**: The wikijs_mcp module was not installed in the virtual environment
2. **Invalid regex patterns**: Security configuration had shell wildcard patterns instead of proper regex
3. **Wrong Python path**: .mcp.json referenced system Python instead of venv Python

### Fixes Applied:
1. **Installed package**: `cd wikijs-mcp-server && venv/bin/pip install -e .`
2. **Fixed regex patterns in config/wikijs_mcp_config.json**:
   - `"*.private.*"` → `".*\\.private\\..*"`
   - `"secret*"` → `"secret.*"` 
   - `"*.key"` → `".*\\.key"`
   - `"*.pem"` → `".*\\.pem"`
   - `"*.env"` → `".*\\.env"`
   - `"*.config.js"` → `".*\\.config\\.js"`
3. **Updated .mcp.json**: Changed command to `/mnt/c/GIT/mcp-servers/wikijs-mcp-server/venv/bin/python`

## Proxmox MCP Server Issues and Fixes

### Issues:
1. **Missing run script**: No proper entry point script for the server
2. **Direct CLI invocation**: .mcp.json was calling cli.py directly which caused import errors

### Fixes Applied:
1. **Created run_server.py**:
   ```python
   #!/usr/bin/env python3
   import sys
   import os
   from pathlib import Path
   
   current_dir = Path(__file__).parent
   src_dir = current_dir / "src"
   sys.path.insert(0, str(src_dir))
   
   if __name__ == "__main__":
       from proxmox_mcp.cli import main
       main()
   ```

2. **Updated .mcp.json configuration**:
   ```json
   "proxmox-mcp": {
     "command": "/mnt/c/GIT/mcp-servers/proxmox-mcp-server/venv/bin/python",
     "args": [
       "/mnt/c/GIT/mcp-servers/proxmox-mcp-server/run_server.py",
       "run",
       "/mnt/c/GIT/mcp-servers/proxmox-mcp-server/config.json"
     ]
   }
   ```

## Testing
Created test_startup.py scripts for both servers to verify they initialize without hanging. Both servers now pass startup tests.

## Key Learnings
1. MCP servers expect stdio input and will hang if run directly without proper test harness
2. Regex patterns in configs must be valid Python regex, not shell wildcards
3. Always use virtual environment Python for MCP servers
4. Proper entry point scripts are essential for module imports to work correctly