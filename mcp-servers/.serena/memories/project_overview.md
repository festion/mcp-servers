# MCP Servers Project Overview

## Purpose
Collection of Model Context Protocol (MCP) servers for various integrations including:
- **code-linter-mcp-server**: Code analysis and linting capabilities
- **network-mcp-server**: Network file system access (SMB/NFS)
- **wikijs-mcp-server**: WikiJS documentation management  
- **proxmox-mcp-server**: Proxmox virtual machine management

## Tech Stack
- **Language**: Python 3.x
- **Framework**: Model Context Protocol (MCP)
- **Package Management**: pip + requirements.txt
- **Virtual Environments**: venv for each server
- **Configuration**: JSON-based configuration files
- **Installation**: Custom installers with automatic dependency management

## Project Structure
```
mcp-servers/
├── global-mcp-installer.py     # Global installer/manager
├── install-all-mcp-servers.py  # Batch installer
├── code-linter-mcp-server/     # Code linting server
├── network-mcp-server/         # Network filesystem server
├── wikijs-mcp-server/          # WikiJS integration server
└── proxmox-mcp-server/         # Proxmox management server
```

Each server contains:
- `src/` - Source code with modular architecture
- `tests/` - Unit and integration tests
- `installer.py` - Individual server installer
- `test_startup.py` - Startup validation
- `requirements.txt` - Python dependencies
- `run_server.py` - Server entry point