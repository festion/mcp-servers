# Home Assistant Error Troubleshooting Plan - June 7, 2025

## Critical Issues Identified

### 1. YAML Configuration Error (BLOCKING)
**Error**: "while scanning for the next token found character '\t' that cannot start any token in "/config/automations/appliances2.yaml""
**Status**: File does not exist - this appears to be a stale reference
**Impact**: Blocking all configuration reloads

### 2. Template Circular Reference (HIGH PRIORITY)
**Error**: "Template loop detected" and "unknown entity binary_sensor.night_mode_active"
**Location**: `/config/packages/zwave_led_night_mode.yaml` line 16
**Issue**: Template references itself in icon definition

### 3. Missing Entity References (MEDIUM PRIORITY)
**Error**: "unknown entity binary_sensor.night_mode_active"
**Status**: Entity exists but automation references are inconsistent

### 4. Unavailable Automation Entities (LOW PRIORITY)
**Count**: 8 unavailable automation entities
**Impact**: Failed automation count shows 8 instead of 0

## IMMEDIATE FIXES REQUIRED

### Fix 1: Resolve YAML Configuration Error
The error references "appliances2.yaml" which doesn't exist. Need to check:
1. Configuration.yaml includes
2. Any references to non-existent files
3. Possible temporary files or cache issues

### Fix 2: Fix Template Circular Reference
**File**: `Z:\packages\zwave_led_night_mode.yaml`
**Current problematic code** (around line 16):
```yaml
icon: >
  {% if is_state('binary_sensor.night_mode_active', 'on') %}
    mdi:weather-night
  {% else %}
    mdi:weather-sunny
  {% endif %}
```

**Fixed code**:
```yaml
icon: >
  {% set current_time = now().time() %}
  {% set night_start = strptime('22:00:00', '%H:%M:%S').time() %}
  {% set night_end = strptime('07:00:00', '%H:%M:%S').time() %}
  {% if current_time >= night_start or current_time < night_end %}
    mdi:weather-night
  {% else %}
    mdi:weather-sunny
  {% endif %}
```

### Fix 3: Script Service Call Error
**Error**: "Invalid data for call_service at pos 1: extra keys not allowed @ data['entity_id']"
**Location**: `script.test_appliance_announcements`
**Action**: Review and fix service call syntax

## EXECUTION PLAN

1. **Backup Current State**
   - Create backup of current configuration
   - Document current error state

2. **Apply Template Fix**
   - Edit `Z:\packages\zwave_led_night_mode.yaml`
   - Replace circular reference with direct time calculation

3. **Configuration Validation**
   - Check for any references to "appliances2.yaml"
   - Validate all automation files

4. **Reload and Test**
   - Reload YAML configuration
   - Monitor error logs
   - Verify automation count

## AUTOMATION ENTITIES TO REVIEW

### Unavailable Entities (may need cleanup):
- automation.dryer_cycle_complete_3
- automation.system_health_status_reporter_2
- automation.system_health_critical_failure_alert_2
- automation.system_health_notification_recovery_monitor_2
- automation.health_monitor_system_health_recovery_2
- automation.washing_machine_cycle_monitoring
- automation.z_wave_led_preset_handler_fixed
- automation.z_wave_led_night_mode_notifications_fixed

## VALIDATION STEPS

1. Check error log for reduction in errors
2. Verify failed automation count = 0
3. Confirm template loop errors resolved
4. Test configuration reload functionality

## EXPECTED OUTCOMES

- ✅ Configuration reloads work without errors
- ✅ Template loop errors eliminated
- ✅ Failed automation count reduced to 0
- ✅ System stability improved
- ✅ All core functionality restored

---
**Next Steps**: Apply template fix to production server at Z:\packages\zwave_led_night_mode.yaml
