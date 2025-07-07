#!/bin/bash
# ===== HOME ASSISTANT PRODUCTION DEPLOYMENT SCRIPT =====
# Purpose: Deploy validated configuration to production server (192.168.1.155)
# Target: 192.168.1.155 (production)
# Usage: ./deploy-to-prod.sh
# 
# ⚠️  CRITICAL: Only run after successful testing deployment and validation

set -e  # Exit on any error

# Configuration
PROD_HOST="192.168.1.155"
PROD_USER="root"
PROD_CONFIG_PATH="/usr/share/hassio/homeassistant"
LOCAL_CONFIG_PATH="$(pwd)"
REQUIRED_BRANCH="main"

echo "🚨 HOME ASSISTANT PRODUCTION DEPLOYMENT 🚨"
echo "==========================================="
echo "Target: $PROD_HOST (PRODUCTION)"
echo "Time: $(date)"
echo ""
echo "⚠️  WARNING: This will deploy to LIVE PRODUCTION system"
echo "⚠️  Ensure testing validation is complete before proceeding"
echo ""

# Safety confirmation
read -p "🔒 Type 'DEPLOY-TO-PRODUCTION' to confirm: " -r
if [[ "$REPLY" != "DEPLOY-TO-PRODUCTION" ]]; then
    echo "❌ Production deployment cancelled for safety"
    exit 1
fi

# Verify we're in the right directory
if [[ ! -f "configuration.yaml" ]]; then
    echo "❌ Error: Must run from Home Assistant config directory"
    exit 1
fi

# Ensure we're on the main branch
echo "🔍 Verifying deployment branch..."
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "$REQUIRED_BRANCH" ]]; then
    echo "❌ Error: Must be on '$REQUIRED_BRANCH' branch for production deployment"
    echo "   Current branch: $CURRENT_BRANCH"
    echo "   Switch with: git checkout $REQUIRED_BRANCH"
    exit 1
fi

# Verify branch is up to date and clean
echo "📡 Verifying branch status..."
git fetch origin

# Check if local is up to date with remote
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse "origin/$REQUIRED_BRANCH")
if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
    echo "❌ Error: Local branch is not up to date with remote"
    echo "   Run: git pull origin $REQUIRED_BRANCH"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: Uncommitted changes detected"
    echo "   Commit or stash changes before production deployment"
    exit 1
fi

# Verify production server is accessible
echo "🔍 Checking production server accessibility..."
if ! ping -c 1 "$PROD_HOST" &>/dev/null; then
    echo "❌ Error: Production server $PROD_HOST is not accessible"
    exit 1
fi

# Check production server health before deployment
echo "🏥 Checking production server health..."
PROD_API_STATUS=$(curl -f -s "http://$PROD_HOST:8123/api/" || echo "FAILED")
if [[ "$PROD_API_STATUS" == "FAILED" ]]; then
    echo "❌ Error: Production Home Assistant is not responding"
    echo "   Cannot deploy to unhealthy system"
    exit 1
fi

# Get current production version for rollback reference
echo "📋 Recording current production state..."
CURRENT_PROD_COMMIT=$(ssh "$PROD_USER@$PROD_HOST" "cd $PROD_CONFIG_PATH && git rev-parse --short HEAD 2>/dev/null || echo 'unknown'")
echo "   Current production commit: $CURRENT_PROD_COMMIT"

# Create full production backup
echo "💾 Creating production backup..."
BACKUP_NAME="pre-deploy-$(date +%Y%m%d_%H%M%S)"
ssh "$PROD_USER@$PROD_HOST" "ha backups new --name '$BACKUP_NAME'" || {
    echo "❌ Error: Failed to create production backup"
    echo "   Cannot proceed without backup"
    exit 1
}
echo "✅ Production backup created: $BACKUP_NAME"

# Final validation on local configuration
echo "🔍 Final configuration validation..."
if command -v hass &>/dev/null; then
    if ! hass --script check_config --config . &>/dev/null; then
        echo "❌ Error: Configuration validation failed"
        exit 1
    fi
else
    echo "⚠️  Warning: Local HA CLI not available, skipping local validation"
fi

# Deploy to production with careful sync options
echo "📤 Deploying to production server..."
echo "   This may take several minutes..."

rsync -avz \
    --exclude='.git/' \
    --exclude='deployment/' \
    --exclude='docs/' \
    --exclude='environments/development/' \
    --exclude='environments/testing/' \
    --exclude='*.log' \
    --exclude='*.db' \
    --exclude='*.db-*' \
    --exclude='.HA_VERSION' \
    --exclude='known_devices.yaml' \
    --exclude='secrets.yaml' \
    "$LOCAL_CONFIG_PATH/" "$PROD_USER@$PROD_HOST:$PROD_CONFIG_PATH/"

