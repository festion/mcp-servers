# Network MCP Server Installation & Usage Guide

## Quick Start

### 1. Installation

```bash
cd C:\working\network-mcp-server
pip install -e .
```

### 2. Create Configuration

```bash
network-mcp-server create-config my_config.json
```

Edit `my_config.json` with your SMB share details:

```json
{
  "shares": {
    "my_nas": {
      "type": "smb",
      "host": "192.168.1.100",
      "share_name": "documents",
      "username": "your_username",
      "password": "your_password",
      "domain": "WORKGROUP"
    }
  },
  "security": {
    "allowed_extensions": [".txt", ".py", ".json", ".md"],
    "enable_write": true,
    "enable_delete": false
  }
}
```

### 3. Validate Configuration

```bash
network-mcp-server validate-config my_config.json
```

### 4. Test the Server

```bash
python test_setup.py
```

### 5. Run the Server

```bash
network-mcp-server run --config my_config.json
```

## Claude Desktop Integration

Add this to your Claude Desktop configuration file:

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "network-fs": {
      "command": "network-mcp-server",
      "args": ["run", "--config", "C:\\path\\to\\your\\config.json"]
    }
  }
}
```

## Available Tools in Claude

Once connected, you can use these tools in Claude:

### 1. List Directory Contents
```
List the contents of my NAS documents folder
```

### 2. Read Files
```
Read the file "projects/readme.txt" from my_nas share
```

### 3. Write Files
```
Write a new file called "notes.md" to my_nas share with this content: [your content]
```

### 4. Get File Information
```
Get information about the file "data.csv" on my_nas
```

### 5. Create Directories
```
Create a new directory called "backup" on my_nas share
```

### 6. View Share Information
```
Show me information about my configured network shares
```

## Security Features

- **File Extension Filtering**: Only allow specific file types
- **Path Restrictions**: Block access to sensitive directories
- **Size Limits**: Prevent reading/writing large files
- **Operation Controls**: Enable/disable write and delete operations
- **Audit Logging**: All operations are logged

## Troubleshooting

### Connection Issues

1. **Check network connectivity:**
   ```bash
   ping 192.168.1.100
   telnet 192.168.1.100 445
   ```

2. **Verify SMB share access:**
   - Test with Windows Explorer or `net use` command
   - Ensure the share is accessible with your credentials

3. **Check firewall settings:**
   - Ensure port 445 is open
   - Disable Windows Firewall temporarily to test

### Authentication Issues

1. **Domain vs Workgroup:**
   - For domain: use `DOMAIN\username` or set domain in config
   - For workgroup: use just `username`

2. **Password special characters:**
   - Escape special characters in JSON config
   - Consider using environment variables for sensitive data

### Permission Issues

1. **SMB share permissions:**
   - Ensure the user has read/write access to the share
   - Check NTFS permissions on the target directories

2. **MCP server permissions:**
   - Check the `security` section in your config
   - Verify file extensions are allowed

## Advanced Configuration

### Environment Variables

For security, use environment variables for credentials:

```json
{
  "shares": {
    "secure_share": {
      "type": "smb",
      "host": "192.168.1.100",
      "share_name": "documents",
      "username": "${SMB_USERNAME}",
      "password": "${SMB_PASSWORD}",
      "domain": "${SMB_DOMAIN}"
    }
  }
}
```

Set environment variables:
```bash
set SMB_USERNAME=your_username
set SMB_PASSWORD=your_password
set SMB_DOMAIN=WORKGROUP
```

### Multiple Shares

Configure multiple network shares:

```json
{
  "shares": {
    "home_nas": {
      "type": "smb",
      "host": "192.168.1.100",
      "share_name": "home",
      "username": "homeuser",
      "password": "homepass"
    },
    "office_server": {
      "type": "smb",
      "host": "office.company.com",
      "share_name": "projects", 
      "username": "officeuser",
      "password": "officepass",
      "domain": "COMPANY"
    }
  }
}
```

### Enhanced Security

```json
{
  "security": {
    "allowed_extensions": [".txt", ".py", ".js", ".json", ".md", ".csv"],
    "blocked_extensions": [".exe", ".bat", ".cmd", ".ps1", ".dll"],
    "max_file_size": "50MB",
    "allowed_paths": ["/documents", "/projects", "/shared"],
    "blocked_paths": ["/admin", "/system", "/config"],
    "enable_write": true,
    "enable_delete": false
  }
}
```

## Development

### Running Tests

```bash
# Install development dependencies
pip install pytest pytest-asyncio

# Run tests
python -m pytest tests/ -v

# Run setup tests
python test_setup.py
```

### Adding New Protocols

The server is designed to be extensible. To add support for new protocols (NFS, FTP, etc.):

1. Create a new protocol implementation in `src/network_mcp/`
2. Add configuration model to `config.py`
3. Update the server to handle the new protocol type
4. Add tests for the new functionality

## Support

For issues and questions:

1. Check the logs for error messages
2. Verify your network connectivity and SMB access
3. Test with the provided test scripts
4. Review the security configuration

Common error patterns:
- `Authentication failed`: Check username/password/domain
- `Connection timeout`: Check network connectivity and firewall
- `Permission denied`: Check file/directory permissions
- `File not found`: Verify path and case sensitivity
