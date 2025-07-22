#!/bin/bash

# Deploy appliance notification fixes to production Home Assistant
# Target: \\192.168.1.155 via SMB/CIFS

set -e

echo "🚀 Deploying appliance notification fixes to production..."

# Configuration
PRODUCTION_HOST="192.168.1.155"
SHARE_PATH="//192.168.1.155/config"
MOUNT_POINT="/tmp/ha_mount_$$"
USERNAME="homeassistant"
PASSWORD="reedflower805"

# Create temporary mount point
mkdir -p "$MOUNT_POINT"

# Mount the Home Assistant config share
echo "📁 Mounting Home Assistant config share..."
mount -t cifs "$SHARE_PATH" "$MOUNT_POINT" \
    -o username="$USERNAME",password="$PASSWORD",vers=3.0,uid=$(id -u),gid=$(id -g)

if [ $? -eq 0 ]; then
    echo "✅ Successfully mounted $SHARE_PATH"
    
    # Create backup of current automations
    BACKUP_DIR="$MOUNT_POINT/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR/automations"
    
    echo "📦 Creating backup of current automations..."
    cp "$MOUNT_POINT/automations/appliances.yaml" "$BACKUP_DIR/automations/" 2>/dev/null || true
    cp "$MOUNT_POINT/automations/appliance.yaml" "$BACKUP_DIR/automations/" 2>/dev/null || true
    
    # Deploy the updated files
    echo "🔄 Deploying updated automation files..."
    cp "automations/appliances.yaml" "$MOUNT_POINT/automations/"
    cp "automations/appliance.yaml" "$MOUNT_POINT/automations/"
    
    echo "✅ Files deployed successfully!"
    echo "📋 Backup created at: $BACKUP_DIR"
    
    # Unmount
    umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT"
    
    echo ""
    echo "🎉 Deployment complete!"
    echo "📌 Next steps:"
    echo "   1. Go to Home Assistant > Developer Tools > YAML"
    echo "   2. Click 'Check Configuration'"
    echo "   3. If valid, click 'Restart' or reload automations"
    echo "   4. Test the washing machine and dishwasher notifications"
    echo ""
    echo "🔧 Changes deployed:"
    echo "   • Fixed '-297 minutes' bug in notifications"
    echo "   • Enhanced washing machine logic with dryer coordination"
    echo "   • Disabled dishwasher reminders (kept completion announcements)"
    
else
    echo "❌ Failed to mount Home Assistant config share"
    rmdir "$MOUNT_POINT"
    exit 1
fi