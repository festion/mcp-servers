# MCP (Model Context Protocol) Overview

## What is MCP?

The Model Context Protocol (MCP) is an open standard for connecting AI assistants to various data sources and tools. It enables seamless integration between AI systems and external services, databases, APIs, and applications.

## Architecture

MCP follows a client-server architecture where:
- **MCP Clients** (like Claude) connect to and interact with MCP servers
- **MCP Servers** provide access to specific resources, tools, or data sources
- **Protocol** defines standardized communication patterns

## Available MCP Servers

### Core Infrastructure
- **[Filesystem Server](/mcp/servers/filesystem)** - Local file system access
- **[Network-FS Server](/mcp/servers/network-fs)** - Network file system access

### Platform Integrations  
- **[Home Assistant Server](/mcp/servers/home-assistant)** - Smart home automation
- **[Proxmox Server](/mcp/servers/proxmox)** - Virtualization management
- **[GitHub Server](/mcp/servers/github)** - Repository and project management

### Documentation & AI
- **[WikiJS Server](/mcp/servers/wikijs)** - Documentation management
- **[Serena Server](/mcp/servers/serena)** - AI assistant integration

### Development Tools
- **[Code Linter Server](/mcp/servers/code-linter)** - Code quality tools

## Configuration

MCP servers are configured in Claude Code settings with individual wrapper scripts:
- `hass-mcp-wrapper.sh` - Home Assistant integration
- `proxmox-mcp-wrapper.sh` - Proxmox management
- `wikijs-mcp-wrapper.sh` - WikiJS documentation
- `github-wrapper.sh` - GitHub repository access
- `serena-mcp-wrapper.sh` - Serena AI assistant
- `network-mcp-wrapper.sh` - Network file systems
- `code-linter-wrapper.sh` - Code quality tools

## Development Resources

- **[Server Development Guide](/mcp/server-development)** - Creating custom MCP servers
- **[Client Integration Guide](/mcp/client-integration)** - Integrating with MCP clients
- **[Protocol Specification](/mcp/protocol)** - Technical protocol details

## Getting Started

1. **Installation** - Set up MCP servers via wrapper scripts
2. **Configuration** - Configure authentication tokens and endpoints
3. **Testing** - Verify connectivity with `/mcp` command
4. **Usage** - Access tools and resources through Claude Code

## Best Practices

- Use test tokens during development and diagnostics
- Implement proper error handling in wrapper scripts
- Follow security guidelines for production deployments
- Regular health checks and monitoring
- Maintain documentation for custom implementations