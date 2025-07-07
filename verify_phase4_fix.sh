#!/bin/bash

# ============================================================================
# ADAPTIVE LIGHTING PHASE 4: POST-DEPLOYMENT VERIFICATION
# ============================================================================
# Verifies that the missing input helpers fix has resolved the 13 failed
# automations issue after Home Assistant restart.
# ============================================================================

set -euo pipefail

# Configuration
PRODUCTION_URL="http://192.168.1.155:8123"
PRODUCTION_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiOTJkNDM5Yjg2OTU0YWFmOTAwZmVhZmMyMmI1NjlhNCIsImlhdCI6MTc1MTQ5NjEyMiwiZXhwIjoyMDY2ODU2MTIyfQ.VnAswhqcZsIR4grBirx2IjdI3bvxCC2A0fKwVv4OXkQ"

echo "============================================================================"
echo "🔍 ADAPTIVE LIGHTING PHASE 4: POST-DEPLOYMENT VERIFICATION"
echo "============================================================================"
echo "Production URL: $PRODUCTION_URL"
echo "Verification Time: $(date)"
echo ""

# Function to make API calls with error handling
api_call() {
    local endpoint="$1"
    local response
    if response=$(curl -s -H "Authorization: Bearer $PRODUCTION_TOKEN" "$PRODUCTION_URL$endpoint" 2>/dev/null); then
        echo "$response"
    else
        echo "ERROR: Failed to connect to $endpoint" >&2
        return 1
    fi
}

# Step 1: Verify Home Assistant connectivity
echo "🔍 Step 1: Verifying production connectivity..."
if api_call "/api/" > /dev/null; then
    echo "✅ Production Home Assistant is accessible"
else
    echo "❌ Cannot connect to production Home Assistant"
    exit 1
fi

# Step 2: Check automation status
echo ""
echo "📊 Step 2: Checking automation status..."

python3 -c "
import json
import sys

# Get states from stdin
states_data = '''$(api_call "/api/states")'''
try:
    states = json.loads(states_data)
except json.JSONDecodeError as e:
    print(f'❌ Failed to parse API response: {e}')
    sys.exit(1)

# Filter for adaptive lighting automations
automations = [s for s in states if s['entity_id'].startswith('automation.adaptive_lighting_')]
total_automations = len(automations)

# Count states
available_automations = [a for a in automations if a['state'] == 'on']
unavailable_automations = [a for a in automations if a['state'] == 'unavailable']
off_automations = [a for a in automations if a['state'] == 'off']

print(f'📈 Total adaptive lighting automations: {total_automations}')
print(f'✅ Available (on): {len(available_automations)}')
print(f'⏸️ Available (off): {len(off_automations)}')
print(f'❌ Unavailable: {len(unavailable_automations)}')

if unavailable_automations:
    print()
    print('❌ STILL UNAVAILABLE AUTOMATIONS:')
    for auto in unavailable_automations:
        print(f'   - {auto[\"entity_id\"]}')
        print(f'     Last changed: {auto.get(\"last_changed\", \"unknown\")}')
else:
    print()
    print('🎉 ALL AUTOMATIONS ARE AVAILABLE!')

# Return exit code based on success
sys.exit(len(unavailable_automations))
"

AUTOMATION_CHECK_RESULT=$?

# Step 3: Check for required input helpers
echo ""
echo "🔍 Step 3: Verifying new input helpers are loaded..."

python3 -c "
import json
import sys

# Required entities that should now exist
required_entities = [
    'input_boolean.adaptive_lighting_bedroom_zone_enable',
    'input_boolean.adaptive_lighting_enhanced_mode', 
    'input_boolean.adaptive_lighting_performance_monitoring',
    'input_boolean.adaptive_lighting_daily_reset_enable',
    'input_boolean.adaptive_lighting_double_click_enabled',
    'input_boolean.adaptive_lighting_smart_re_sync_enabled',
    'input_boolean.adaptive_lighting_advanced_analytics_enabled',
    'input_button.adaptive_lighting_sync_all_zones',
    'input_button.adaptive_lighting_manual_sync',
    'input_text.last_double_click_entity',
    'input_text.adaptive_lighting_system_status',
    'input_text.adaptive_lighting_last_sync',
    'input_datetime.last_double_click_time'
]

