# Failed Automations Fix Plan

**Issue**: 20 failed automations detected in system health monitor
**Priority Order**: 1 → 3 → 4 → 2 (Database → MQTT/BLE → Templates → ESPHome)

---

## Priority 1: Fix Database Backup Scripts (Critical)

### **Problem**
- Multiple backup automations failing with shell script execution errors
- Error: `[Errno 2] No such file or directory` when executing multiline shell scripts
- Affects 6+ backup automations running hourly/daily

### **Failed Automations**
- `database_hourly_backup_peak_hours`
- `postgresql_hourly_backup_peak_hours`
- `database_backup_retention_management`
- `postgresql_backup_retention_management`
- `postgresql_automatic_backup`
- `postgresql_daily_health_check`

### **Root Cause**
Shell scripts are being passed as string content to `shell_command` service calls instead of proper script file references or properly formatted shell commands.

### **Fix Steps**
1. **Create shell script files**:
   ```bash
   mkdir -p /config/scripts/backup/
   ```

2. **Move shell script content to proper .sh files**:
   - `/config/scripts/backup/database_backup.sh`
   - `/config/scripts/backup/postgresql_backup.sh`
   - `/config/scripts/backup/retention_cleanup.sh`

3. **Update shell_command.yaml**:
   ```yaml
   shell_command:
     database_backup: "/config/scripts/backup/database_backup.sh"
     postgresql_backup: "/config/scripts/backup/postgresql_backup.sh"
     retention_cleanup: "/config/scripts/backup/retention_cleanup.sh"
   ```

4. **Set proper permissions**:
   ```bash
   chmod +x /config/scripts/backup/*.sh
   ```

5. **Update automation service calls**:
   - Change from inline shell script content to `shell_command.database_backup`
   - Add error handling and logging

### **Expected Result**
- All 6 backup automations operational
- Reduce failed count by 6

---

## Priority 3: MQTT/BLE Configuration (High)

### **Problem**
- BLE car detection failing: `Cannot subscribe to topic 'xbg'`
- Multiple BLE garage door automations dependent on missing entities
- MQTT broker configuration issues

### **Failed Automations**
- `ble_car_detection_processor`
- BLE garage door automations (3-4 automations)
- BLE device discovery automations

### **Root Cause**
- MQTT topic 'xbg' doesn't exist or broker misconfigured
- Missing input helper entities for BLE system
- April Brother BLE Gateway connectivity issues

### **Fix Steps**
1. **Verify MQTT broker status**:
   ```bash
   mosquitto_sub -h localhost -t xbg/#
   ```

2. **Check BLE Gateway connectivity**:
   - Ping April Brother BLE Gateway at 192.168.1.82
   - Verify MQTT publishing from gateway

3. **Create missing input helpers**:
   - `input_boolean.ble_car1_present`
   - `input_boolean.ble_car2_present`
   - `input_boolean.ble_car3_present`
   - `input_number.ble_car1_rssi`
   - Related BLE control entities

4. **Fix MQTT topics**:
   - Update automation triggers to use correct MQTT topics
   - Or create MQTT sensor entities to bridge topics

5. **Test BLE system**:
   - Verify all input helpers exist and are accessible
   - Test automation conditions and triggers

### **Expected Result**
- BLE car detection operational
- Garage door automations working
- Reduce failed count by 4-5

---

## Priority 4: Template Fixes (Medium)

### **Problem**
- Template rendering errors in device health monitoring
- Error: `'dict object' has no attribute 'to_state'`
- Incorrect template syntax causing automation failures

### **Failed Automations**
- `device_health_monitor_optimized`
- Related template-based health monitoring automations

### **Root Cause**
Templates trying to access `trigger.to_state` when `trigger` is a dict object without that attribute.

### **Fix Steps**
1. **Locate problematic templates**:
   - Search for `to_state` usage in automation templates
   - Focus on device health monitoring automations

2. **Fix template syntax**:
   ```yaml
   # Before (broken):
   message: "{{ trigger.to_state.state }}"
   
   # After (fixed):
   message: "{{ trigger.to_state.state if trigger.to_state else 'unknown' }}"
   ```

