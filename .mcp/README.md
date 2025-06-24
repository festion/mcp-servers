# MCP Server Configuration and Template Infrastructure

This directory contains the standardized MCP (Model Context Protocol) server configuration and template infrastructure for the homelab-gitops-auditor project ecosystem.

## Directory Structure

```
.mcp/
├── README.md                    # This documentation
├── setup-mcp-servers.sh        # MCP server setup and validation script
├── template-schema.json        # Template definition schema
└── templates/                  # Template definitions directory
    └── standard-devops/        # Standard DevOps project template
        └── template.json       # DevOps template definition
```

## MCP Server Configuration

The project uses 7 standardized MCP servers configured in the root `.mcp.json` file:

1. **filesystem** - File system access via npx
2. **serena** - Primary orchestrator and coordination via uv  
3. **wikijs-mcp** - Wiki.js documentation integration
4. **github** - GitHub API integration via Docker
5. **network-fs** - Network file system access
6. **proxmox-mcp** - Proxmox virtualization management
7. **hass-mcp** - Home Assistant integration via Docker

## Quick Start

### Setup MCP Servers
```bash
# Run the setup script to install and configure all MCP servers
./.mcp/setup-mcp-servers.sh

# Update configuration only
./.mcp/setup-mcp-servers.sh --update-config
```

### Deploy to Other Repositories
```bash
# Deploy standardized MCP configuration to all Git repositories
./scripts/deploy-mcp-config.sh
```

## MCP Server Details

### Filesystem MCP
- **Purpose**: Provides file system access to Claude
- **Access Paths**: 
  - `/mnt/c/Users/{USERNAME}/OneDrive/Desktop`
  - `/mnt/c/GIT` 
  - `/mnt/c/my-tools`
  - `/mnt/c/working`
  - `/mnt/c/Users/{USERNAME}/AppData/Roaming/Claude/logs`

### Serena MCP
- **Purpose**: Primary orchestrator for multi-server coordination
- **Location**: `/mnt/c/GIT/serena`
- **Best Practice**: Use Serena to marshall all other MCP servers

### WikiJS MCP
- **Purpose**: Wiki.js documentation integration
- **Location**: `/mnt/c/GIT/mcp-servers/wikijs-mcp-server/`
- **Configuration**: `config/wikijs_mcp_config.json`

### GitHub MCP
- **Purpose**: GitHub API integration for repository operations
- **Authentication**: Requires `GITHUB_PERSONAL_ACCESS_TOKEN`
- **Features**: Issues, PRs, branches, repository management

### Network-FS MCP
- **Purpose**: Network file system access
- **Location**: `/mnt/c/my-tools/network-fs/`

### Proxmox MCP
- **Purpose**: Proxmox virtualization management
- **Location**: `/mnt/c/GIT/mcp-servers/proxmox-mcp-server/`
- **Configuration**: `config.json`

### Home Assistant MCP
- **Purpose**: Home Assistant integration
- **Authentication**: Requires `HA_URL` and `HA_TOKEN`
- **Default URL**: `http://192.168.1.155:8123`

## Template Infrastructure

### Template Schema
The `template-schema.json` defines the structure for repository templates including:
- Template identity and metadata
- File and directory requirements
- Dependency specifications
- Compliance checks

### Standard DevOps Template
Located in `templates/standard-devops/`, provides:
- GitOps workflow configuration
- CI/CD pipeline setup
- MCP server integration
- Standardized directory structure
- Documentation templates

## Usage Guidelines

### Best Practices
1. **Use Serena as Primary Orchestrator** - Coordinate all operations through Serena
2. **Prefer MCP Operations** - Use MCP servers over direct CLI commands when possible
3. **Repository Operations** - Use GitHub MCP for repository management
4. **Code Quality** - Validate all code with appropriate linting tools
5. **Documentation** - Update Wiki.js through wikijs-mcp server

### Integration Workflow
1. **Planning** - Use Serena to coordinate across multiple MCP servers
2. **Implementation** - Leverage GitHub MCP for repository operations
3. **Validation** - Use filesystem MCP for code quality checks
4. **Deployment** - Coordinate through GitHub Actions via GitHub MCP
5. **Monitoring** - Use Serena to orchestrate monitoring across tools

## Configuration Placeholders

When deploying MCP configuration to new environments, update these placeholders:

- `{{USERNAME}}` - System username for file paths
- `{{HASS_URL}}` - Home Assistant URL (default: http://192.168.1.155:8123)
- `{{HASS_TOKEN}}` - Home Assistant long-lived access token
- `{{GITHUB_TOKEN}}` - GitHub personal access token with repo permissions

## Troubleshooting

### Common Issues

#### MCP Server Not Responding
1. Check if required dependencies are installed
2. Verify configuration file paths exist
3. Ensure authentication tokens are valid
4. Check Docker containers are running (for containerized servers)

#### Permission Errors
1. Verify file system paths are accessible
2. Check virtual environment activation for Python servers
3. Ensure Docker has appropriate permissions

#### Template Application Failures
1. Run template detection: `.mcp/template-detector.py`
2. Check for file conflicts before application
3. Verify backup system is functional
4. Review template compliance scoring

### Getting Help

1. **Template Issues** - Review template-schema.json and template definitions
2. **MCP Configuration** - Check server-specific configuration files
3. **Deployment Problems** - Review deployment script logs in `/tmp/deploy-mcp-config.log`
4. **Integration Issues** - Verify Serena orchestration setup

## Development Notes

### Phase 1A Status: COMPLETE
- Template infrastructure foundation established
- MCP server standardization operational
- Repository detection and analysis functional
- Deployment automation tested

### Phase 1B: Template Application Engine
Ready for implementation with:
- Automated template application
- Intelligent conflict resolution
- Batch processing system
- Git integration enhancement
- Comprehensive backup and rollback

## Files Modified by MCP Infrastructure

### Auto-Generated/Managed
- `.mcp.json` - MCP server configuration (deployed by scripts)
- Template application results and logs

### User-Maintained
- Template definitions in `templates/` directory
- Server-specific configuration files
- Authentication tokens and credentials

## Security Considerations

- **Token Security**: Never commit authentication tokens to repositories
- **File Access**: MCP filesystem access is limited to configured paths
- **Network Access**: Network-based MCP servers require appropriate firewall rules
- **Docker Security**: Containerized MCP servers run with limited privileges

For detailed implementation information, see the project documentation and Phase 1A completion summary.