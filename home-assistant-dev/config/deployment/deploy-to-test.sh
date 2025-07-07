#!/bin/bash
# ===== HOME ASSISTANT TESTING DEPLOYMENT SCRIPT =====
# Purpose: Deploy configuration changes to testing LXC container (129)
# Target: 192.168.1.129 (ha-test-129)
# Usage: ./deploy-to-test.sh [branch-name]

set -e  # Exit on any error

# Configuration
TEST_HOST="192.168.1.129"
TEST_USER="root"
TEST_CONFIG_PATH="/usr/share/hassio/homeassistant"
LOCAL_CONFIG_PATH="$(pwd)"
BRANCH_NAME="${1:-main}"

echo "🧪 Home Assistant Testing Deployment"
echo "⚠️  WARNING: LXC 129 container must be created first!"
echo "===================================="
echo "Target: $TEST_HOST (LXC 129)"
echo "Branch: $BRANCH_NAME"
echo "Time: $(date)"
echo ""

# Verify we're in the right directory
if [[ ! -f "configuration.yaml" ]]; then
    echo "❌ Error: Must run from Home Assistant config directory"
    echo "   Expected to find configuration.yaml in current directory"
    exit 1
fi

# Check if testing container is accessible
echo "🔍 Checking testing container accessibility..."
if ! ping -c 1 "$TEST_HOST" &>/dev/null; then
    echo "❌ Error: Testing container $TEST_HOST is not accessible"
    echo "   Please ensure LXC 129 is running and network is configured"
    exit 1
fi

# Ensure we're on the correct branch (usually main for testing)
echo "🔄 Switching to branch: $BRANCH_NAME"
if ! git checkout "$BRANCH_NAME" 2>/dev/null; then
    echo "❌ Error: Branch $BRANCH_NAME doesn't exist"
    echo "   Available branches:"
    git branch -a
    exit 1
fi

# Verify branch is up to date
echo "📡 Checking if branch is up to date..."
git fetch origin
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse "origin/$BRANCH_NAME")

if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
    echo "⚠️  Warning: Local branch is not up to date with remote"
    echo "   Local:  $LOCAL_COMMIT"
    echo "   Remote: $REMOTE_COMMIT"
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled. Please pull latest changes first."
        exit 1
    fi
fi

# Enhanced configuration validation
echo "🔍 Performing comprehensive configuration validation..."

# Check for common issues
echo "  • Checking for required files..."
REQUIRED_FILES=("configuration.yaml" "automations.yaml" "scripts.yaml")
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Error: Required file missing: $file"
        exit 1
    fi
done

# Validate YAML syntax
echo "  • Validating YAML syntax..."
find . -name "*.yaml" -not -path "./.git/*" | while read -r file; do
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        echo "❌ Error: YAML syntax error in $file"
        exit 1
    fi
done

# Check for secrets references
echo "  • Checking secrets references..."
if grep -r "!secret" . --include="*.yaml" | grep -v "secrets.yaml" >/dev/null; then
    if [[ ! -f "environments/testing/secrets.yaml" ]]; then
        echo "❌ Error: Configuration references secrets but no testing secrets file found"
        echo "   Expected: environments/testing/secrets.yaml"
        exit 1
    fi
fi

echo "✅ Configuration validation passed"

# Create snapshot of current testing environment
echo "📸 Creating snapshot of current testing environment..."
SNAPSHOT_NAME="pre-deploy-$(date +%Y%m%d_%H%M%S)"
ssh "$TEST_USER@$TEST_HOST" "ha backups new --name '$SNAPSHOT_NAME'" || {
    echo "⚠️  Warning: Snapshot creation failed, continuing anyway"
}

# Sync configuration to testing container
echo "📤 Syncing configuration to testing container..."
rsync -avz --delete \
    --exclude='.git/' \
    --exclude='deployment/' \
    --exclude='docs/' \
    --exclude='environments/development/' \
    --exclude='environments/production/' \
    --exclude='*.log' \
    --exclude='*.db' \
    --exclude='*.db-*' \
    --exclude='.HA_VERSION' \
    --exclude='known_devices.yaml' \
    "$LOCAL_CONFIG_PATH/" "$TEST_USER@$TEST_HOST:$TEST_CONFIG_PATH/"

