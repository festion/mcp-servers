# Home Assistant Installation on LXC 128
*Setup Guide for Development Environment*

## Overview
This guide installs Home Assistant Supervised on LXC 128 (192.168.1.239) to create a complete development environment for testing dashboards, automations, and integrations.

## Prerequisites

### LXC Container Requirements
- **Container**: LXC 128 
- **IP Address**: 192.168.1.239
- **OS**: Debian 11/12 or Ubuntu 20.04/22.04 LTS
- **Memory**: Minimum 2GB RAM (4GB recommended)
- **Storage**: Minimum 20GB (50GB+ recommended)
- **Network**: Bridge networking with internet access

### Access Requirements
- SSH access to LXC container as root
- SSH key-based authentication configured
- Container has internet connectivity
- Port 8123 accessible for Home Assistant web interface

## Installation Methods

### Method 1: Automated Installation (Recommended)
```bash
# Run the automated installation script
./deployment/install-ha-on-lxc128.sh
```

### Method 2: Manual Installation
If you prefer manual installation or need to troubleshoot:

#### Step 1: Connect to LXC Container
```bash
ssh root@192.168.1.239
```

#### Step 2: Update System
```bash
apt update && apt upgrade -y
```

#### Step 3: Install Prerequisites
```bash
apt install -y \
  wget curl udisks2 libglib2.0-bin \
  network-manager dbus systemd-journal-remote \
  systemd-resolved
```

#### Step 4: Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Test Docker
docker run hello-world
```

#### Step 5: Install Docker Compose
```bash
# Download Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose

# Make executable
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

#### Step 6: Install Home Assistant Supervised
```bash
# Download installer
wget https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb

# Install (may show dependency warnings - normal)
dpkg -i homeassistant-supervised.deb

# Fix any dependency issues
apt-get install -f -y
```

#### Step 7: Wait for Startup
```bash
# Monitor startup (takes 5-10 minutes)
watch -n 5 'curl -s http://localhost:8123/api/ && echo "HA Ready!" || echo "Still starting..."'
```

## Post-Installation Setup

### 1. Initial Home Assistant Configuration
1. **Access Web Interface**: http://192.168.1.239:8123
2. **Create Admin User**: Follow the setup wizard
3. **Configure Location**: Set your location and timezone
4. **Skip Integrations**: We'll configure these later via deployment

### 2. Verify Installation
```bash
# Check supervisor status
ssh root@192.168.1.239 'ha supervisor info'

# Check core status  
ssh root@192.168.1.239 'ha core info'

# View logs if needed
ssh root@192.168.1.239 'ha core logs'
```

### 3. Test API Access
```bash
# Test from development machine
curl -f -s "http://192.168.1.239:8123/api/"
# Should return: {"message": "API running."}
```

## Configuration Structure

### Default Paths
- **Configuration**: `/usr/share/hassio/homeassistant/`
- **Custom Components**: `/usr/share/hassio/homeassistant/custom_components/`
- **WWW Resources**: `/usr/share/hassio/homeassistant/www/`
- **Packages**: `/usr/share/hassio/homeassistant/packages/`

### Deployment Integration
Once installed, the deployment script will:
- Sync configuration files to `/usr/share/hassio/homeassistant/`
- Deploy development-specific secrets
- Restart Home Assistant core
- Validate configuration

## Troubleshooting

### Common Issues

#### 1. HA Not Starting
```bash
# Check supervisor logs
ssh root@192.168.1.239 'ha supervisor logs'

# Check Docker containers
ssh root@192.168.1.239 'docker ps -a'

# Restart supervisor if needed
ssh root@192.168.1.239 'systemctl restart hassio-supervisor'
```

#### 2. API Not Accessible
```bash
# Check if HA is running locally
ssh root@192.168.1.239 'curl http://localhost:8123/api/'

# Check network connectivity
ping 192.168.1.239

# Check port is open
telnet 192.168.1.239 8123
```

#### 3. Permission Issues
```bash
# Fix config directory permissions
ssh root@192.168.1.239 'chown -R root:root /usr/share/hassio/homeassistant/'
```

#### 4. Docker Issues
```bash
# Restart Docker
ssh root@192.168.1.239 'systemctl restart docker'

# Check Docker status
ssh root@192.168.1.239 'systemctl status docker'
```

### Log Locations
- **Supervisor Logs**: `ha supervisor logs`
- **Core Logs**: `ha core logs`  
- **System Logs**: `journalctl -u hassio-supervisor`
- **Docker Logs**: `docker logs homeassistant`

## Useful Commands

### Management Commands
```bash
# SSH to container
ssh root@192.168.1.239

# Check all service status
ha supervisor info

# Restart Home Assistant
ha core restart

# Update supervisor
ha supervisor update

# Backup configuration
ha backups new --name "manual-backup-$(date +%Y%m%d)"

# Restore backup
ha backups restore BACKUP_SLUG
```

### Development Commands
```bash
# Deploy configuration
./deployment/deploy-to-dev.sh

# Check configuration
ssh root@192.168.1.239 'ha core check'

# Reload configuration
ssh root@192.168.1.239 'ha core reload'

# Monitor logs
ssh root@192.168.1.239 'ha core logs -f'
```

## Integration with Development Pipeline

### Environment Variables
The installation creates a development environment that integrates with:
- **MCP Server**: `environments/development/hass-mcp-wrapper-dev.sh`
- **Deployment**: `deployment/deploy-to-dev.sh`
- **Configuration**: `environments/development/mcp-config.json`

### Development Workflow
1. **Code Changes**: Make changes in local repository
2. **Deploy**: `./deployment/deploy-to-dev.sh`
3. **Test**: Access http://192.168.1.239:8123 to test changes
4. **Debug**: Check logs and validate functionality
5. **Iterate**: Repeat cycle until satisfied

### Next Steps After Installation
1. **Test deployment pipeline**: `./deployment/deploy-to-dev.sh`
2. **Configure development secrets**: Create `environments/development/secrets.yaml`
3. **Set up MCP integration**: Test Home Assistant MCP server connection
4. **Install development add-ons**: VSCode Server, File Editor, etc.

## Security Considerations

### Development Environment Notes
- This is a **development environment** - not production-hardened
- Use development-specific credentials and tokens
- Isolate from production network if handling sensitive data
- Regular backups recommended before major configuration changes

### Network Security
- LXC container should be on isolated development network
- Consider firewall rules limiting access to development team
- Use strong passwords for Home Assistant admin account

## Maintenance

### Regular Tasks
- **Monthly**: Update Home Assistant supervisor and core
- **After Major Changes**: Create configuration backup
- **Weekly**: Review error logs and system performance

### Update Procedure
```bash
# Update supervisor
ssh root@192.168.1.239 'ha supervisor update'

# Update core (if available)
ssh root@192.168.1.239 'ha core update'

# Update all add-ons
ssh root@192.168.1.239 'ha addons update --all'
```

This installation provides a complete, isolated Home Assistant development environment for testing dashboards, automations, and integrations safely.