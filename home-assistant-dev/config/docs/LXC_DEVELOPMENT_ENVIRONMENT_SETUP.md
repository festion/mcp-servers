# Home Assistant LXC Development Environment Setup Guide
**Created**: 2025-06-30
**Purpose**: Establish proper dev/test/prod workflow using LXC containers

## Overview
This guide establishes a modern, containerized development workflow to replace the current backwards production-first approach.

## Architecture Design

### Current (Problematic) Workflow
```
Direct Production Edit (192.168.1.155) → Local Sync → Git Commit
```
**Issues**: No testing, production risk, backwards version control

### New (Recommended) Workflow  
```
Local Git → Dev LXC 128 → Test LXC 129 → Production 192.168.1.155 → Git Commit
```
**Benefits**: Proper testing, version control, zero production risk

## LXC Container Specifications

### Development Container (LXC 128)
```yaml
Container: ha-dev-128
Purpose: Active development and feature work
OS: Home Assistant OS (latest)
Resources:
  CPU: 4 cores
  RAM: 4GB
  Storage: 32GB
  Network: 192.168.1.128/24
Services:
  - Home Assistant Core
  - MQTT (development broker)
  - MariaDB (local)
  - Code editor access
  - Git integration
Access:
  - SSH: port 22
  - Web UI: 192.168.1.128:8123
  - SMB: //192.168.1.128/config
Configuration:
  - Clean slate HA installation
  - Development-safe device integrations
  - Mock/simulated sensors for testing
  - Debug logging enabled
```

### Testing Container (LXC 129)
```yaml
Container: ha-test-129  
Purpose: Pre-production validation and QA
OS: Home Assistant OS (production version)
Resources:
  CPU: 4 cores
  RAM: 4GB
  Storage: 32GB
  Network: 192.168.1.129/24
Services:
  - Home Assistant Core (prod version)
  - MQTT (isolated test broker)
  - MariaDB (local)
  - All production integrations
Access:
  - SSH: port 22
  - Web UI: 192.168.1.129:8123
  - SMB: //192.168.1.129/config
Configuration:
  - Mirror of production configuration
  - Same device integrations (test mode)
  - Production logging levels
  - Performance monitoring
```

### Production Server (Existing 192.168.1.155)
```yaml
Server: ha-prod-155
Purpose: Live production system
Current Setup: Maintained as-is
Access: Read-only except for approved deployments
Configuration: Current working setup
```

## LXC Container Creation Commands

### Proxmox LXC Creation
```bash
# Development Container (LXC 128)
pct create 128 local:vztmpl/haos-generic-x86-64.tar.gz \
  --cores 4 \
  --memory 4096 \
  --swap 512 \
  --storage local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.128/24,gw=192.168.1.1 \
  --hostname ha-dev-128 \
  --description "Home Assistant Development Environment"

# Testing Container (LXC 129)  
pct create 129 local:vztmpl/haos-generic-x86-64.tar.gz \
  --cores 4 \
  --memory 4096 \
  --swap 512 \
  --storage local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.129/24,gw=192.168.1.1 \
  --hostname ha-test-129 \
  --description "Home Assistant Testing Environment"

# Start containers
pct start 128
pct start 129
```

### Initial Container Setup
```bash
# For each container (128, 129):
# 1. Access container console
pct console 128

# 2. Initial Home Assistant setup via web UI
# Visit: http://192.168.1.128:8123

# 3. Enable SSH and SMB access
# Configure in HA: Settings > Add-ons > SSH & Web Terminal
# Configure in HA: Settings > Add-ons > Samba share

# 4. Create development user
# HA Settings > People > Add Person (developer access)
```

## Network Configuration

### SMB Share Access
```bash
# Development environment
//192.168.1.128/config

# Testing environment  
//192.168.1.129/config

# Production environment (existing)
//192.168.1.155/config
```

### SSH Access Setup
```bash
# Development
ssh ha-dev@192.168.1.128

# Testing
ssh ha-test@192.168.1.129

# Production (existing)
ssh ha-prod@192.168.1.155
```

## Development Workflow Integration