if [[ $? -ne 0 ]]; then
    echo "❌ Error: Production deployment sync failed"
    exit 1
fi

# Deploy production secrets
if [[ -f "environments/production/secrets.yaml" ]]; then
    echo "🔐 Deploying production secrets..."
    scp "environments/production/secrets.yaml" "$PROD_USER@$PROD_HOST:$PROD_CONFIG_PATH/secrets.yaml"
else
    echo "⚠️  Warning: No production secrets file found, keeping existing"
fi

# Validate configuration on production server
echo "🔍 Validating configuration on production server..."
if ! ssh "$PROD_USER@$PROD_HOST" "cd $PROD_CONFIG_PATH && ha core check"; then
    echo "❌ Error: Configuration validation failed on production"
    echo "🔧 Rolling back to backup..."
    ssh "$PROD_USER@$PROD_HOST" "ha backups restore $BACKUP_NAME"
    exit 1
fi

# Reload configuration (prefer reload over restart for production)
echo "🔄 Reloading production configuration..."
if ssh "$PROD_USER@$PROD_HOST" "ha core reload"; then
    echo "✅ Configuration reloaded successfully"
    RESTART_PERFORMED=false
else
    echo "⚠️  Reload failed, performing controlled restart..."
    ssh "$PROD_USER@$PROD_HOST" "ha core restart"
    RESTART_PERFORMED=true
    
    # Wait longer for restart
    echo "⏳ Waiting for production restart (90 seconds)..."
    sleep 90
fi

# Comprehensive production health check
echo "🏥 Performing comprehensive production health check..."
sleep 15  # Allow system to stabilize

# Check API response
if ! curl -f -s "http://$PROD_HOST:8123/api/" >/dev/null; then
    echo "❌ Error: Production API not responding after deployment"
    echo "🚨 CRITICAL: Rolling back immediately..."
    ssh "$PROD_USER@$PROD_HOST" "ha backups restore $BACKUP_NAME"
    exit 1
fi

# Check for critical errors
ERROR_COUNT=$(ssh "$PROD_USER@$PROD_HOST" "ha core logs | grep -i 'ERROR\|CRITICAL' | tail -100 | wc -l" || echo "0")
if [[ "$ERROR_COUNT" -gt 5 ]]; then
    echo "⚠️  Warning: Elevated error count detected ($ERROR_COUNT recent errors)"
    echo "   Monitor closely and consider rollback if issues persist"
fi

# Check automation status
AUTOMATION_COUNT=$(ssh "$PROD_USER@$PROD_HOST" "ha core info | grep -o 'automations: [0-9]*' | grep -o '[0-9]*'" || echo "unknown")
echo "📊 Production Health Status:"
echo "   • API: ✅ Responding"
echo "   • Automations: $AUTOMATION_COUNT loaded"
echo "   • Recent errors: $ERROR_COUNT"
echo "   • Restart performed: $RESTART_PERFORMED"

# Update Git tracking on production server (if Git is available)
ssh "$PROD_USER@$PROD_HOST" "cd $PROD_CONFIG_PATH && git init . && git add . && git commit -m 'Production deployment $(date)' || true" 2>/dev/null

echo ""
echo "🎉 PRODUCTION DEPLOYMENT SUCCESSFUL!"
echo "===================================="
echo "✅ Target: $PROD_HOST (PRODUCTION)"
echo "✅ Branch: $REQUIRED_BRANCH"
echo "✅ Commit: $(git rev-parse --short HEAD) - $(git log -1 --pretty=format:'%s')"
echo "✅ Previous: $CURRENT_PROD_COMMIT"
echo "✅ Backup: $BACKUP_NAME"
echo "✅ Time: $(date)"
echo ""
echo "🔍 Post-Deployment Monitoring:"
echo "   • Monitor system for 30 minutes"
echo "   • Check critical automations are working"
echo "   • Verify device integrations"
echo "   • Watch error logs: ssh $PROD_USER@$PROD_HOST 'ha core logs -f'"
echo ""
echo "📝 Final Steps:"
echo "   • Update deployment log/documentation"
echo "   • Notify team of successful deployment"
echo "   • Schedule post-deployment review"
echo ""
echo "🚨 Emergency Rollback (if needed):"
echo "   ssh $PROD_USER@$PROD_HOST 'ha backups restore $BACKUP_NAME'"
echo ""
echo "✅ Production deployment completed successfully at $(date)"