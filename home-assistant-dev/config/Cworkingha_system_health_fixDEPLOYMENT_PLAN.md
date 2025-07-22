# System Health Dashboard Fix - Deployment Plan
# Date: June 2, 2025
# Purpose: Fix blank system health monitor dashboard

## Problem Analysis
Your system health dashboard is blank because:

1. **Sensor Name Mismatches**: Dashboard references sensors with "*_emergency_fix" names that don't exist
2. **Unavailable Sensors**: Key sensors like `sensor.system_health_percentage` are "unavailable" 
3. **Disabled Automation**: `automation.health_monitor_system_health_recovery` is turned OFF
4. **Multiple Config Files**: You have conflicting system health configurations

## Current Entity Status
- ❌ `sensor.system_health_percentage` → "unavailable"
- ❌ `binary_sensor.system_health_ok` → "unavailable" 
- ❌ Multiple health sensors → "unavailable"
- ❌ `automation.health_monitor_system_health_recovery` → OFF

## Solution Overview
Replace current `packages/system_health.yaml` with unified configuration that:
- ✅ Creates all sensors referenced by dashboard
- ✅ Uses robust template logic with error handling
- ✅ Enables proper automation recovery mechanisms
- ✅ Provides detailed system health monitoring

## Deployment Steps

### Step 1: Backup Current Configuration
```bash
# Backup current system health files
cp /config/packages/system_health.yaml /config/packages/system_health_BACKUP_$(date +%Y%m%d_%H%M%S).yaml
cp /config/dashboards/system_health_dashboard.yaml /config/dashboards/system_health_dashboard_BACKUP_$(date +%Y%m%d_%H%M%S).yaml
```

### Step 2: Deploy New System Health Package
- Replace `/config/packages/system_health.yaml` with `unified_system_health.yaml`
- This creates all required sensors with proper "*_emergency_fix" naming

### Step 3: Deploy New Dashboard
- Replace `/config/dashboards/system_health_dashboard.yaml` with `unified_system_health_dashboard.yaml`
- This matches the sensor names created in Step 2

### Step 4: Restart and Validate
```bash
# Check configuration validity
ha config check

# Restart Home Assistant
ha core restart

# Wait 2 minutes, then check:
# - All new sensors appear and have values
# - Dashboard displays data properly
# - Automations are enabled and working
```

## Expected Results After Deployment

### New Sensors Created:
- `sensor.integration_health_status_emergency_fix` → Text status (Excellent/Good/Fair/Poor/Critical)
- `sensor.integration_health_percentage_fixed` → Numeric percentage for automations
- `sensor.alexa_integration_health_emergency_fix` → Alexa integration health %
- `sensor.mobile_app_integration_health_emergency_fix` → Mobile app health %
- `sensor.switch_integration_health_emergency_fix` → Switch integration health %
- `sensor.unavailable_entities_emergency_fix` → Count of unavailable entities
- `sensor.failed_automations_count_emergency_fix` → Count of failed automations
- `binary_sensor.system_health_ok_emergency_fix` → Overall health status

### Dashboard Features:
- ✅ Real-time health metrics display
- ✅ Integration-specific health monitoring
- ✅ Visual gauges for health percentages
- ✅ Action buttons for manual refresh/recovery
- ✅ Detailed status information in markdown
- ✅ Conditional alerts for current issues

### Automation Features:
- ✅ Hourly health status logging
- ✅ Automatic recovery attempts when health drops
- ✅ Critical failure notifications
- ✅ Notification system recovery monitoring

## Rollback Plan (if needed)
If issues occur:
```bash
# Restore original files
cp /config/packages/system_health_BACKUP_*.yaml /config/packages/system_health.yaml
cp /config/dashboards/system_health_dashboard_BACKUP_*.yaml /config/dashboards/system_health_dashboard.yaml

# Restart Home Assistant
ha core restart
```

## Validation Checklist
After deployment, verify:
- [ ] Dashboard loads without errors
- [ ] All sensors show values (not "unavailable")
- [ ] Health percentage displays correctly
- [ ] Integration health metrics appear
- [ ] Action buttons work
- [ ] Automations are enabled
- [ ] No configuration errors in logs

## Files to Deploy:
1. `unified_system_health.yaml` → `/config/packages/system_health.yaml`
2. `unified_system_health_dashboard.yaml` → `/config/dashboards/system_health_dashboard.yaml`

This solution provides comprehensive system health monitoring with proper error handling and dashboard compatibility.
