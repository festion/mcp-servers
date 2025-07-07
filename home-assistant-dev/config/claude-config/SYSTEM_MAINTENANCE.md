# System Maintenance Documentation

## Overview
Home Assistant includes several automated system maintenance processes to keep the system running smoothly. These automations handle database optimization, Z-Wave connectivity checks, entity registry verification, and other system health monitoring.

## Z-Wave JS Connectivity Check

### Automation Details
- **ID**: `zwave_js_startup_check`
- **File**: `/config/automations/system_maintenance.yaml`
- **Purpose**: Ensures Z-Wave JS is properly connected

### Triggers
1. Home Assistant startup (with 3-minute delay)
2. Every 4 hours
3. Manual trigger via event `check_zwave_js`

### Actions
The automation calls `shell_command.check_zwave_js`, which executes a check script and logs the results to `/config/logs/zwave_js_check.log`.

### Manual Check
To manually trigger the Z-Wave JS check:
```yaml
service: event.fire
data:
  event_type: check_zwave_js
```

## Database Maintenance

### Automation Details
- **ID**: `daily_database_maintenance`
- **File**: `/config/automations/system_maintenance.yaml`
- **Purpose**: Optimizes the Home Assistant database

### Schedule
Runs daily at 3:30 AM, but only if Home Assistant has been running for over 24 hours.

### Actions
1. Purges old records (keeps 30 days of history)
2. Repacks the database for improved performance
3. Creates a notification when complete

### Full Database Maintenance
For more thorough maintenance, a script is available:
```bash
bash /config/ha_db_maintenance.sh
```
Note: This should only be run when Home Assistant is stopped.

## Entity Registry Check

### Automation Details
- **ID**: `entity_registry_check`
- **File**: `/config/automations/system_maintenance.yaml`
- **Purpose**: Checks for entity conflicts and problems in the entity registry

### Triggers
1. Home Assistant startup (with 5-minute delay)
2. Weekly on Sunday at 4:30 AM
3. Manual trigger via event `check_entity_registry`

### Actions
1. Checks for entity registry conflicts, focusing on:
   - Recently renamed entities that may have duplicates
   - Missing entities that should exist
2. Creates a notification if issues are found

### Manual Check
To manually trigger the entity registry check:
```yaml
service: event.fire
data:
  event_type: check_entity_registry
```

### Entity Mapping
The automation currently monitors these entity pairs for conflicts:
- `input_number.curatron_drying_threshold` → `input_number.curatron_drying_threshold_slider`
- `input_boolean.curatron_drying_active` → `input_boolean.curatron_drying_active_mode`
- `input_datetime.last_fertigation_time` → `input_datetime.last_fertigation_timestamp`

## Important Command References

### BLE Device Management
- **Discovery**: `python /config/python_scripts/ble_device_discovery.py`
- **Setup**: `bash /config/ble_device_setup.sh`

### Custom Component Validation
- **HACS Validation**: `bash -c "cd custom_components/<component_name> && hacs validate"`

### Configuration Deployment
- **Deploy/Sync**: `bash sync_home_assistant.sh` (Note: Never run this command as per CLAUDE.md)