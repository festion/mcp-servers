# GitHub Actions Self-Hosted Runner Installation Guide

## Table of Contents
1. [Prerequisites Verification](#1-prerequisites-verification)
2. [Repository Setup](#2-repository-setup)
3. [Installation Steps](#3-installation-steps)
4. [Container Configuration](#4-container-configuration)
5. [Verification Steps](#5-verification-steps)
6. [Troubleshooting](#6-troubleshooting)
7. [Maintenance](#7-maintenance)

---

## 1. Prerequisites Verification

### 1.1 System Requirements

**Minimum Hardware Requirements:**
- **CPU**: 4 cores (Intel/AMD x86_64)
- **Memory**: 8 GB RAM
- **Storage**: 40 GB available disk space (SSD recommended)
- **Network**: Stable internet connection with access to GitHub.com

**Recommended Hardware:**
- **CPU**: 6+ cores
- **Memory**: 12+ GB RAM
- **Storage**: 60+ GB SSD
- **Network**: 100+ Mbps bandwidth

### 1.2 Operating System Requirements

**Supported Operating Systems:**
- Ubuntu 20.04 LTS or later
- Debian 11 or later
- CentOS 8 or later
- RHEL 8 or later

**Current System Check:**
```bash
# Check OS version
cat /etc/os-release

# Check CPU cores
nproc

# Check available memory
free -h

# Check disk space
df -h /home/dev/workspace
```

### 1.3 Network Connectivity Requirements

**Required Network Access:**
- **GitHub.com**: HTTPS (443) for runner registration and communication
- **Docker Hub**: HTTPS (443) for container image pulls
- **Private Network**: Access to 192.168.1.155 (Home Assistant)
- **Local Network**: Access to 192.168.1.0/24 subnet

**Network Connectivity Test:**
```bash
# Test GitHub connectivity
curl -I https://github.com

# Test Docker Hub connectivity
curl -I https://registry-1.docker.io

# Test Home Assistant connectivity
ping -c 4 192.168.1.155

# Test local network access
ip route show | grep 192.168.1.0
```

### 1.4 User Permissions

**Required Permissions:**
- **Docker Group**: User must be in docker group
- **Sudo Access**: Required for initial setup
- **File Permissions**: Write access to /home/dev/workspace

**Permission Verification:**
```bash
# Check current user
whoami

# Check docker group membership
groups $USER | grep docker

# Check sudo access
sudo -l

# Check write permissions
touch /home/dev/workspace/test_file && rm /home/dev/workspace/test_file
```

---

## 2. Repository Setup

### 2.1 GitHub Personal Access Token

**Token Generation Steps:**
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Click "Generate new token (classic)"
3. Set expiration (recommend 90 days)
4. Select required scopes:
   - `repo` (Full control of private repositories)
   - `admin:repo_hook` (Repository hooks)
   - `workflow` (Update GitHub Action workflows)

**Token Verification:**
```bash
# Test token (replace YOUR_TOKEN with actual token)
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
```

### 2.2 Repository Configuration

**Runner Registration Requirements:**
- Repository admin access
- Actions enabled in repository settings
- Self-hosted runners allowed in organization settings (if applicable)

**Repository Settings Check:**
1. Go to Repository → Settings → Actions → General
2. Ensure "Allow all actions and reusable workflows" is selected
3. Under "Runners", ensure "Allow self-hosted runners" is enabled

### 2.3 Runner Registration Token

**Generate Registration Token:**
1. Navigate to Repository → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Select "Linux" as the operating system
4. Copy the registration token (starts with `ACTIONS_RUNNER_TOKEN_`)

**Token Format Validation:**
```bash
# Token should match this pattern
echo "ACTIONS_RUNNER_TOKEN_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ABCDEF"
```

---

## 3. Installation Steps

### 3.1 Docker Installation

**Ubuntu/Debian Installation:**
```bash
# Update package index
sudo apt update

# Install required packages
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt update

# Install Docker Engine
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

**CentOS/RHEL Installation:**
```bash
# Install required packages
sudo yum install -y yum-utils

# Add Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

### 3.2 Docker Compose Installation

**Install Docker Compose (if not included):**
```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make executable
sudo chmod +x /usr/local/bin/docker-compose

# Create symlink
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify installation
docker-compose --version
```

### 3.3 Project Directory Setup

**Create Directory Structure:**
```bash
# Navigate to workspace
cd /home/dev/workspace

# Create project directory
mkdir -p github-actions-runner/{config,logs,workspace,scripts}

# Set proper permissions
chmod 755 github-actions-runner
chmod 755 github-actions-runner/{config,logs,workspace,scripts}

# Navigate to project directory
cd github-actions-runner
```

### 3.4 Environment Configuration

**Create Environment File:**
```bash
# Create .env file
cat > .env << 'EOF'
# GitHub Configuration
GITHUB_OWNER=your-github-username
GITHUB_REPOSITORY=your-repository-name
GITHUB_TOKEN=your-personal-access-token
RUNNER_NAME=homelab-runner-01
RUNNER_LABELS=self-hosted,linux,homelab

# Runner Configuration
RUNNER_WORKDIR=/workspace
RUNNER_EPHEMERAL=false
RUNNER_REPLACE_EXISTING=true

# Network Configuration
RUNNER_NETWORK=github-runner-network
RUNNER_SUBNET=172.20.0.0/16

# Resource Configuration
RUNNER_CPU_LIMIT=4
RUNNER_MEMORY_LIMIT=8g

# Home Assistant Configuration
HOMEASSISTANT_HOST=192.168.1.155
HOMEASSISTANT_USER=homeassistant
HOMEASSISTANT_SSH_KEY_PATH=./config/homeassistant_key
EOF
```

**Set Environment File Permissions:**
```bash
# Secure environment file
chmod 600 .env

# Verify permissions
ls -la .env
```

---

## 4. Container Configuration

### 4.1 Docker Compose Configuration

**Create docker-compose.yml:**
```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  github-runner:
    image: ghcr.io/actions/actions-runner:latest
    container_name: github-actions-runner
    restart: unless-stopped
    environment:
      - GITHUB_OWNER=${GITHUB_OWNER}
      - GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - RUNNER_NAME=${RUNNER_NAME}
      - RUNNER_LABELS=${RUNNER_LABELS}
      - RUNNER_WORKDIR=${RUNNER_WORKDIR}
      - RUNNER_EPHEMERAL=${RUNNER_EPHEMERAL}
      - RUNNER_REPLACE_EXISTING=${RUNNER_REPLACE_EXISTING}
    volumes:
      - ./config:/runner/config
      - ./workspace:/workspace
      - ./logs:/runner/logs
      - /var/run/docker.sock:/var/run/docker.sock
      - ${HOMEASSISTANT_SSH_KEY_PATH}:/runner/.ssh/id_rsa:ro
    networks:
      - github-runner-network
    deploy:
      resources:
        limits:
          cpus: '${RUNNER_CPU_LIMIT}'
          memory: ${RUNNER_MEMORY_LIMIT}
    healthcheck:
      test: ["CMD", "pgrep", "-f", "Runner.Listener"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  runner-monitor:
    image: alpine:latest
    container_name: github-runner-monitor
    restart: unless-stopped
    volumes:
      - ./logs:/logs
      - ./scripts:/scripts
    networks:
      - github-runner-network
    command: ["/scripts/health-monitor.sh"]
    depends_on:
      - github-runner

networks:
  github-runner-network:
    driver: bridge
    ipam:
      config:
        - subnet: ${RUNNER_SUBNET}
          gateway: 172.20.0.1

volumes:
  runner-config:
    driver: local
  runner-workspace:
    driver: local
  runner-logs:
    driver: local
EOF
```

### 4.2 SSH Key Configuration

**Generate SSH Key for Home Assistant Access:**
```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ./config/homeassistant_key -N ""

# Set proper permissions
chmod 600 ./config/homeassistant_key
chmod 644 ./config/homeassistant_key.pub

# Display public key for copying to Home Assistant
echo "Copy this public key to Home Assistant ~/.ssh/authorized_keys:"
cat ./config/homeassistant_key.pub
```

### 4.3 Health Monitor Script

**Create Health Monitor Script:**
```bash
cat > scripts/health-monitor.sh << 'EOF'
#!/bin/bash

# Health monitor for GitHub Actions runner
LOG_FILE="/logs/health-monitor.log"
CHECK_INTERVAL=30
MAX_RETRIES=3

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_runner_health() {
    local container_name="github-actions-runner"
    local health_status
    
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    
    if [[ "$health_status" == "healthy" ]]; then
        return 0
    else
        return 1
    fi
}

check_network_connectivity() {
    local target_host="192.168.1.155"
    
    if ping -c 1 -W 5 "$target_host" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

restart_runner() {
    log "Restarting GitHub Actions runner..."
    docker-compose restart github-runner
    sleep 30
}

main() {
    log "Starting health monitor..."
    
    while true; do
        if ! check_runner_health; then
            log "Runner health check failed"
            restart_runner
        fi
        
        if ! check_network_connectivity; then
            log "Network connectivity check failed"
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

main "$@"
EOF

# Make script executable
chmod +x scripts/health-monitor.sh
```

### 4.4 Runner Registration Script

**Create Registration Script:**
```bash
cat > scripts/register-runner.sh << 'EOF'
#!/bin/bash

set -e

# Load environment variables
source .env

# Check if runner is already registered
if [[ -f "./config/.runner" ]]; then
    echo "Runner already registered. Use --force to re-register."
    if [[ "$1" != "--force" ]]; then
        exit 0
    fi
fi

# Get registration token
echo "Getting registration token..."
REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY/actions/runners/registration-token" \
    | jq -r '.token')

if [[ "$REGISTRATION_TOKEN" == "null" ]]; then
    echo "Failed to get registration token"
    exit 1
fi

# Register runner
echo "Registering runner..."
docker run --rm \
    -v "$(pwd)/config:/runner/config" \
    -e GITHUB_OWNER="$GITHUB_OWNER" \
    -e GITHUB_REPOSITORY="$GITHUB_REPOSITORY" \
    -e REGISTRATION_TOKEN="$REGISTRATION_TOKEN" \
    -e RUNNER_NAME="$RUNNER_NAME" \
    -e RUNNER_LABELS="$RUNNER_LABELS" \
    ghcr.io/actions/actions-runner:latest \
    ./config.sh --url "https://github.com/$GITHUB_OWNER/$GITHUB_REPOSITORY" \
                --token "$REGISTRATION_TOKEN" \
                --name "$RUNNER_NAME" \
                --labels "$RUNNER_LABELS" \
                --work "/workspace" \
                --unattended

echo "Runner registered successfully!"
EOF

# Make script executable
chmod +x scripts/register-runner.sh
```

---

## 5. Verification Steps

### 5.1 Pre-flight System Check

**Create Pre-flight Check Script:**
```bash
cat > scripts/preflight-check.sh << 'EOF'
#!/bin/bash

# Pre-flight system check for GitHub Actions runner
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_passed=0
check_failed=0

print_status() {
    if [[ $2 -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $1"
        ((check_passed++))
    else
        echo -e "${RED}✗${NC} $1"
        ((check_failed++))
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check Docker installation
echo "Checking Docker installation..."
if command -v docker &> /dev/null; then
    print_status "Docker is installed" 0
    docker --version
else
    print_status "Docker is not installed" 1
fi

# Check Docker service
echo "Checking Docker service..."
if systemctl is-active --quiet docker; then
    print_status "Docker service is running" 0
else
    print_status "Docker service is not running" 1
fi

# Check Docker permissions
echo "Checking Docker permissions..."
if docker ps &> /dev/null; then
    print_status "Docker permissions are correct" 0
else
    print_status "Docker permissions issue - user not in docker group" 1
    print_warning "Run: sudo usermod -aG docker \$USER && newgrp docker"
fi

# Check Docker Compose
echo "Checking Docker Compose..."
if command -v docker-compose &> /dev/null; then
    print_status "Docker Compose is installed" 0
    docker-compose --version
else
    print_status "Docker Compose is not installed" 1
fi

# Check system resources
echo "Checking system resources..."
cpu_cores=$(nproc)
memory_gb=$(free -g | awk 'NR==2{printf "%.1f", $2}')
disk_space=$(df -BG /home/dev/workspace | awk 'NR==2{print $4}' | sed 's/G//')

if [[ $cpu_cores -ge 4 ]]; then
    print_status "CPU cores: $cpu_cores (minimum 4)" 0
else
    print_status "CPU cores: $cpu_cores (minimum 4 required)" 1
fi

if (( $(echo "$memory_gb >= 8" | bc -l) )); then
    print_status "Memory: ${memory_gb}GB (minimum 8GB)" 0
else
    print_status "Memory: ${memory_gb}GB (minimum 8GB required)" 1
fi

if [[ $disk_space -ge 40 ]]; then
    print_status "Disk space: ${disk_space}GB (minimum 40GB)" 0
else
    print_status "Disk space: ${disk_space}GB (minimum 40GB required)" 1
fi

# Check network connectivity
echo "Checking network connectivity..."
if curl -s --max-time 10 https://github.com &> /dev/null; then
    print_status "GitHub connectivity" 0
else
    print_status "GitHub connectivity" 1
fi

if curl -s --max-time 10 https://registry-1.docker.io &> /dev/null; then
    print_status "Docker Hub connectivity" 0
else
    print_status "Docker Hub connectivity" 1
fi

if ping -c 1 -W 5 192.168.1.155 &> /dev/null; then
    print_status "Home Assistant connectivity (192.168.1.155)" 0
else
    print_status "Home Assistant connectivity (192.168.1.155)" 1
fi

# Check environment file
echo "Checking environment configuration..."
if [[ -f ".env" ]]; then
    print_status "Environment file exists" 0
    if grep -q "GITHUB_TOKEN=" .env && [[ $(grep "GITHUB_TOKEN=" .env | cut -d'=' -f2) != "your-personal-access-token" ]]; then
        print_status "GitHub token configured" 0
    else
        print_status "GitHub token not configured" 1
    fi
else
    print_status "Environment file missing" 1
fi

# Summary
echo
echo "=== Pre-flight Check Summary ==="
echo -e "${GREEN}Passed: $check_passed${NC}"
echo -e "${RED}Failed: $check_failed${NC}"

if [[ $check_failed -eq 0 ]]; then
    echo -e "${GREEN}All checks passed! Ready to proceed with installation.${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed. Please resolve issues before proceeding.${NC}"
    exit 1
fi
EOF

# Make script executable
chmod +x scripts/preflight-check.sh
```

### 5.2 Installation Verification

**Run Pre-flight Check:**
```bash
# Execute pre-flight check
./scripts/preflight-check.sh
```

**Configure Environment Variables:**
```bash
# Edit .env file with your actual values
nano .env

# Verify configuration
source .env
echo "Repository: $GITHUB_OWNER/$GITHUB_REPOSITORY"
echo "Runner Name: $RUNNER_NAME"
```

**Register Runner:**
```bash
# Register the runner with GitHub
./scripts/register-runner.sh
```

**Start Services:**
```bash
# Start the runner services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f github-runner
```

### 5.3 Network Connectivity Tests

**Test Network Access:**
```bash
# Test from within runner container
docker exec github-actions-runner ping -c 3 192.168.1.155

# Test SSH connectivity
docker exec github-actions-runner ssh -o StrictHostKeyChecking=no homeassistant@192.168.1.155 "echo 'SSH connection successful'"
```

### 5.4 Runner Registration Confirmation

**Verify Runner Registration:**
```bash
# Check GitHub repository settings
echo "Verify runner appears in: https://github.com/$GITHUB_OWNER/$GITHUB_REPOSITORY/settings/actions/runners"

# Check runner status
docker exec github-actions-runner ./run.sh --once --check
```

### 5.5 Basic Functionality Tests

**Create Test Workflow:**
```yaml
# Create .github/workflows/test-runner.yml in your repository
name: Test Self-Hosted Runner

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Test basic functionality
        run: |
          echo "Runner is working!"
          whoami
          pwd
          docker --version
          
      - name: Test network connectivity
        run: |
          ping -c 3 192.168.1.155
          
      - name: Test SSH access
        run: |
          ssh -o StrictHostKeyChecking=no homeassistant@192.168.1.155 "echo 'SSH test successful'"
```

---

## 6. Troubleshooting

### 6.1 Common Installation Issues

**Issue: Docker permission denied**
```bash
# Solution: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or restart session
logout
# Login again
```

**Issue: Runner registration fails**
```bash
# Check token validity
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Check repository access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY
```

**Issue: Container fails to start**
```bash
# Check container logs
docker-compose logs github-runner

# Check system resources
docker stats

# Check Docker daemon status
sudo systemctl status docker
```

### 6.2 Network Connectivity Issues

**Issue: Cannot reach 192.168.1.155**
```bash
# Check routing table
ip route show

# Check firewall rules
sudo iptables -L

# Test from host
ping 192.168.1.155
```

**Issue: SSH connection fails**
```bash
# Check SSH key permissions
ls -la config/homeassistant_key

# Test SSH from host
ssh -i config/homeassistant_key homeassistant@192.168.1.155

# Check SSH key is added to Home Assistant
cat config/homeassistant_key.pub
```

### 6.3 Runner Performance Issues

**Issue: High resource usage**
```bash
# Monitor resource usage
docker stats github-actions-runner

# Check disk usage
df -h

# Check memory usage
free -h

# Adjust resource limits in docker-compose.yml
```

### 6.4 GitHub Integration Issues

**Issue: Runner not appearing in GitHub**
```bash
# Check runner registration
cat config/.runner

# Re-register runner
./scripts/register-runner.sh --force

# Check GitHub API access
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPOSITORY/actions/runners"
```

---

## 7. Maintenance

### 7.1 Regular Updates

**Update Container Images:**
```bash
# Pull latest images
docker-compose pull

# Restart services
docker-compose up -d
```

**Update Runner Configuration:**
```bash
# Update environment variables
nano .env

# Restart services
docker-compose restart
```

### 7.2 Log Management

**Log Rotation:**
```bash
# Add to crontab
0 2 * * * /usr/bin/docker exec github-actions-runner logrotate /etc/logrotate.conf
```

**Log Monitoring:**
```bash
# Monitor logs
docker-compose logs -f --tail=100 github-runner

# Check log sizes
du -sh logs/
```

### 7.3 Backup and Recovery

**Backup Configuration:**
```bash
# Create backup
tar -czf github-runner-backup-$(date +%Y%m%d).tar.gz config/ .env docker-compose.yml

# Restore from backup
tar -xzf github-runner-backup-YYYYMMDD.tar.gz
```

---

## 8. Next Steps

After successful installation:

1. **Configure Workflows**: Update your GitHub Actions workflows to use `runs-on: self-hosted`
2. **Set Up Monitoring**: Implement comprehensive monitoring and alerting
3. **Security Hardening**: Review and implement additional security measures
4. **Performance Tuning**: Optimize resource allocation based on actual usage
5. **Documentation**: Document your specific configuration and procedures

---

**Installation Guide Version**: 1.0  
**Last Updated**: 2025-07-16  
**Compatibility**: Docker 20.10+, Docker Compose 2.0+  
**Support**: Refer to TROUBLESHOOTING.md for additional help