#!/bin/bash
# ===== LXC 128 READINESS CHECK =====
# Purpose: Verify LXC 128 is ready for Home Assistant installation
# Usage: ./check-lxc128-readiness.sh

LXC_HOST="192.168.1.239"
LXC_USER="root"

echo "🔍 LXC 128 Readiness Check"
echo "=========================="
echo "Target: $LXC_HOST"
echo "Time: $(date)"
echo ""

# Network connectivity
echo "📡 Network Connectivity:"
if ping -c 3 "$LXC_HOST" >/dev/null 2>&1; then
    echo "✅ Network: Reachable"
else
    echo "❌ Network: Not reachable"
    exit 1
fi

# SSH connectivity
echo "🔑 SSH Access:"
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$LXC_USER@$LXC_HOST" "echo 'SSH OK'" >/dev/null 2>&1; then
    echo "✅ SSH: Accessible with key-based auth"
else
    echo "❌ SSH: Not accessible or requires password"
    echo "   Configure SSH key-based authentication first"
    exit 1
fi

# System information
echo "💻 System Information:"
OS_INFO=$(ssh "$LXC_USER@$LXC_HOST" "cat /etc/os-release | grep PRETTY_NAME" 2>/dev/null | cut -d'"' -f2)
echo "   OS: $OS_INFO"

ARCH=$(ssh "$LXC_USER@$LXC_HOST" "uname -m" 2>/dev/null)
echo "   Architecture: $ARCH"

# Memory check
MEMORY=$(ssh "$LXC_USER@$LXC_HOST" "free -m | awk 'NR==2{printf \"%.1f GB\", \$2/1024}'" 2>/dev/null)
echo "   Memory: $MEMORY"

# Disk space check  
DISK=$(ssh "$LXC_USER@$LXC_HOST" "df -h / | awk 'NR==2{print \$4}'" 2>/dev/null)
echo "   Available Disk: $DISK"

# Check if ports are available
echo "🚪 Port Availability:"
if ssh "$LXC_USER@$LXC_HOST" "ss -tuln | grep :8123" >/dev/null 2>&1; then
    echo "⚠️  Port 8123: Already in use (HA may already be installed)"
else
    echo "✅ Port 8123: Available"
fi

# Check for existing Docker
echo "🐳 Docker Status:"
if ssh "$LXC_USER@$LXC_HOST" "command -v docker" >/dev/null 2>&1; then
    DOCKER_VERSION=$(ssh "$LXC_USER@$LXC_HOST" "docker --version" 2>/dev/null)
    echo "✅ Docker: Already installed ($DOCKER_VERSION)"
else
    echo "📦 Docker: Not installed (will be installed)"
fi

# Check internet connectivity from LXC
echo "🌐 Internet Access:"
if ssh "$LXC_USER@$LXC_HOST" "curl -s --connect-timeout 5 https://github.com >/dev/null" 2>/dev/null; then
    echo "✅ Internet: Available"
else
    echo "❌ Internet: Not available from container"
    echo "   Check container network configuration"
fi

# Summary
echo ""
echo "📋 Readiness Summary:"
echo "===================="

# Calculate readiness score
CHECKS_PASSED=0
TOTAL_CHECKS=5

# Recheck key requirements
ping -c 1 "$LXC_HOST" >/dev/null 2>&1 && ((CHECKS_PASSED++))
ssh -o ConnectTimeout=5 -o BatchMode=yes "$LXC_USER@$LXC_HOST" "echo test" >/dev/null 2>&1 && ((CHECKS_PASSED++))
ssh "$LXC_USER@$LXC_HOST" "curl -s --connect-timeout 5 https://github.com >/dev/null" 2>/dev/null && ((CHECKS_PASSED++))

# Check sufficient resources
MEMORY_MB=$(ssh "$LXC_USER@$LXC_HOST" "free -m | awk 'NR==2{print \$2}'" 2>/dev/null)
if [[ $MEMORY_MB -ge 2048 ]]; then
    ((CHECKS_PASSED++))
    echo "✅ Memory: Sufficient ($MEMORY_MB MB)"
else
    echo "⚠️  Memory: Low ($MEMORY_MB MB, recommend 2GB+)"
fi

DISK_AVAIL=$(ssh "$LXC_USER@$LXC_HOST" "df / | awk 'NR==2{print \$4}'" 2>/dev/null)
if [[ $DISK_AVAIL -ge 20971520 ]]; then  # 20GB in KB
    ((CHECKS_PASSED++))
    echo "✅ Disk: Sufficient space"
else
    echo "⚠️  Disk: Limited space (recommend 20GB+)"
fi

echo ""
if [[ $CHECKS_PASSED -ge 4 ]]; then
    echo "🎉 READY FOR INSTALLATION ($CHECKS_PASSED/$TOTAL_CHECKS checks passed)"
    echo ""
    echo "Next step: ./deployment/install-ha-on-lxc128.sh"
    exit 0
else
    echo "❌ NOT READY ($CHECKS_PASSED/$TOTAL_CHECKS checks passed)"
    echo ""
    echo "Please resolve the issues above before installation"
    exit 1
fi