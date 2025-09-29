# BLE Garage Door Package Troubleshooting - Complete Investigation

## Problem Summary
User reported "4 Invalid" MAC validation despite having only one MAC configured, and MAC addresses not persisting when entered via dashboard.

## Root Cause Analysis

### Issues Identified and Resolved ✅

1. **Duplicate Template Sensors**
   - Found duplicate `sensor.ble_mac_address_validation_status` in entity registry
   - Same unique_id caused conflicts and state issues
   - **Fix**: Changed unique_id to `ble_mac_validation_status_v2` in packages/ble_garage_door.yaml:380

2. **Gateway Validation Logic Flawed**
   - Gateway validation only checked if `sensor.ble_gateway_raw_data` existed
   - Showed "connected" even when pointing to wrong device (weather station at .82)
   - **Fix**: Updated templates.yaml:141-170 to check actual JSON payload structure:
   ```yaml
   state: >
     {% if states('sensor.ble_gateway_raw_data') not in ['unavailable', 'unknown'] %}
       {% set gateway_data = state_attr('sensor.ble_gateway_raw_data', 'devices') %}
       {% set gateway_time = state_attr('sensor.ble_gateway_raw_data', 'time') %}
       {% if gateway_data is not none and gateway_time is not none and gateway_data is iterable %}
         online
       {% else %}
         offline
       {% endif %}
     {% else %}
       offline
     {% endif %}
   ```

3. **MAC Validation Counting Logic**
   - Logic counted all 4 MAC slots regardless of whether they contained data
   - **Fix**: Updated packages/ble_garage_door.yaml:390-408 to count only non-empty MACs:
   ```yaml
   {% set non_empty_macs = [] %}
   {% for mac in all_macs %}
     {% if mac and mac != '' and mac != 'unknown' and mac != 'unavailable' %}
       {% set non_empty_macs = non_empty_macs + [mac] %}
     {% endif %}
   {% endfor %}
   ```

4. **Gateway IP Configuration**
   - Gateway IP was incorrect: 192.168.1.82 (weather station) instead of 192.168.1.46
   - **Fix**: Updated gateway IP to 192.168.1.46

5. **Invalid Configuration Options**
   - `restore: true` option on input_text entities caused warnings
   - **Fix**: Removed invalid restore options

### Remaining Critical Issue ❌

**MAC Address Persistence Problem**
- All `input_text` entities for MAC addresses show `"editable":false` in core.restore_state
- This occurs despite explicitly setting `editable: true` in configuration
- Prevents users from entering MAC addresses via dashboard
- MAC values don't persist across Home Assistant restarts

**Evidence**:
```yaml
# Configuration shows:
ble_driveway_car_1_mac:
  editable: true
  
# Runtime state shows:
"attributes":{"editable":false, ...}
```

## Technical Details

### File Locations
- **Main Package**: `/home/dev/workspace/home-assistant-config/packages/ble_garage_door.yaml`
- **Templates**: `/home/dev/workspace/home-assistant-config/templates.yaml` 
- **Dashboard**: `/home/dev/workspace/home-assistant-config/dashboards/ble_garage_door_dashboard.yaml`

### Entity Registry Issues
- Multiple sensors with same unique_id caused conflicts
- `sensor.ble_mac_address_validation_status` (original)
- `sensor.ble_mac_address_validation_status_2` (duplicate)
- **Current**: `sensor.ble_mac_address_validation_status_v2` (fixed)

### Template Sensor Logic
Current diagnostic template in packages/ble_garage_door.yaml:381-409:
```yaml
state: >
  {% if states('input_text.ble_driveway_car_1_mac') == 'unknown' %}
    Input entities not loaded
  {% else %}
    # MAC validation logic
  {% endif %}
```

## Investigation Methods Used

1. **SSH Access to Production System** (192.168.1.155)
2. **Entity Registry Analysis** (/config/.storage/core.entity_registry)
3. **State Persistence Check** (/config/.storage/core.restore_state)
4. **Configuration Validation** (ha core check)
5. **Log Analysis** (/config/home-assistant.log)
6. **Manual State Modification** (Python JSON manipulation)

## Current Status

### Working Components ✅
- BLE gateway detection and JSON payload validation
- Template sensor creation and unique ID resolution
- Configuration syntax validation
- Git CI/CD pipeline integration

### Non-Working Components ❌
- MAC address input via dashboard (entities not editable)
- MAC address persistence across restarts
- User configuration workflow

## Next Steps Required

1. **Investigate Input Text Editability**:
   - Check if packages system affects input_text editable property
   - Test creating input_text entities outside packages
   - Review Home Assistant documentation for package limitations

2. **Alternative Solutions**:
   - Consider using input helpers created through UI instead of YAML
   - Implement custom storage mechanism for MAC addresses
   - Use automation to handle MAC address persistence

3. **System Configuration Review**:
   - Check global Home Assistant settings affecting input_text
   - Review package loading order and dependencies
   - Investigate if other packages have similar issues

## Commits Made
- `793f8f4b`: Added diagnostic check for input_text entity loading
- `ae3040ec`: Changed unique_id to avoid duplicate sensor conflicts  
- `462892ff`: Explicitly set editable: true for all input_text MAC entities

## User Feedback Timeline
1. "still shows 4 invalid" → Fixed counting logic
2. "gateway IP is wrong" → Fixed IP and validation logic
3. "still unavailable and the mac did not persist" → Identified root cause

The investigation revealed multiple systemic issues with the BLE garage door configuration, most of which have been resolved. The remaining MAC address persistence issue appears to be related to Home Assistant's handling of input_text entities within packages.