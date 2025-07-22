# Homelab GitOps Auditor Community Scripts

This repository contains community scripts for deploying homelab infrastructure components.

## Available Scripts

### WikiJS Integration Container (`ct/wikijs-integration.sh`)

Deploy a production-ready WikiJS integration service for GitOps document management.

**Features:**
- ✅ **Smart Container Detection** - Automatically detects existing containers
- ✅ **Update/Create Modes** - Updates existing installations or creates new containers
- ✅ **Production Ready** - Node.js 20, PM2, systemd service, nginx reverse proxy
- ✅ **Auto Configuration** - Pre-configured with WikiJS tokens and endpoints
- ✅ **Health Monitoring** - Built-in health checks and status endpoints

**One-line deployment:**
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/homelab-gitops-auditor/community-scripts/main/ct/wikijs-integration.sh)"
```

**Or using curl:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/homelab-gitops-auditor/community-scripts/main/ct/wikijs-integration.sh)"
```

**Container Specifications:**
- **CPU:** 2 cores
- **RAM:** 1GB
- **Disk:** 4GB
- **Network:** Static IP (192.168.1.200/24)
- **OS:** Debian 12 LXC

**Service Endpoints:**
- **Main Service:** `http://192.168.1.200/`
- **Health Check:** `http://192.168.1.200/health`
- **Service Status:** `http://192.168.1.200/wiki-agent/status`

## Usage Instructions

1. **First Installation:** Run the one-line command on your Proxmox host
2. **Updates:** Re-run the same command - it will detect existing containers and offer update options
3. **Multiple Containers:** The script will find available container IDs automatically

## Requirements

- Proxmox VE 8.0 or later
- Internet connection for downloading templates and dependencies
- Sufficient resources (2 CPU cores, 1GB RAM, 4GB disk space)

## Supported Operations

- **Fresh Installation** - Creates new container with WikiJS integration
- **In-place Updates** - Updates existing installations while preserving data
- **Configuration Management** - Maintains production environment settings
- **Service Management** - Automatic systemd service setup and management

## Integration

This script integrates with:
- **WikiJS** (192.168.1.90:3000) - Document management system
- **GitOps Auditor** - Repository monitoring and documentation sync
- **Proxmox VE** - Container lifecycle management

## Support

For issues, feature requests, or contributions, please visit the main project repository:
https://github.com/homelab-gitops-auditor/homelab-gitops-auditor