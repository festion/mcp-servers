# Network MCP Server - Installation Guide

This guide covers the installation of the Network MCP Server from source to deployment.

## Quick Start

### Windows
```batch
# Navigate to source directory
cd C:\git\mcp-servers\network-mcp-server

# Run installer with default settings
install.bat

# Or with custom install directory
install.bat --install-dir "D:\my-tools\network-mcp"
```

### Unix/Linux/macOS
```bash
# Navigate to source directory
cd /path/to/mcp-servers/network-mcp-server

# Make installer executable
chmod +x install.sh

# Run installer with default settings
./install.sh

# Or with custom install directory
./install.sh --install-dir "$HOME/my-tools/network-mcp"
```

## Installation Options

### Windows (install.bat)
- `--source DIR` - Source directory (default: C:\git\mcp-servers\network-mcp-server)
- `--install-dir DIR` - Installation directory (default: C:\working\network-mcp-server)
- `--help` - Show help message

### Unix/Linux/macOS (install.sh)
- `--source DIR` - Source directory (default: current directory)
- `--install-dir DIR` - Installation directory (default: ~/mcp-servers/network-mcp-server)
- `--help` - Show help message

### Python Installer Script
```bash
# Advanced installation with Python script
python installer.py

# Or with command line options
python installer.py --source /path/to/source --install-dir /path/to/install
```

## What Gets Installed

### Core Package
- Network MCP Server package
- Core dependencies (mcp, pysmb, pydantic)
- Development dependencies (pytest, black, ruff, mypy)

### Configuration
- Sample configuration file (`config.json`)
- Pre-configured for SMB/CIFS access

## Prerequisites

### Required
- Python 3.10 or later
- pip (Python package manager)

### Network Access
- Access to SMB/CIFS shares you want to connect to
- Network connectivity to target servers
- Appropriate credentials for SMB shares

## Installation Process

1. **Validation** - Checks Python version and source directory
2. **Directory Setup** - Creates installation directory
3. **File Copying** - Copies source files to installation directory
4. **Package Installation** - Installs the MCP server package
5. **Dependencies** - Installs required dependencies (pysmb, etc.)
6. **Configuration** - Creates sample configuration file
7. **Testing** - Runs basic tests if available
8. **Integration Setup** - Provides Claude Desktop configuration

## Post-Installation Configuration

### SMB Share Setup
Edit the generated `config.json` file with your SMB details:

```json
{
  "shares": {
    "my_share": {
      "host": "192.168.1.100",
      "share_name": "shared_folder",
      "username": "your_username",
      "password": "your_password",
      "domain": "your_domain",
      "port": 445,
      "timeout": 30
    }
  },
  "security": {
    "allowed_file_extensions": [".txt", ".md", ".json", ".py"],
    "max_file_size": "10MB",
    "allow_write": true,
    "allow_delete": false
  }
}
```

### Configuration Fields
- **host** - SMB server hostname or IP address
- **share_name** - Name of the SMB share
- **username** - SMB username
- **password** - SMB password (consider using environment variables)
- **domain** - SMB domain (optional, use "" if not needed)
- **port** - SMB port (default: 445)
- **timeout** - Connection timeout in seconds

### Security Settings
- **allowed_file_extensions** - List of allowed file extensions
- **max_file_size** - Maximum file size (e.g., "10MB", "1GB")
- **allow_write** - Allow writing files to shares
- **allow_delete** - Allow deleting files from shares

## Testing Installation

### Validate Configuration
```bash
network-mcp-server validate-config /path/to/config.json
```

### Test Connection
```bash
# Test the server (will attempt to connect to configured shares)
network-mcp-server run --config /path/to/config.json
```

### Test Specific Operations
```bash
# List shares
network-mcp-server list-shares --config /path/to/config.json

# Test connectivity
network-mcp-server test-connection --config /path/to/config.json
```

## Claude Desktop Integration

Add the provided configuration to your Claude Desktop config file:

**Windows**: `%USERPROFILE%\AppData\Roaming\Claude\claude_desktop_config.json`
**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "network-fs": {
      "command": "/path/to/network-mcp-server",
      "args": ["run", "--config", "/path/to/config.json"]
    }
  }
}
```

## Usage Examples

Once installed and configured, you can use these commands through Claude Desktop:

- "List the contents of my network share"
- "Read the file 'documents/readme.txt' from my_share"
- "Create a new file called 'notes.txt' with content on my_share"
- "Show information about the 'projects' directory"
- "Upload this file to my network share"

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Check host/IP address and port
   - Verify firewall settings
   - Ensure SMB service is running

2. **Authentication Failed**
   - Verify username/password
   - Check domain settings
   - Try without domain if not needed

3. **Permission Denied**
   - Check SMB share permissions
   - Verify user has appropriate access
   - Check security settings in config

4. **Command Not Found**
   - Ensure pip scripts directory is in PATH
   - Try using `python -m network_mcp.cli` instead

### Network Diagnostics

```bash
# Test SMB connectivity manually
smbclient -L //hostname -U username

# Check port accessibility
telnet hostname 445

# Test with different credentials
net use \\hostname\sharename /user:domain\username
```

### Log Analysis
Enable verbose logging in configuration:
```json
{
  "logging": {
    "level": "DEBUG",
    "file": "/path/to/network-mcp.log"
  }
}
```

## Security Considerations

### Credential Security
- Use environment variables for passwords when possible
- Restrict file permissions on configuration files
- Consider using keyring/credential managers

### Network Security
- Use VPN when accessing remote shares
- Configure appropriate firewall rules
- Monitor access logs

### File Access Control
- Limit allowed file extensions
- Set appropriate file size limits
- Disable write/delete if not needed
- Use read-only shares when possible

## Advanced Configuration

### Multiple Shares
```json
{
  "shares": {
    "documents": {
      "host": "server1.company.com",
      "share_name": "documents",
      "username": "user1"
    },
    "backups": {
      "host": "server2.company.com",
      "share_name": "backups",
      "username": "user2"
    }
  }
}
```

### Environment Variables
```json
{
  "shares": {
    "my_share": {
      "host": "${SMB_HOST}",
      "username": "${SMB_USER}",
      "password": "${SMB_PASS}"
    }
  }
}
```

### Custom Timeouts and Retries
```json
{
  "connection": {
    "timeout": 60,
    "retry_attempts": 3,
    "retry_delay": 5
  }
}
```

## Getting Help

- Run installer with `--help` for installation options
- Check the main README.md for detailed server documentation
- Review configuration examples in the examples directory
- Enable debug logging for troubleshooting connection issues
