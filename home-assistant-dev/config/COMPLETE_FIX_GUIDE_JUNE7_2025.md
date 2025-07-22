# COMPREHENSIVE HOME ASSISTANT ERROR FIX GUIDE
# Production Server: \\192.168.1.155\config (Z:\)
# Date: June 7, 2025

## CRITICAL ISSUES TO FIX

### 🔴 Priority 1: Template Circular Reference (BREAKING SYSTEM)
**File**: `Z:\packages\zwave_led_night_mode.yaml`
**Line**: ~16
**Error**: Template loop detected
**Fix**: Replace icon template to remove self-reference

### 🟡 Priority 2: Script Service Call Error
**File**: `Z:\scripts.yaml`
**Error**: Invalid data for call_service - extra keys not allowed
**Fix**: Update notify service calls to use correct syntax

### 🟠 Priority 3: Phantom File Reference
**Error**: appliances2.yaml not found
**Fix**: Check for stale cache/references

## EXECUTION STEPS

### Step 1: Fix Template Circular Reference
**File**: `Z:\packages\zwave_led_night_mode.yaml`

**Find this section (around line 16):**
```yaml
        icon: >
          {% if is_state('binary_sensor.night_mode_active', 'on') %}
            mdi:weather-night
          {% else %}
            mdi:weather-sunny
          {% endif %}
```

**Replace with:**
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

### Step 2: Fix Script Service Calls
**File**: `Z:\scripts.yaml`

**Find and replace these service calls:**

**In `test_appliance_announcements` script:**
```yaml
# CHANGE FROM:
    - service: notify.alexa_media
      target:
        entity_id: media_player.everywhere
      data:
        message: "Testing appliance announcement system. All devices responding."
        data:
          type: announce

# CHANGE TO:
    - service: notify.alexa_media_everywhere
      data:
        message: "Testing appliance announcement system. All devices responding."
        data:
          type: announce
```

**Apply same fix to:**
- `manual_energy_report` script
- `reload_appliance_automations` script

### Step 3: Clear Configuration Cache
1. Restart Home Assistant completely
2. Check for any `.appliances2.yaml` files in the config directory
3. Verify no temporary files exist

### Step 4: Validation
After applying fixes:

1. **Check Error Log**:
   ```
   Settings → System → Logs
   ```
   - Should see reduction in template loop errors
   - Should see reduction in service call errors

2. **Test Configuration Reload**:
   ```
   Developer Tools → YAML → Check Configuration
   Developer Tools → YAML → Restart → Quick Reload
   ```

3. **Test Scripts**:
   ```
   Developer Tools → Services
   Call: script.test_appliance_announcements
   ```

4. **Verify Automation Count**:
   - Failed automations should reduce from 8 to 0

## EXPECTED OUTCOMES

✅ **Template Errors Fixed**
- No more "Template loop detected" errors
- `binary_sensor.night_mode_active` works properly

✅ **Service Call Errors Fixed**  
- Scripts execute without errors
- Alexa announcements work

✅ **Configuration Reloads Work**
- No more "appliances2.yaml" errors
- YAML reloads complete successfully

✅ **System Stability Improved**
- Reduced error log spam
- Automation health restored

## ROLLBACK PLAN (if needed)

If issues occur:
1. Restore from backup at `C:\working\backup_june6_2025\`
2. Revert specific files that were changed
3. Restart Home Assistant

## MONITORING

After fixes, monitor for 24 hours:
- Error log should show significant reduction
- System health should improve
- All automations should function normally

---
**Total Estimated Fix Time**: 10-15 minutes
**Risk Level**: Low (non-breaking fixes)
**Testing Required**: Yes (validate each fix)
