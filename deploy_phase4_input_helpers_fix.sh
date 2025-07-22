#!/bin/bash

# ============================================================================
# ADAPTIVE LIGHTING PHASE 4: MISSING INPUT HELPERS DEPLOYMENT
# ============================================================================
# Deploys the missing input helpers to fix the 13 failed automations
# in production Home Assistant after the July 3, 2025 restart.
#
# This script safely deploys the missing input helper entities that the
# Phase 4 automations require to function properly.
# ============================================================================

set -euo pipefail

# Configuration
PRODUCTION_URL="http://192.168.1.155:8123"
PRODUCTION_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiOTJkNDM5Yjg2OTU0YWFmOTAwZmVhZmMyMmI1NjlhNCIsImlhdCI6MTc1MTQ5NjEyMiwiZXhwIjoyMDY2ODU2MTIyfQ.VnAswhqcZsIR4grBirx2IjdI3bvxCC2A0fKwVv4OXkQ"
LOCAL_CONFIG_DIR="/home/dev/workspace/home-assistant-config"
MISSING_HELPERS_FILE="packages/phase4_missing_input_helpers.yaml"
BACKUP_DIR="backup_phase4_fix_$(date +%Y%m%d_%H%M%S)"

echo "============================================================================"
echo "🔧 ADAPTIVE LIGHTING PHASE 4: MISSING INPUT HELPERS DEPLOYMENT"
echo "============================================================================"
echo "Production URL: $PRODUCTION_URL"
echo "Deployment Time: $(date)"
echo "Missing Helpers File: $MISSING_HELPERS_FILE"
echo ""

# Step 1: Verify production connectivity
echo "🔍 Step 1: Verifying production Home Assistant connectivity..."
if curl -s -f -H "Authorization: Bearer $PRODUCTION_TOKEN" "$PRODUCTION_URL/api/" > /dev/null; then
    echo "✅ Production Home Assistant is accessible"
else
    echo "❌ Cannot connect to production Home Assistant"
    echo "   Please check network connectivity and token validity"
    exit 1
fi

# Step 2: Validate missing helpers file
echo ""
echo "📋 Step 2: Validating missing input helpers file..."
if [ ! -f "$LOCAL_CONFIG_DIR/$MISSING_HELPERS_FILE" ]; then
    echo "❌ Missing helpers file not found: $LOCAL_CONFIG_DIR/$MISSING_HELPERS_FILE"
    exit 1
fi

echo "✅ Missing helpers file found and readable"

# Step 3: Check YAML syntax
echo ""
echo "🔍 Step 3: Validating YAML syntax..."
if python3 -c "import yaml; yaml.safe_load(open('$LOCAL_CONFIG_DIR/$MISSING_HELPERS_FILE'))" 2>/dev/null; then
    echo "✅ YAML syntax is valid"
else
    echo "❌ YAML syntax error detected"
    echo "   Please check the YAML file for syntax errors"
    exit 1
fi

# Step 4: Check current automation status
echo ""
echo "📊 Step 4: Checking current automation status..."
UNAVAILABLE_COUNT=$(curl -s -H "Authorization: Bearer $PRODUCTION_TOKEN" "$PRODUCTION_URL/api/states" | \
    python3 -c "
import sys, json
states = json.load(sys.stdin)
automations = [s for s in states if s['entity_id'].startswith('automation.adaptive_lighting_')]
unavailable = [a for a in automations if a['state'] == 'unavailable']
print(len(unavailable))
")

echo "📈 Current unavailable adaptive lighting automations: $UNAVAILABLE_COUNT"

if [ "$UNAVAILABLE_COUNT" -eq "0" ]; then
    echo "⚠️ No unavailable automations found. Deployment may not be necessary."
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled by user."
        exit 0
    fi
fi

# Step 5: Create backup
echo ""
echo "💾 Step 5: Creating configuration backup..."
mkdir -p "$LOCAL_CONFIG_DIR/$BACKUP_DIR"

# Backup current packages directory
if [ -d "$LOCAL_CONFIG_DIR/packages" ]; then
    cp -r "$LOCAL_CONFIG_DIR/packages" "$LOCAL_CONFIG_DIR/$BACKUP_DIR/"
    echo "✅ Configuration backup created: $BACKUP_DIR"
else
    echo "⚠️ No packages directory found to backup"
fi

# Step 6: Show deployment plan
echo ""
echo "📝 Step 6: Deployment Plan"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Will deploy the following missing input helpers:"
echo ""

# Parse and show the input helpers being deployed
python3 -c "
import yaml
with open('$LOCAL_CONFIG_DIR/$MISSING_HELPERS_FILE') as f:
    config = yaml.safe_load(f)

for category in ['input_boolean', 'input_button', 'input_text', 'input_datetime']:
    if category in config:
        print(f'{category.upper()}:')
        for entity, props in config[category].items():
            name = props.get('name', entity)
            print(f'  • {entity}: {name}')
        print()
"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 7: Confirmation
echo ""
read -p "🚀 Ready to deploy missing input helpers? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled by user."
    exit 0
fi

# Step 8: Deploy to production
echo ""
echo "🚀 Step 8: Deploying missing input helpers to production..."

# Copy the missing helpers file to production config (this step would be done via file sync in real environment)
# For now, we'll show the manual steps needed

echo "📋 MANUAL DEPLOYMENT STEPS REQUIRED:"
echo ""
echo "1. Copy the following file to production Home Assistant:"
echo "   Source: $LOCAL_CONFIG_DIR/$MISSING_HELPERS_FILE"
echo "   Destination: /config/packages/phase4_missing_input_helpers.yaml"
echo ""
echo "2. Restart Home Assistant to load the new input helpers"
echo ""
echo "3. Verify that automations become available"

# Step 9: Configuration validation command
echo ""
echo "🔍 Step 9: Configuration validation command"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "To validate the configuration before restart, run:"
echo ""
echo "curl -X POST -H \"Authorization: Bearer $PRODUCTION_TOKEN\" \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     \"$PRODUCTION_URL/api/config/core/check_config\""
echo ""

# Step 10: Verification script
echo "🔍 Step 10: Post-deployment verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "After deployment and restart, verify automation status with:"
echo ""
echo "python3 -c \""
echo "import requests, json"
echo "headers = {'Authorization': 'Bearer $PRODUCTION_TOKEN'}"
echo "response = requests.get('$PRODUCTION_URL/api/states', headers=headers)"
echo "states = response.json()"
echo "automations = [s for s in states if s['entity_id'].startswith('automation.adaptive_lighting_')]"
echo "unavailable = [a for a in automations if a['state'] == 'unavailable']"
echo "print(f'Unavailable automations: {len(unavailable)}')\"" 
echo ""

# Step 11: Rollback information
echo "🔄 Step 11: Rollback Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "If issues occur, rollback by:"
echo "1. Remove: /config/packages/phase4_missing_input_helpers.yaml"
echo "2. Restart Home Assistant"
echo "3. Restore from backup: $BACKUP_DIR"
echo ""

echo "✅ DEPLOYMENT PREPARATION COMPLETE"
echo ""
echo "📋 NEXT STEPS:"
echo "1. Manually copy the input helpers file to production"
echo "2. Restart Home Assistant"
echo "3. Verify automation status"
echo ""
echo "============================================================================"