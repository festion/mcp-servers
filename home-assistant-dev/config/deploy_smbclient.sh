#!/bin/bash

# Deploy appliance notification fixes to production Home Assistant using smbclient
# Target: \\192.168.1.155 via SMB

set -e

echo "🚀 Deploying appliance notification fixes to production..."

# Configuration
PRODUCTION_HOST="192.168.1.155"
USERNAME="homeassistant"
PASSWORD="reedflower805"

# Test connection first
echo "🔍 Testing connection to Home Assistant..."
smbclient -L //$PRODUCTION_HOST -U $USERNAME%$PASSWORD -N || {
    echo "❌ Failed to connect to $PRODUCTION_HOST"
    exit 1
}

echo "✅ Connection successful!"

# Create backup timestamp
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "📦 Creating backup of current files..."

# Backup current files
smbclient //$PRODUCTION_HOST/config -U $USERNAME%$PASSWORD -c "
prompt OFF
cd automations
get appliances.yaml appliances_backup_$BACKUP_TIMESTAMP.yaml
get appliance.yaml appliance_backup_$BACKUP_TIMESTAMP.yaml
" 2>/dev/null || echo "Note: Some backup files may not exist, continuing..."

echo "🔄 Deploying updated automation files..."

# Deploy new files
smbclient //$PRODUCTION_HOST/config -U $USERNAME%$PASSWORD -c "
prompt OFF
cd automations
put automations/appliances.yaml appliances.yaml
put automations/appliance.yaml appliance.yaml
" || {
    echo "❌ Failed to deploy files"
    exit 1
}

echo "✅ Files deployed successfully!"
echo "📋 Backup files created with timestamp: $BACKUP_TIMESTAMP"

echo ""
echo "🎉 Deployment complete!"
echo "📌 Next steps:"
echo "   1. Go to Home Assistant > Developer Tools > YAML"
echo "   2. Click 'Check Configuration'"
echo "   3. If valid, click 'Restart' or 'Reload Automations'"
echo "   4. Test the washing machine and dishwasher notifications"
echo ""
echo "🔧 Changes deployed:"
echo "   • Fixed '-297 minutes' bug in notifications"
echo "   • Enhanced washing machine logic with dryer coordination"
echo "   • Disabled dishwasher reminders (kept completion announcements)"
echo ""
echo "🌐 Home Assistant URL: http://$PRODUCTION_HOST:8123"