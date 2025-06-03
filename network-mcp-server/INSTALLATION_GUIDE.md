    }
  }
}
```

### 4. Alternative: Use Python Module Directly

If the executable path doesn't work, you can use the Python module directly:

```json
{
  "mcpServers": {
    "network-fs": {
      "command": "python",
      "args": [
        "C:\\working\\network-mcp-server\\run_server.py",
        "run",
        "--config", 
        "C:\\working\\network-mcp-server\\test_config.json"
      ]
    }
  }
}
```

## Security Configuration

The server includes comprehensive security controls in the config:

```json
{
  "security": {
    "allowed_extensions": [".txt", ".py", ".json", ".md", ".yaml", ".yml", ".xml", ".csv"],
    "blocked_extensions": [".exe", ".bat", ".cmd", ".ps1", ".sh"],
    "max_file_size": "100MB",
    "allowed_paths": [],
    "blocked_paths": ["/etc", "/root", "/sys", "/proc", "/windows", "/system32"],
    "enable_write": true,
    "enable_delete": false
  }
}
```

## Testing the Server

### Manual Test
```bash
# Test with dry run first
C:\Users\Jeremy\AppData\Roaming\Python\Python313\Scripts\network-mcp-server.exe run --config C:\working\network-mcp-server\test_config.json
```

### Example Usage in Claude Desktop

Once configured, you can ask Claude:

- "List the contents of my network share"
- "Read the file 'documents/readme.txt' from my_share"
- "Create a new file called 'test.txt' with some content on my_share"
- "Show me information about the 'projects' directory"

## Troubleshooting

### Common Issues

1. **"network-mcp-server command not found"**
   - Use the full path or Python module approach above

2. **SMB Authentication Fails**
   - Verify username, password, and domain
   - Check if the SMB server allows the connection
   - Try with `use_ntlm_v2: false` if having auth issues

3. **Connection Timeout**
   - Verify the host IP and port (445 for SMB)
   - Check firewall settings
   - Increase timeout value in config

4. **Permission Denied**
   - Check SMB share permissions
   - Verify the user has access to the share
   - Review security settings in the config

### Debug Mode

Enable debug logging by changing in config:
```json
{
  "logging_level": "DEBUG"
}
```

## File Structure

```
C:\working\network-mcp-server\
├── src/network_mcp/
│   ├── __init__.py
│   ├── server.py          # Main MCP server
│   ├── smb_fs.py         # SMB filesystem implementation
│   ├── config.py         # Configuration models
│   ├── security.py       # Security validation
│   ├── exceptions.py     # Custom exceptions
│   └── cli.py            # Command-line interface
├── tests/
│   └── test_basic.py     # Basic tests
├── pyproject.toml        # Package configuration
├── README.md            # Documentation
├── example_config.json  # Example configuration
├── test_config.json     # Generated test config
└── run_server.py        # Direct runner script
```

## Adding More Share Types

The architecture supports adding other network protocols:

1. **NFS Support** - Create `nfs_fs.py` similar to `smb_fs.py`
2. **FTP/SFTP** - Add FTP connection classes
3. **WebDAV** - Add WebDAV protocol support

## Success! 🎉

Your Network MCP Server is ready to use! You now have:

✅ **SMB/Samba share access** from Claude Desktop
✅ **Full file operations** (read, write, list, create, delete)
✅ **Security controls** (file type restrictions, size limits, path controls)
✅ **Extensible architecture** for adding more protocols
✅ **Comprehensive error handling** and logging

The server will allow Claude to directly access your network shares, read configuration files, analyze data, and help manage your network storage - all while maintaining security boundaries you configure.