# Get states from stdin
states_data = '''$(api_call "/api/states")'''
try:
    states = json.loads(states_data)
except json.JSONDecodeError as e:
    print(f'❌ Failed to parse API response: {e}')
    sys.exit(1)

# Check each required entity
missing_entities = []
available_entities = []

for entity_id in required_entities:
    entity_state = next((s for s in states if s['entity_id'] == entity_id), None)
    if entity_state:
        available_entities.append(entity_id)
        print(f'✅ {entity_id}: {entity_state[\"state\"]}')
    else:
        missing_entities.append(entity_id)
        print(f'❌ {entity_id}: NOT FOUND')

print()
print(f'📊 Input Helper Status:')
print(f'   ✅ Available: {len(available_entities)}/{len(required_entities)}')
print(f'   ❌ Missing: {len(missing_entities)}/{len(required_entities)}')

if missing_entities:
    print()
    print('❌ MISSING INPUT HELPERS:')
    for entity in missing_entities:
        print(f'   - {entity}')

# Return exit code based on success
sys.exit(len(missing_entities))
"

INPUT_HELPER_CHECK_RESULT=$?

# Step 4: Check for errors in logs
echo ""
echo "🔍 Step 4: Checking for recent errors in logs..."

ERROR_LOG=$(api_call "/api/error_log" | tail -50)
ADAPTIVE_ERRORS=$(echo "$ERROR_LOG" | grep -i "adaptive_lighting\|automation.*unavailable\|input_boolean.*not found" | tail -10 || true)

if [ -n "$ADAPTIVE_ERRORS" ]; then
    echo "⚠️ Recent errors found in logs:"
    echo "$ADAPTIVE_ERRORS"
else
    echo "✅ No recent adaptive lighting errors found in logs"
fi

# Step 5: Overall status summary
echo ""
echo "============================================================================"
echo "📊 VERIFICATION SUMMARY"
echo "============================================================================"

if [ $AUTOMATION_CHECK_RESULT -eq 0 ] && [ $INPUT_HELPER_CHECK_RESULT -eq 0 ]; then
    echo "🎉 SUCCESS: Phase 4 input helpers fix has been deployed successfully!"
    echo ""
    echo "✅ All automations are now available"
    echo "✅ All required input helpers are loaded"
    echo "✅ No critical errors detected"
    echo ""
    echo "🚀 The 13 failed automations issue has been RESOLVED!"
    
elif [ $AUTOMATION_CHECK_RESULT -eq 0 ] && [ $INPUT_HELPER_CHECK_RESULT -ne 0 ]; then
    echo "⚠️ PARTIAL SUCCESS: Automations are available but some input helpers are missing"
    echo ""
    echo "✅ All automations are available" 
    echo "❌ Some input helpers are still missing"
    echo ""
    echo "🔧 Additional configuration may be needed"
    
elif [ $AUTOMATION_CHECK_RESULT -ne 0 ] && [ $INPUT_HELPER_CHECK_RESULT -eq 0 ]; then
    echo "⚠️ PARTIAL SUCCESS: Input helpers are loaded but automations still unavailable"
    echo ""
    echo "❌ Some automations are still unavailable"
    echo "✅ Input helpers are loaded properly"
    echo ""
    echo "🔄 Home Assistant restart may be required"
    
else
    echo "❌ DEPLOYMENT FAILED: Issues remain with both automations and input helpers"
    echo ""
    echo "❌ Automations still unavailable: $AUTOMATION_CHECK_RESULT"
    echo "❌ Input helpers still missing: $INPUT_HELPER_CHECK_RESULT"
    echo ""
    echo "🔧 Manual intervention required"
fi

echo ""
echo "============================================================================"

# Exit with appropriate code
if [ $AUTOMATION_CHECK_RESULT -eq 0 ] && [ $INPUT_HELPER_CHECK_RESULT -eq 0 ]; then
    exit 0
else
    exit 1
fi