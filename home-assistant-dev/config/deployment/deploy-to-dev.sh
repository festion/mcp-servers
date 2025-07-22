#!/bin/bash
# ===== HOME ASSISTANT DEVELOPMENT DEPLOYMENT SCRIPT =====
# Purpose: Deploy configuration changes to development LXC container (128)
# Target: 192.168.1.128 (ha-dev-128)
# Usage: ./deploy-to-dev.sh [branch-name]

set -e  # Exit on any error

# Configuration
DEV_HOST="192.168.1.239"
DEV_USER="root"
DEV_CONFIG_PATH="/usr/share/hassio/homeassistant"
LOCAL_CONFIG_PATH="$(pwd)"
BRANCH_NAME="${1:-development}"

echo "🚀 Home Assistant Development Deployment"
echo "========================================"
echo "Target: $DEV_HOST (LXC 128 - 192.168.1.239)"
echo "Branch: $BRANCH_NAME"
echo "Time: $(date)"
echo ""

# Verify we're in the right directory
if [[ ! -f "configuration.yaml" ]]; then
    echo "❌ Error: Must run from Home Assistant config directory"
    echo "   Expected to find configuration.yaml in current directory"
    exit 1
fi

# Check if development container is accessible
echo "🔍 Checking development container accessibility..."
if ! ping -c 1 "$DEV_HOST" &>/dev/null; then
    echo "❌ Error: Development container $DEV_HOST is not accessible"
    echo "   Please ensure LXC 128 is running and network is configured"
    exit 1
fi

# Switch to specified branch
echo "🔄 Switching to branch: $BRANCH_NAME"
if ! git checkout "$BRANCH_NAME" 2>/dev/null; then
    echo "⚠️  Warning: Branch $BRANCH_NAME doesn't exist, staying on current branch"
    CURRENT_BRANCH=$(git branch --show-current)
    echo "   Current branch: $CURRENT_BRANCH"
fi

# Validate configuration before deployment
echo "🔍 Validating Home Assistant configuration..."
if command -v hass &>/dev/null; then
    if ! hass --script check_config --config . &>/dev/null; then
        echo "❌ Error: Configuration validation failed"
        echo "   Please fix configuration errors before deployment"
        exit 1
    fi
    echo "✅ Configuration validation passed"
else
    echo "⚠️  Warning: Home Assistant CLI not available, skipping local validation"
fi

# Create backup of current development config
echo "💾 Creating backup of current development configuration..."
BACKUP_DIR="/tmp/ha-dev-backup-$(date +%Y%m%d_%H%M%S)"
ssh "$DEV_USER@$DEV_HOST" "mkdir -p $BACKUP_DIR && cp -r $DEV_CONFIG_PATH/* $BACKUP_DIR/" || {
    echo "⚠️  Warning: Backup creation failed, continuing anyway"
}

# Sync configuration to development container
echo "📤 Syncing configuration to development container..."
rsync -avz --delete \
    --exclude='.git/' \
    --exclude='deployment/' \
    --exclude='docs/' \
    --exclude='*.log' \
    --exclude='*.db' \
    --exclude='*.db-*' \
    --exclude='.HA_VERSION' \
    --exclude='known_devices.yaml' \
    --exclude='secrets.yaml' \
    "$LOCAL_CONFIG_PATH/" "$DEV_USER@$DEV_HOST:$DEV_CONFIG_PATH/"

if [[ $? -eq 0 ]]; then
    echo "✅ Configuration sync completed successfully"
else
    echo "❌ Error: Configuration sync failed"
    exit 1
fi

# Copy development-specific secrets if they exist
if [[ -f "environments/development/secrets.yaml" ]]; then
    echo "🔐 Deploying development secrets..."
    scp "environments/development/secrets.yaml" "$DEV_USER@$DEV_HOST:$DEV_CONFIG_PATH/secrets.yaml"
fi

# Restart Home Assistant in development container
echo "🔄 Restarting Home Assistant in development container..."
ssh "$DEV_USER@$DEV_HOST" "ha core restart" || {
    echo "⚠️  Warning: Restart command failed, Home Assistant may not be running"
}

# Wait for Home Assistant to come back online
echo "⏳ Waiting for Home Assistant to restart..."
sleep 30

# Verify deployment success
echo "🔍 Verifying deployment..."
if curl -f -s "http://$DEV_HOST:8123/api/" >/dev/null; then
    echo "✅ Development deployment successful!"
    echo "🌐 Access development instance at: http://$DEV_HOST:8123"
else
    echo "❌ Warning: Development instance may not be responding"
    echo "   Check logs: ssh $DEV_USER@$DEV_HOST 'ha core logs'"
fi

# Display useful information
echo ""
echo "📋 Deployment Summary"
echo "==================="
echo "✅ Target: $DEV_HOST (LXC 128)"
echo "✅ Branch: $(git branch --show-current)"
echo "✅ Commit: $(git rev-parse --short HEAD)"
echo "✅ Time: $(date)"
echo ""
echo "🔧 Next Steps:"
echo "   • Test your changes at http://$DEV_HOST:8123"
echo "   • Check logs: ssh $DEV_USER@$DEV_HOST 'ha core logs'"
echo "   • Deploy to testing: ./deploy-to-test.sh"
echo ""
echo "🚨 Rollback (if needed):"
echo "   ssh $DEV_USER@$DEV_HOST 'cp -r $BACKUP_DIR/* $DEV_CONFIG_PATH/ && ha core restart'"