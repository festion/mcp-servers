# Installation Guide - Proxmox MCP Server

This guide provides step-by-step instructions for installing and configuring the Proxmox MCP Server.

## Prerequisites

### System Requirements

- **Python**: 3.8 or higher
- **Operating System**: Windows, macOS, or Linux
- **Claude Desktop**: Latest version with MCP support
- **Network Access**: Connectivity to Proxmox VE server(s)

### Proxmox Requirements

- **Proxmox VE**: Version 7.0 or higher recommended
- **API Access**: User account with API access permissions
- **Network**: HTTPS access to Proxmox API (default port 8006)

## Installation Methods

### Method 1: Install from Source (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-org/mcp-servers.git
   cd mcp-servers/proxmox-mcp-server
   ```

2. **Install the package:**
   ```bash
   pip install -e .
   ```

3. **Verify installation:**
   ```bash
   proxmox-mcp-server --version
   ```

### Method 2: Direct Installation

If you have the source code locally:

```bash
cd path/to/proxmox-mcp-server
pip install -r requirements.txt
pip install -e .
```

## Configuration Setup

### Step 1: Create Configuration File

Generate a sample configuration file:

```bash
proxmox-mcp-server create-config --output /path/to/proxmox_config.json
```

This creates a template configuration file that you'll customize for your environment.

### Step 2: Configure Environment Variables

Create a `.env` file in your working directory or set system environment variables:

```bash
# .env file
PROXMOX_PASSWORD=your_proxmox_password
PROXMOX_BACKUP_PASSWORD=your_backup_server_password
```

**Security Note**: Never store passwords directly in configuration files. Always use environment variables.

### Step 3: Edit Configuration

Open the generated configuration file and update it with your Proxmox server details:

```json
{
  "servers": {
    "main": {
      "host": "your.proxmox.server",
      "port": 8006,
      "username": "your_username",
      "password_env_var": "PROXMOX_PASSWORD",
      "realm": "pam",
      "verify_ssl": false,
      "timeout": 30
    }
  },
  "default_server": "main",
  "security": {
    "allow_vm_operations": true,
    "allow_storage_operations": true,
    "allow_snapshot_operations": true,
    "allow_backup_operations": true,
    "require_confirmation_for_destructive_ops": true
  }
}
```

### Step 4: Validate Configuration

Test your configuration:

```bash
proxmox-mcp-server validate-config /path/to/proxmox_config.json --test-connection
```

If the validation fails, check:
- Network connectivity to Proxmox server
- Username and password
- SSL certificate settings
- Firewall rules

## Claude Desktop Integration

### Locate Claude Desktop Configuration

Find your Claude Desktop configuration file:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

### Add MCP Server Configuration

Edit the Claude Desktop configuration file:

```json
{
  "mcpServers": {
    "proxmox": {
      "command": "proxmox-mcp-server",
      "args": ["run", "/absolute/path/to/proxmox_config.json"],
      "env": {
        "PROXMOX_PASSWORD": "your_password"
      }
    }
  }
}
```

### Alternative Configuration with Script

For Windows users, you can create a batch file:

```batch
@echo off
set PROXMOX_PASSWORD=your_password
proxmox-mcp-server run "C:\path\to\proxmox_config.json"
```

Then reference the batch file in Claude Desktop:

```json
{
  "mcpServers": {
    "proxmox": {
      "command": "C:\\path\\to\\proxmox_mcp_runner.bat",
      "args": []
    }
  }
}
```

## Proxmox User Setup

### Create Dedicated API User (Recommended)

For security best practices, create a dedicated user for API access:

1. **Log into Proxmox web interface**

2. **Navigate to Datacenter → Permissions → Users**

3. **Add new user:**
   - User name: `mcp-api`
   - Realm: `pve` (Proxmox VE authentication server)
   - Password: Generate strong password

4. **Assign permissions:**
   ```bash
   # Via CLI (as root on Proxmox server)
   pveum user add mcp-api@pve --password your_secure_password
   pveum aclmod / -user mcp-api@pve -role PVEAdmin
   ```

### Required Permissions

The MCP server requires the following permissions:

- **VM operations**: VM.Audit, VM.Monitor, VM.PowerMgmt
- **Storage operations**: Datastore.Audit, Datastore.AllocateSpace
- **Snapshot operations**: VM.Snapshot, VM.Snapshot.Rollback
- **Backup operations**: VM.Backup, Datastore.AllocateSpace
- **System operations**: Sys.Audit, Sys.Console

### Minimal Permissions Setup

For read-only operations:

```bash
pveum role add MCPReadOnly -privs VM.Audit,Datastore.Audit,Sys.Audit
pveum aclmod / -user mcp-api@pve -role MCPReadOnly
```

For full management capabilities:

```bash
pveum aclmod / -user mcp-api@pve -role PVEAdmin
```

## Testing Installation

### Basic Functionality Test

1. **Start Claude Desktop** and ensure the MCP server is loaded

2. **Test system information:**
   ```
   Ask Claude: "Get basic information about my Proxmox system"
   ```

3. **Test health assessment:**
   ```
   Ask Claude: "Run a health assessment of my Proxmox environment"
   ```

### Manual Testing

You can also test the server directly:

```bash
# Test configuration
proxmox-mcp-server validate-config /path/to/config.json --test-connection

