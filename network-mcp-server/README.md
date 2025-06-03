# Network MCP Server

A Model Context Protocol (MCP) server that provides access to network filesystems including SMB/CIFS shares, NFS mounts, and other network storage protocols.

## Features

- **SMB/CIFS Support**: Access Windows shares and Samba servers
- **File Operations**: Read, write, list, delete files and directories
- **Authentication**: Support for username/password and domain authentication
- **Security**: Configurable access controls and path restrictions
- **Extensible**: Designed to support additional protocols (NFS, FTP, etc.)

## Installation

```bash
pip install -e .
```

## Configuration

Create a configuration file `network_config.json`:

```json
{
  "shares": {
    "my_share": {
      "type": "smb",
      "host": "192.168.1.100",
      "share_name": "shared_folder",
      "username": "user",
      "password": "pass",
      "domain": "WORKGROUP"
    }
  },
  "security": {
    "allowed_extensions": [".txt", ".py", ".json", ".md"],
    "max_file_size": "100MB"
  }
}
```

## Usage

Start the MCP server:

```bash
network-mcp-server --config network_config.json
```

Use with Claude Desktop by adding to your configuration:

```json
{
  "mcpServers": {
    "network-fs": {
      "command": "network-mcp-server",
      "args": ["--config", "path/to/network_config.json"]
    }
  }
}
```

## Available Tools

- `list_network_directory`: List contents of a network directory
- `read_network_file`: Read contents of a network file
- `write_network_file`: Write contents to a network file
- `delete_network_file`: Delete a network file
- `create_network_directory`: Create a network directory
- `get_network_file_info`: Get metadata about a network file

## Security Considerations

- Network credentials are stored in configuration
- File access is restricted by configured paths and extensions
- All operations are logged for audit purposes