### MCP Server Environment Targeting
```bash
# Development MCP configuration
export HASS_URL="http://192.168.1.128:8123"
export HASS_TOKEN="dev-token-here"

# Testing MCP configuration  
export HASS_URL="http://192.168.1.129:8123"
export HASS_TOKEN="test-token-here"

# Production MCP configuration (existing)
export HASS_URL="http://192.168.1.155:8123"
export HASS_TOKEN="prod-token-here"
```

### Git Repository Structure
```
home-assistant-config/
├── environments/
│   ├── development/     # LXC 128 specific configs
│   ├── testing/         # LXC 129 specific configs
│   └── production/      # LXC 155 specific configs
├── shared/              # Common configurations
│   ├── automations/
│   ├── scripts/
│   ├── templates/
│   └── packages/
├── deployment/
│   ├── deploy-to-dev.sh
│   ├── deploy-to-test.sh
│   └── deploy-to-prod.sh
└── docs/
    └── DEVELOPMENT_WORKFLOW.md
```

## Container Lifecycle Management

### Development Container (128)
- **Purpose**: Daily development work
- **Rebuilds**: Monthly or as needed for testing
- **Data**: Ephemeral, Git-backed
- **Backups**: Configuration only (via Git)

### Testing Container (129)
- **Purpose**: Pre-production validation
- **Updates**: Mirror production version
- **Data**: Production configuration copy
- **Backups**: Weekly automated snapshots

### Production Container (155)
- **Purpose**: Live system
- **Updates**: Only after testing validation
- **Data**: Critical, backed up daily
- **Monitoring**: 24/7 health monitoring

## Security Considerations

### Container Isolation
- Each container runs in isolated network namespace
- No direct container-to-container communication
- Production secrets isolated from dev/test
- Separate MQTT brokers for each environment

### Access Control
- Development: Full access for experimentation
- Testing: Read/write for validation
- Production: Read-only except during deployments
- SSH keys unique per environment

### Data Protection
- Development: Mock/test data only
- Testing: Sanitized production data
- Production: Full security measures
- Secrets management per environment

## Implementation Timeline

### Phase 1: Container Creation (Week 1)
- [x] Create LXC 128 (Development)
- [x] Create LXC 129 (Testing)  
- [x] Initial Home Assistant setup
- [x] Network access configuration

### Phase 2: Workflow Integration (Week 2)
- [ ] Git repository restructuring
- [ ] MCP server multi-environment support
- [ ] Deployment script creation
- [ ] Documentation updates

### Phase 3: Migration (Week 3)
- [ ] Production configuration migration to testing
- [ ] Workflow validation and testing
- [ ] Team training on new process
- [ ] Legacy cleanup

### Phase 4: Production Rollout (Week 4)
- [ ] Full workflow implementation
- [ ] Production deployment via new process
- [ ] Legacy system decommission
- [ ] Performance monitoring

## Maintenance Procedures

### Weekly Tasks
- Update testing container with production config
- Review development container resource usage
- Validate backup procedures
- Performance monitoring review

### Monthly Tasks
- Rebuild development container (clean slate)
- Security updates across all containers
- Workflow optimization review
- Documentation updates

### Quarterly Tasks
- Full architecture review
- Capacity planning assessment
- Disaster recovery testing
- Process improvement evaluation

## Troubleshooting

### Common Issues
- Container startup failures: Check Proxmox logs
- Network connectivity: Verify bridge configuration
- SMB access issues: Check firewall rules
- HA startup problems: Review container resources

### Recovery Procedures
- Development failure: Rebuild from Git
- Testing failure: Restore from snapshot
- Production failure: Standard HA recovery procedures
- Network issues: Proxmox network troubleshooting

## Success Metrics

### Development Efficiency
- Faster feature development cycle
- Reduced production incidents
- Improved code quality via testing
- Better collaboration via proper Git workflow

### System Reliability
- Zero production downtime from development
- Faster issue resolution via testing environment
- Improved rollback capabilities
- Better change management

### Team Productivity  
- Clearer development process
- Reduced context switching
- Better debugging capabilities
- Improved documentation

---

**Next Steps**: Execute Phase 1 container creation and proceed with workflow integration.