if [[ $? -eq 0 ]]; then
    echo "✅ Configuration sync completed successfully"
else
    echo "❌ Error: Configuration sync failed"
    exit 1
fi

# Deploy testing-specific secrets
if [[ -f "environments/testing/secrets.yaml" ]]; then
    echo "🔐 Deploying testing secrets..."
    scp "environments/testing/secrets.yaml" "$TEST_USER@$TEST_HOST:$TEST_CONFIG_PATH/secrets.yaml"
else
    echo "⚠️  Warning: No testing secrets file found, using existing secrets"
fi

# Validate configuration on testing container
echo "🔍 Validating configuration on testing container..."
ssh "$TEST_USER@$TEST_HOST" "ha core check" || {
    echo "❌ Error: Configuration validation failed on testing container"
    echo "🔧 Attempting to restore from snapshot..."
    ssh "$TEST_USER@$TEST_HOST" "ha backups restore $SNAPSHOT_NAME"
    exit 1
}

# Reload configuration (try reload first, restart if needed)
echo "🔄 Reloading Home Assistant configuration..."
if ssh "$TEST_USER@$TEST_HOST" "ha core reload"; then
    echo "✅ Configuration reloaded successfully"
else
    echo "⚠️  Reload failed, attempting full restart..."
    ssh "$TEST_USER@$TEST_HOST" "ha core restart"
    
    # Wait for restart
    echo "⏳ Waiting for Home Assistant to restart..."
    sleep 45
fi

# Comprehensive health check
echo "🏥 Performing health check..."
sleep 10  # Allow services to stabilize

# Check if Home Assistant API is responding
if ! curl -f -s "http://$TEST_HOST:8123/api/" >/dev/null; then
    echo "❌ Error: Home Assistant API not responding"
    echo "🔧 Attempting to restore from snapshot..."
    ssh "$TEST_USER@$TEST_HOST" "ha backups restore $SNAPSHOT_NAME"
    exit 1
fi

# Check for critical errors in logs
echo "📊 Checking for critical errors..."
ERROR_COUNT=$(ssh "$TEST_USER@$TEST_HOST" "ha core logs | grep -i 'ERROR\|CRITICAL' | wc -l" || echo "0")
if [[ "$ERROR_COUNT" -gt 10 ]]; then
    echo "⚠️  Warning: High error count detected ($ERROR_COUNT errors)"
    echo "   Review logs: ssh $TEST_USER@$TEST_HOST 'ha core logs'"
fi

# Test automation loading
echo "🤖 Checking automation status..."
AUTOMATION_STATUS=$(ssh "$TEST_USER@$TEST_HOST" "ha core info | grep -o 'automations: [0-9]*'" || echo "automations: unknown")
echo "   $AUTOMATION_STATUS"

echo "✅ Testing deployment successful!"

# Display comprehensive summary
echo ""
echo "📋 Testing Deployment Summary"
echo "============================"
echo "✅ Target: $TEST_HOST (LXC 129)"
echo "✅ Branch: $(git branch --show-current)"
echo "✅ Commit: $(git rev-parse --short HEAD) - $(git log -1 --pretty=format:'%s')"
echo "✅ Time: $(date)"
echo "✅ Snapshot: $SNAPSHOT_NAME"
echo "✅ Errors: $ERROR_COUNT"
echo ""
echo "🧪 Testing Checklist:"
echo "   • Access testing instance: http://$TEST_HOST:8123"
echo "   • Verify all automations are working"
echo "   • Test critical device integrations"
echo "   • Check dashboard functionality"
echo "   • Monitor error logs for 24 hours"
echo ""
echo "🚀 Ready for Production:"
echo "   ./deploy-to-prod.sh"
echo ""
echo "🚨 Rollback (if needed):"
echo "   ssh $TEST_USER@$TEST_HOST 'ha backups restore $SNAPSHOT_NAME'"