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

### 📊 WikiJS MCP Server
**Status**: ✅ Complete and Functional  
**Location**: `wikijs-mcp-server/`

WikiJS documentation management and markdown processing with automated content migration.

**Features**:
- 12 MCP tools for complete WikiJS documentation management
- Markdown file discovery and analysis
- Automated content migration to WikiJS
- Document validation and metadata extraction
- Search and retrieval capabilities
- Bulk operations with progress tracking

### 🗄️ TrueNAS MCP Server
**Status**: ✅ Complete and Functional  
**Location**: `truenas-mcp-server/`

TrueNAS Core management through natural language commands with comprehensive storage operations.

**Features**:
- 15+ MCP tools for complete TrueNAS management
- Storage pool and dataset management
- User administration and permissions control
- Snapshot and backup automation
- SMB/NFS share management
- iSCSI targets for Kubernetes integration
- ZFS property management (compression, deduplication, quotas)
- **Kubernetes Ready**: Export NFS shares and create iSCSI targets

**Key Tools**: Storage pools, datasets, users, permissions, snapshots, shares, backups, system monitoring.

### 🐙 GitHub MCP Server
**Status**: ✅ Production Ready (Forked from GitHub Official)  
**Location**: `github-mcp-server/`

Official GitHub MCP Server providing comprehensive GitHub API integration for repository management, issues, pull requests, and project boards.

**Features**:
- Complete GitHub API access through MCP protocol
- Repository management (create, update, delete, fork)
- Issues and pull requests management
- Project boards and labels administration
- GitHub Actions workflow integration
- OAuth and Personal Access Token authentication
- Remote and local deployment options

**Key Tools**: Repository operations, issue management, pull request workflows, project board management, GitHub Actions integration, user and organization management.

## 🗺️ Development Roadmap

### 🐙 GitHub MCP Server: Project Board Support Enhancement
**Priority**: High | **Phase**: Phase 1 Development  
**Target Completion**: Q1 2025

Enhance the forked GitHub MCP Server with comprehensive project board management capabilities that are currently missing from the official implementation.

#### Phase 1: Core Project Board Features (High Priority)
1. **📋 Project Board Creation & Management**
   - Create new project boards with customizable templates
   - Configure board settings and automation rules
   - Board deletion and archival operations
   - Template-based board creation for standardized workflows

2. **🎯 Column Management**
   - Create, update, and delete project board columns
   - Reorder columns and configure column automation
   - Custom column types and field configurations
   - Column limits and WIP (Work In Progress) constraints

3. **🎴 Card Operations**
   - Add issues and pull requests to project boards
   - Move cards between columns programmatically
   - Update card metadata and custom fields
   - Bulk card operations and batch processing

#### Phase 2: Advanced Automation (Medium Priority)
4. **⚙️ Workflow Automation**
   - Automated card movement based on issue/PR status
   - Custom automation rules and triggers
   - Integration with GitHub Actions workflows
   - Event-driven card updates and notifications

5. **📊 Cross-Repository Project Management**
   - Multi-repository project board support
   - Organization-level project management
   - Repository linking and dependency tracking
   - Unified project dashboard across repositories

#### Phase 3: Template & Integration Features (Medium Priority)
6. **📐 Project Templates**
   - Standardized project board templates (Kanban, Scrum, Bug Triage)
   - Template customization and sharing
   - Quick project setup from templates
   - Template versioning and updates

7. **🔗 Advanced Integrations**
   - Project progress reporting and analytics
   - Integration with external project management tools
   - Custom field types and validation
   - Export/import functionality for project data

#### Technical Implementation Plan
- **New MCP Tools**: 15+ specialized tools for project board operations
- **API Integration**: GitHub Projects API v2 GraphQL integration
- **Authentication**: OAuth and PAT support with proper scoping
- **Error Handling**: Comprehensive error handling with retry logic
- **Performance**: Optimized queries and caching for large projects
- **Testing**: Unit and integration tests for all project board operations

#### Success Metrics
- **Feature Parity**: Complete project board management capabilities
- **Performance**: Sub-200ms response times for project operations
- **Reliability**: 99.9% operation success rate
- **Integration**: Seamless Claude Desktop integration with project workflows
- **Adoption**: Enhanced project management capabilities for all MCP users

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
    },
    "github": {
      "command": "path/to/github-mcp-server/github-mcp-server",
      "args": [],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token"
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
