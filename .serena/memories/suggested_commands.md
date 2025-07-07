# Suggested Commands for Workspace Development

## MCP Server Management
```bash
# List all MCP servers
claude mcp list

# Add new MCP server
claude mcp add <name> "<command>"

# Remove MCP server
claude mcp remove <name>

# Test MCP functionality
/mcp
```

## Service Management
```bash
# Project management services
/home/dev/workspace/project-management-wrapper.sh start|stop|restart|status

# Home Assistant wrapper
/home/dev/workspace/hass-mcp-wrapper.sh

# Proxmox wrapper
/home/dev/workspace/proxmox-mcp-wrapper.sh
```

## Development Tools
```bash
# Test MCP integration
/home/dev/workspace/test-mcp-integration.sh

# MCP diagnostics
/home/dev/workspace/mcp-diagnostic.sh

# Setup MCP servers
/home/dev/workspace/setup-mcp-servers.sh
```

## Package Management
```bash
# Install Node.js dependencies
npm install

# Run package tests
npm test
```

## System Commands (Linux)
```bash
# File operations
ls -la
find . -name "*.yaml" -type f
grep -r "pattern" .
cd /path/to/directory

# Process management
ps aux | grep node
kill -9 <pid>

# Docker operations
docker ps
docker-compose up -d
docker logs <container>
```