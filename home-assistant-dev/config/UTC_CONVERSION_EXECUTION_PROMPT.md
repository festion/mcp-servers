# HOME ASSISTANT UTC CONVERSION - STANDALONE EXECUTION PROMPT

## PROJECT CONTEXT
- **Home Assistant Version**: 2025.5.3
- **Project Directory**: Z:\ (network mapped Home Assistant config)
- **Current Health**: 99.2% (stable system)
- **Purpose**: Complete UTC standardization to eliminate timezone calculation errors

## CONVERSION STATUS
### ✅ ALREADY UTC CONVERTED:
- `automations/curatron.yaml` - Fully UTC standardized
- `templates_curatron_utc.yaml` - UTC template sensors ready
- `DATETIME_STANDARDS_UTC.md` - Implementation standards defined

### ❌ REQUIRES UTC CONVERSION:
- `templates.yaml` - Contains timezone-naive `strptime()` patterns
- Any other templates using `now() - strptime()` calculations

## REPAIR INSTRUCTIONS

### STEP 1: Backup Current Files
```bash
# Backup templates.yaml
cp Z:\templates.yaml Z:\templates_backup_pre_utc_$(date +%Y%m%d_%H%M%S).yaml
```

### STEP 2: Convert templates.yaml UTC Patterns
**Find and replace these problematic patterns:**

#### ❌ REMOVE: Timezone-naive calculations
```yaml
# BAD - causes offset-naive/offset-aware errors
{% set start_dt = strptime(start_time, '%Y-%m-%d %H:%M:%S') %}
{% set now_dt = now().replace(tzinfo=None) %}
{% set hours_since = ((now_dt - start_dt).total_seconds() / 3600) %}
```

#### ✅ REPLACE WITH: UTC timestamp calculations
```yaml
# GOOD - UTC safe timestamp calculations
{% set start_timestamp = state_attr('input_datetime.curatron_drying_start_time', 'timestamp') | float(0) %}
{% set current_timestamp = utcnow().timestamp() %}
{% set hours_since = ((current_timestamp - start_timestamp) / 3600) | round(1) %}
```

### STEP 3: Specific Template Fixes Required

#### Fix Curatron Progress Sensor:
**Location**: `templates.yaml` - "Curatron Drying Progress" sensor
**Replace**: All `strptime()` and `now().replace(tzinfo=None)` patterns
**With**: Timestamp-based calculations using `state_attr('input_datetime.curatron_drying_start_time', 'timestamp')`

#### Fix Curatron Status Sensor:
**Location**: `templates.yaml` - "Curatron Drying Status" sensor
**Replace**: Same timezone-naive patterns in attributes
**With**: UTC timestamp calculations

#### Fix Health Dashboard:
**Location**: `templates.yaml` - "Health Dashboard Instructions" 
**Replace**: `now().strftime('%Y-%m-%d %H:%M:%S')`
**With**: `utcnow().strftime('%Y-%m-%d %H:%M:%S')`

### STEP 4: Deploy UTC Template Alternative
**Option A**: Replace problematic sensors in templates.yaml
**Option B**: Include templates_curatron_utc.yaml and disable old sensors

### STEP 5: Validation Steps
1. **Configuration Check**: `ha core check`
2. **Template Validation**: Check for template errors in logs
3. **Automation Test**: Trigger Curatron automation manually
4. **Health Monitoring**: Verify no datetime errors appear
5. **Dashboard Verification**: Confirm Curatron dashboard displays correctly

### STEP 6: Update Configuration Include
```yaml
# In configuration.yaml, update template include
template: 
  - !include templates.yaml
  - !include templates_curatron_utc.yaml  # Add UTC sensors
```

## ERROR PREVENTION PATTERNS

### Use These UTC-Safe Patterns:
```yaml
# Current UTC timestamp
current_timestamp: "{{ utcnow().timestamp() }}"

# Extract stored timestamp
stored_timestamp: "{{ state_attr('input_datetime.entity', 'timestamp') | float(0) }}"

# Calculate time difference
hours_elapsed: "{{ ((current_timestamp - stored_timestamp) / 3600) | round(1) }}"

# UTC datetime for storage
utc_datetime: "{{ utcnow().strftime('%Y-%m-%d %H:%M:%S') }}"

# Local display (user-friendly)
local_display: "{{ stored_timestamp | timestamp_local }}"
```

### Avoid These Problematic Patterns:
```yaml
# NEVER use these - cause timezone errors
strptime(datetime_string, format)
now().replace(tzinfo=None)
now() - strptime()
datetime subtraction with mixed timezone types
```

## COMPLETION CRITERIA
- [ ] All `strptime()` patterns removed from templates.yaml
- [ ] All `now().replace(tzinfo=None)` patterns replaced with UTC
- [ ] Curatron sensors use timestamp-based calculations
- [ ] Health dashboard uses `utcnow()` for timestamps
- [ ] Configuration check passes without errors
- [ ] No datetime-related errors in logs after restart
- [ ] Curatron dashboard displays correctly
- [ ] System health remains >95%

## ROLLBACK PROCEDURE
If issues occur:
1. Restore backup: `cp Z:\templates_backup_pre_utc_*.yaml Z:\templates.yaml`
2. Restart Home Assistant
3. Verify system health recovery
4. Investigate specific template errors

## REFERENCE FILES
- **Standards**: `Z:\DATETIME_STANDARDS_UTC.md`
- **Working Example**: `Z:\templates_curatron_utc.yaml`
- **Fixed Automation**: `Z:\automations\curatron.yaml`

## SUCCESS VALIDATION
After completion:
- System health >95%
- No timezone-related errors in logs
- Curatron drying calculations work correctly
- Dashboard displays accurate time information
- All datetime operations use UTC standards

This conversion ensures robust, timezone-safe datetime handling across the entire Home Assistant configuration.