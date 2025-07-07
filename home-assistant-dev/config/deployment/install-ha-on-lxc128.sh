#!/bin/bash
# ===== HOME ASSISTANT INSTALLATION ON LXC 128 =====
# Purpose: Install Home Assistant Supervised on LXC 128 (192.168.1.239)
# Target: Fresh Debian/Ubuntu LXC container
# Usage: ./install-ha-on-lxc128.sh

set -e  # Exit on any error

# Configuration
LXC_HOST="192.168.1.239"
LXC_USER="root"
HA_VERSION="latest"
INSTALL_LOG="/tmp/ha-install-$(date +%Y%m%d_%H%M%S).log"

echo "🏠 Home Assistant Installation on LXC 128"
echo "========================================="
echo "Target: $LXC_HOST"
echo "Install Type: Home Assistant Supervised"
echo "Time: $(date)"
echo "Log: $INSTALL_LOG"
echo ""

# Function to run commands on LXC and log output
run_on_lxc() {
    local cmd="$1"
    local desc="$2"
    echo "📋 $desc"
    echo "   Command: $cmd"
    ssh "$LXC_USER@$LXC_HOST" "$cmd" 2>&1 | tee -a "$INSTALL_LOG"
    local exit_code=${PIPESTATUS[0]}
    if [[ $exit_code -eq 0 ]]; then
        echo "✅ Success: $desc"
    else
        echo "❌ Failed: $desc (exit code: $exit_code)"
        exit 1
    fi
    echo ""
}

# Verify LXC accessibility
echo "🔍 Checking LXC container accessibility..."
if ! ping -c 1 "$LXC_HOST" &>/dev/null; then
    echo "❌ Error: LXC container $LXC_HOST is not accessible"
    exit 1
fi

if ! ssh -o ConnectTimeout=5 "$LXC_USER@$LXC_HOST" "echo 'SSH connection successful'" &>/dev/null; then
    echo "❌ Error: Cannot SSH to $LXC_HOST"
    echo "   Ensure SSH is configured and key-based auth is set up"
    exit 1
fi

echo "✅ LXC container is accessible"
echo ""

# Check system information
echo "📊 Gathering system information..."
run_on_lxc "uname -a" "System information"
run_on_lxc "cat /etc/os-release" "OS version"
run_on_lxc "df -h /" "Disk space"
run_on_lxc "free -h" "Memory information"

# Update system packages
echo "🔄 Updating system packages..."
run_on_lxc "apt update && apt upgrade -y" "System update"

# Install prerequisites
echo "📦 Installing prerequisites..."
run_on_lxc "apt install -y wget curl udisks2 libglib2.0-bin network-manager dbus systemd-journal-remote systemd-resolved" "Install system dependencies"

# Install Docker
echo "🐳 Installing Docker..."
run_on_lxc "curl -fsSL https://get.docker.com | sh" "Install Docker"
run_on_lxc "systemctl enable docker && systemctl start docker" "Enable and start Docker"

# Verify Docker installation
run_on_lxc "docker --version" "Verify Docker installation"
run_on_lxc "docker run hello-world" "Test Docker functionality"

# Install Docker Compose
echo "🐙 Installing Docker Compose..."
run_on_lxc "curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose" "Download Docker Compose"
run_on_lxc "chmod +x /usr/local/bin/docker-compose" "Make Docker Compose executable"
run_on_lxc "docker-compose --version" "Verify Docker Compose"

# Download and install Home Assistant Supervised
echo "🏠 Installing Home Assistant Supervised..."
run_on_lxc "wget https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb" "Download HA Supervised installer"
run_on_lxc "dpkg -i homeassistant-supervised.deb || apt-get install -f -y" "Install HA Supervised (with dependency fix)"

# Wait for Home Assistant to start
echo "⏳ Waiting for Home Assistant to initialize..."
echo "   This can take 5-10 minutes for first startup..."

# Monitor HA startup
for i in {1..60}; do
    if ssh "$LXC_USER@$LXC_HOST" "curl -f -s http://localhost:8123/api/" &>/dev/null; then
        echo "✅ Home Assistant is responding!"
        break
    fi
    
    if [[ $i -eq 60 ]]; then
        echo "⚠️  Home Assistant startup taking longer than expected"
        echo "   Checking container status..."
        run_on_lxc "ha supervisor info" "Supervisor status"
        run_on_lxc "ha core logs" "Core logs (last 20 lines)"
        break
    fi
    
    echo "   Waiting... ($i/60) - $(date)"
    sleep 10
done

# Verify installation
echo "🔍 Verifying installation..."
run_on_lxc "ha supervisor info" "Supervisor information"
run_on_lxc "ha core info" "Core information"

# Check service status
run_on_lxc "systemctl status hassio-supervisor" "Supervisor service status"

# Network test
echo "🌐 Testing network connectivity..."
if ssh "$LXC_USER@$LXC_HOST" "curl -f -s http://localhost:8123/api/" &>/dev/null; then
    echo "✅ Home Assistant API is responding locally"
else
    echo "❌ Home Assistant API not responding locally"
fi

# External network test from our location
echo "🌍 Testing external access..."
if curl -f -s "http://$LXC_HOST:8123/api/" &>/dev/null; then
    echo "✅ Home Assistant is accessible externally"
else
    echo "❌ Home Assistant not accessible externally (may need time to fully start)"
fi

# Create initial configuration directory structure
echo "📁 Setting up configuration structure..."
run_on_lxc "mkdir -p /usr/share/hassio/homeassistant/custom_components" "Create custom components directory"
run_on_lxc "mkdir -p /usr/share/hassio/homeassistant/www" "Create www directory"
run_on_lxc "mkdir -p /usr/share/hassio/homeassistant/packages" "Create packages directory"

# Set proper permissions
run_on_lxc "chown -R root:root /usr/share/hassio/homeassistant/" "Set configuration ownership"

# Final status check
echo ""
echo "🎉 HOME ASSISTANT INSTALLATION SUMMARY"
echo "====================================="
echo "✅ Target: $LXC_HOST (LXC 128)"
echo "✅ Installation Type: Home Assistant Supervised"
echo "✅ Docker: Installed and running"
echo "✅ Home Assistant: Installed"
echo "✅ Configuration Path: /usr/share/hassio/homeassistant/"
echo "✅ Installation Log: $INSTALL_LOG"
echo ""
echo "🌐 Access Information:"
echo "   • Web UI: http://$LXC_HOST:8123"
echo "   • Initial setup required on first access"
echo "   • Default config location: /usr/share/hassio/homeassistant/"
echo ""
echo "🔧 Useful Commands:"
echo "   • Check status: ssh $LXC_USER@$LXC_HOST 'ha supervisor info'"
echo "   • View logs: ssh $LXC_USER@$LXC_HOST 'ha core logs'"
echo "   • Restart core: ssh $LXC_USER@$LXC_HOST 'ha core restart'"
echo "   • Update supervisor: ssh $LXC_USER@$LXC_HOST 'ha supervisor update'"
echo ""
echo "📋 Next Steps:"
echo "   1. Access http://$LXC_HOST:8123 to complete initial setup"
echo "   2. Create admin user account"
echo "   3. Test deployment: ./deployment/deploy-to-dev.sh"
echo "   4. Configure development-specific integrations"
echo ""
echo "✅ Installation completed at $(date)"