# View server information
proxmox-mcp-server info --config /path/to/config.json

# Test MCP server (this will start the server for direct testing)
proxmox-mcp-server run /path/to/config.json
```

## Troubleshooting Common Issues

### Installation Issues

**"Command not found: proxmox-mcp-server"**
- Ensure pip installation completed successfully
- Check that your Python scripts directory is in PATH
- Try reinstalling: `pip uninstall proxmox-mcp-server && pip install -e .`

**"Module not found" errors**
- Install missing dependencies: `pip install -r requirements.txt`
- Ensure you're using the correct Python environment

### Configuration Issues

**"Authentication failed"**
- Verify username and password
- Check realm setting (usually 'pam' for local users, 'pve' for PVE users)
- Ensure user has API access permissions

**"SSL errors"**
- Set `verify_ssl: false` for self-signed certificates
- Or install the Proxmox certificate in your system trust store

**"Connection timeout"**
- Check network connectivity: `ping your.proxmox.server`
- Verify port accessibility: `telnet your.proxmox.server 8006`
- Increase timeout value in configuration

### Claude Desktop Integration Issues

**"MCP server not starting"**
- Check Claude Desktop logs
- Verify absolute paths in configuration
- Ensure environment variables are accessible

**"Tools not available"**
- Restart Claude Desktop after configuration changes
- Check MCP server logs for errors
- Verify JSON syntax in claude_desktop_config.json

## Security Considerations

### Network Security
- Use VPN or secure network for Proxmox API access
- Consider changing default API port (8006)
- Enable SSL certificate verification in production

### Credential Security
- Never store passwords in configuration files
- Use environment variables or secure credential stores
- Regularly rotate API user passwords
- Use dedicated API users with minimal required permissions

### Access Control
- Enable security features in MCP server configuration
- Set appropriate resource thresholds
- Enable operation confirmation for destructive actions
- Monitor operation logs for unauthorized access

## Performance Optimization

### Configuration Tuning
- Adjust timeout values based on network latency
- Configure appropriate monitoring thresholds
- Enable only required operation categories

### Resource Management
- Monitor MCP server resource usage
- Configure connection pooling for multiple servers
- Set reasonable limits for bulk operations

## Maintenance

### Updates
```bash
# Update to latest version
cd mcp-servers/proxmox-mcp-server
git pull
pip install -e . --upgrade
```

### Log Management
- Monitor MCP server logs regularly
- Configure log rotation if needed
- Archive operation audit logs

### Configuration Backup
- Backup configuration files
- Document environment variable values securely
- Version control configuration changes

## Getting Help

If you encounter issues during installation:

1. **Check this guide** for common solutions
2. **Review error messages** carefully - they often contain specific guidance
3. **Test connectivity** manually using tools like ping, telnet, or curl
4. **Verify permissions** by testing API access directly
5. **Check logs** in Claude Desktop and MCP server output

For additional support:
- 📖 [Main Documentation](README.md)
- 🐛 [Issue Tracker](https://github.com/your-org/mcp-servers/issues)
- 💬 [Community Discussions](https://github.com/your-org/mcp-servers/discussions)