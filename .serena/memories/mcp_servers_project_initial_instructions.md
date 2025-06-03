# MCP Servers Project - Initial Instructions

## Project Overview
This is a collection of Model Context Protocol (MCP) servers that extend Claude Desktop's capabilities by providing access to various external systems and services. The project follows a modular architecture where each MCP server is a self-contained package with its own functionality.

**Development Location**: `C:\git\mcp-servers\` (GitHub synchronized)
**Temporary Work**: `C:\working\` (volatile, short-term only)

## Current MCP Servers

### 1. Network MCP Server (`network-mcp-server/`)
**Status**: ✅ Complete and functional (reference implementation from `C:\working\`)
**Purpose**: Provides access to network filesystems (SMB/CIFS shares, with extensibility for NFS, FTP, etc.)
**Key Features**:
- SMB/CIFS support for Windows shares and Samba servers
- 7 MCP tools for file operations (read, write, list, delete, create directories, get info)
- Comprehensive security controls and validation
- Async architecture with proper error handling
- Claude Desktop integration ready

**Architecture**:
- `src/network_mcp/server.py` - Main MCP server implementation
- `src/network_mcp/smb_fs.py` - SMB filesystem implementation using pysmb
- `src/network_mcp/config.py` - Pydantic configuration models
- `src/network_mcp/security.py` - Security validation and controls
- `src/network_mcp/cli.py` - Command-line interface
- `tests/` - Comprehensive test suite

## Development Environment

### File Organization
- **Primary Development**: `C:\git\mcp-servers\` - All production code, GitHub synchronized
- **Temporary/Experimental**: `C:\working\` - Volatile workspace for prototyping and testing
- **Production Installations**: Install from `C:\git\mcp-servers\[server-name]\` for actual use

### Version Control
- All development happens in `C:\git\mcp-servers\`
- Regular commits and pushes to GitHub for backup and collaboration
- Use feature branches for new server development
- `C:\working\` content should never be considered permanent

## Project Standards and Patterns

### Directory Structure
Each MCP server should follow this standard structure in `C:\git\mcp-servers\`:
```
server-name-mcp-server/
├── src/
│   └── server_name_mcp/
│       ├── __init__.py
│       ├── server.py          # Main MCP server class
│       ├── config.py          # Pydantic configuration models
│       ├── cli.py             # Command-line interface
│       ├── exceptions.py      # Custom exceptions
│       └── [implementation].py # Core functionality
├── tests/
│   └── test_*.py
├── pyproject.toml             # Modern Python packaging
├── setup.py                   # Alternative setup script
├── README.md                  # Documentation
├── example_config.json        # Sample configuration
├── INSTALL.md                 # Installation guide
└── install.bat               # Windows installation script
```

### Technical Standards

#### Dependencies
- **MCP Framework**: Use the official `mcp` Python package
- **Configuration**: Use Pydantic for type-safe configuration models
- **Async**: Use asyncio for non-blocking operations with thread pools for sync APIs
- **Logging**: Use Python's logging module with proper log levels
- **Testing**: Use pytest for comprehensive test coverage

#### Security
- Implement SecurityValidator class for operation controls
- Support configurable file type restrictions
- Implement path validation and sandboxing
- Add audit logging for all operations
- Handle authentication securely

#### Configuration
- Use JSON configuration files with Pydantic validation
- Provide example configurations
- Support environment variable overrides where appropriate
- Include security settings as first-class configuration

#### CLI Interface
Standard commands:
- `run` - Start the MCP server
- `create-config` - Generate sample configuration
- `validate-config` - Validate configuration file
- `--help` - Show usage information

#### MCP Tools Pattern
Each server should provide intuitive tools following this naming convention:
- `list_[resource]` - List resources
- `read_[resource]` - Read resource content
- `write_[resource]` - Write/update resources
- `delete_[resource]` - Delete resources
- `create_[resource]` - Create new resources
- `get_[resource]_info` - Get metadata about resources

### Integration with Claude Desktop
Each server must:
1. Provide clear Claude Desktop configuration examples
2. Include proper executable paths for different platforms
3. Document required arguments and configuration files
4. Provide troubleshooting guidance

## Development Workflow

### Adding New MCP Servers
1. Create new directory in `C:\git\mcp-servers\` following naming convention: `[purpose]-mcp-server/`
2. Implement following the established patterns and architecture
3. Use the Network MCP Server as a reference implementation
4. Ensure comprehensive testing and documentation
5. Update this project's main README.md
6. Commit and push to GitHub regularly

### Code Quality Standards
- Follow Python PEP 8 style guidelines
- Use type hints throughout
- Write comprehensive docstrings
- Implement proper error handling with custom exceptions
- Add logging at appropriate levels
- Write tests for all major functionality

### Documentation Requirements
- README.md with clear usage examples
- Installation instructions for multiple platforms
- Configuration documentation with examples
- Security considerations section
- Troubleshooting guide

## Future MCP Server Ideas
- **Database MCP Server**: Access to SQL databases (PostgreSQL, MySQL, SQLite)
- **Home Assistant MCP Server**: Control and monitor Home Assistant instances
- **Git MCP Server**: Git repository operations and GitHub/GitLab integration
- **Docker MCP Server**: Container management and monitoring
- **AWS/Cloud MCP Server**: Cloud resource management and monitoring
- **REST API MCP Server**: Generic REST API client with authentication
- **Email MCP Server**: Email reading, sending, and management

## Memory Files Available
- `network_mcp_server_implementation_complete.md` - Complete documentation of the Network MCP Server (from C:\working\ prototype)
- Other project-specific memories for different contexts

This project serves as a foundation for extending Claude Desktop's capabilities through the Model Context Protocol ecosystem.