3. **Add proper null checks**:
   ```yaml
   value_template: >
     {% if trigger.to_state %}
       {{ trigger.to_state.state }}
     {% else %}
       unknown
     {% endif %}
   ```

4. **Test template rendering**:
   - Use Developer Tools → Template to test fixes
   - Verify templates work with various trigger scenarios

5. **Add defensive programming**:
   - Add default values for all template variables
   - Use `| default('unknown')` filters

### **Expected Result**
- Device health monitoring operational
- Template errors eliminated
- Reduce failed count by 1-2

---

## Priority 2: ESPHome Integration (Low)

### **Problem**
- Fertigation automation failing: `esphome.wroommicrousb_set_last_fertigation_time not found`
- ESPHome device offline or service not registered

### **Failed Automations**
- `fertigation` (fails every 4 hours: 03:30, 07:30, 11:30, 15:30)

### **Root Cause**
ESPHome device `wroommicrousb` is either:
- Offline/disconnected
- Not properly configured
- Service not registered in Home Assistant

### **Fix Steps**
1. **Check ESPHome device status**:
   - Developer Tools → States → Search for `esphome`
   - Check `sensor.wroommicrousb_*` entities

2. **Verify ESPHome device connectivity**:
   - Check device logs in ESPHome dashboard
   - Verify network connectivity to device
   - Check WiFi signal strength

3. **Review ESPHome configuration**:
   ```yaml
   # Ensure service is defined in device YAML:
   api:
     services:
       - service: set_last_fertigation_time
         variables:
           timestamp: int
         then:
           # Service implementation
   ```

4. **Add conditional logic to automation**:
   ```yaml
   action:
     - choose:
         - conditions:
             - condition: template
               value_template: "{{ has_value('esphome.wroommicrousb_set_last_fertigation_time') }}"
           sequence:
             - service: esphome.wroommicrousb_set_last_fertigation_time
               data:
                 timestamp: "{{ as_timestamp(now()) | int }}"
       default:
         - service: logbook.log
           data:
             name: Fertigation
             message: "ESPHome service unavailable, skipping timestamp update"
   ```

5. **Alternative solutions**:
   - Use input_datetime instead of ESPHome service
   - Create MQTT alternative for timestamp tracking

### **Expected Result**
- Fertigation automation operational
- Reduce failed count by 1

---

## Implementation Timeline

### **Week 1: Database Fixes (Priority 1)**
- Day 1-2: Create and test backup scripts
- Day 3-4: Update automations and test backups
- Day 5: Verify all backup automations working

### **Week 2: MQTT/BLE (Priority 3)**
- Day 1-2: Diagnose and fix MQTT issues
- Day 3-4: Create missing input helpers
- Day 5: Test BLE system functionality

### **Week 3: Templates (Priority 4)**
- Day 1-2: Fix template syntax errors
- Day 3: Test all templates thoroughly
- Day 4-5: Deploy and verify fixes

### **Week 4: ESPHome (Priority 2)**
- Day 1-2: Diagnose ESPHome connectivity
- Day 3-4: Implement conditional logic
- Day 5: Test fertigation system

---

## Success Metrics

**Target**: Reduce failed automations from 20 to 0-2

**Milestones**:
- After Priority 1: 14 failed (6 fixed)
- After Priority 3: 9-10 failed (4-5 more fixed)
- After Priority 4: 7-8 failed (1-2 more fixed)  
- After Priority 2: 6-7 failed (1 more fixed)

**Final Goal**: ≤ 2 failed automations (acceptable maintenance level)

---

## Rollback Plan

If any fixes cause issues:
1. **Database scripts**: Revert to old automation, disable problematic ones
2. **MQTT/BLE**: Disable BLE automations until gateway fixed
3. **Templates**: Add more defensive null checks
4. **ESPHome**: Use fallback input_datetime approach

---

## Testing Strategy

1. **Test in Dev Tools first** (templates, service calls)
2. **Enable one automation at a time**
3. **Monitor logs for errors**
4. **Verify system health dashboard shows improvements**
5. **Document any remaining issues for future iteration**