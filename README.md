# MCP Servers Collection

A collection of Model Context Protocol (MCP) servers that extend Claude Desktop's capabilities by providing access to various external systems and services.

## Available MCP Servers

### 🌐 Network MCP Server
**Status**: ✅ Complete and Functional  
**Location**: `network-mcp-server/`

Provides access to network filesystems including SMB/CIFS shares, with extensibility for NFS, FTP, and other protocols.

**Features**:
- SMB/CIFS support for Windows shares and Samba servers
- 7 MCP tools for file operations (read, write, list, delete, create directories, get info)
- Comprehensive security controls and validation
- Claude Desktop integration ready

### 🔍 Code Linter MCP Server  
**Status**: ✅ Complete and Functional  
**Location**: `code-linter-mcp-server/`

Comprehensive code linting and validation for multiple programming languages with Serena workflow integration.

**Features**:
- Multi-language support (Python, Go, JavaScript, TypeScript, YAML, JSON)
- 6 MCP tools for code quality validation
- **Serena Integration**: Blocks code saves when quality standards aren't met
- Security validation and content scanning
- Concurrent linter execution with result caching

**Critical Integration**: Ensures Serena never saves code that hasn't passed quality validation.

### 🖥️ Proxmox MCP Server
**Status**: ✅ Complete and Functional  
**Location**: `proxmox-mcp-server/`

Comprehensive Proxmox VE datacenter management through Model Context Protocol with full migration from standalone scripts.

**Features**:
- 12 comprehensive MCP tools for complete Proxmox management
- VM/Container lifecycle management (create, start, stop, delete)
- Snapshot and backup operations with automated cleanup
- Health assessments and resource monitoring
- Storage optimization and maintenance automation
- Multi-server support with security validation
- **Migration**: Fully replaces 8+ standalone scripts with enhanced functionality

**Key Tools**: System info, health assessment, VM/container management, snapshot operations, backup management, storage optimization, maintenance automation, audit reporting.

## Development Environment

- **Primary Development**: `C:\git\mcp-servers\` (GitHub synchronized)
- **Temporary Work**: `C:\working\` (volatile, short-term only)

## Quick Start

### Network MCP Server
```bash
cd network-mcp-server
pip install -e .
network-mcp-server create-config --output config.json
```

### Code Linter MCP Server
```bash
cd code-linter-mcp-server  
pip install -e .
pip install flake8 black mypy yamllint  # Install Python linters
code-linter-mcp-server create-config --output config.json
```

### Proxmox MCP Server
```bash
cd proxmox-mcp-server
./install.sh  # Creates virtual environment and installs dependencies
./venv/bin/proxmox-mcp-server create-config --output config.json
# Edit config.json with your Proxmox server details
export PROXMOX_PASSWORD='your_password'
./venv/bin/proxmox-mcp-server validate-config config.json --test-connection
```

## Claude Desktop Integration

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "network-fs": {
      "command": "network-mcp-server",
      "args": ["run", "--config", "path/to/network-config.json"]
    },
    "code-linter": {
      "command": "code-linter-mcp-server", 
      "args": ["run", "--config", "path/to/linter-config.json"]
    },
    "proxmox": {
      "command": "path/to/proxmox-mcp-server/venv/bin/proxmox-mcp-server",
      "args": ["run", "path/to/proxmox-config.json"],
      "env": {
        "PROXMOX_PASSWORD": "your_password"
      }
    }
  }
}
```

## Project Standards

All servers follow consistent patterns:
- **Architecture**: Pydantic configuration, async operations, security validation
- **CLI**: Standard commands (run, create-config, validate-config)
- **Testing**: Comprehensive test coverage with pytest
- **Documentation**: README, examples, and installation guides
- **Security**: File type restrictions, path validation, audit logging

## Development Workflow

1. Create new server directory: `[purpose]-mcp-server/`
2. Follow established directory structure and patterns
3. Implement security validation and error handling
4. Add comprehensive tests and documentation
5. Update this main README

## Future MCP Server Ideas

- **Database MCP Server**: SQL database access and management
- **Home Assistant MCP Server**: Smart home control and monitoring  
- **Git MCP Server**: Repository operations and GitHub/GitLab integration
- **Docker MCP Server**: Container management and monitoring
- **AWS/Cloud MCP Server**: Cloud resource management

## Contributing

See individual server directories for specific setup and contribution guidelines. All development follows the established patterns and quality standards.

## License

MIT License - see individual server LICENSE files for details.
