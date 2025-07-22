# Home Assistant Command Reference

## System Commands

### Configuration Management
- **Deploy/Sync**: `bash sync_home_assistant.sh` 
  - Syncs local changes to Home Assistant using rsync over Samba
  - **IMPORTANT**: Never run this command as per CLAUDE.md instructions

### Testing and Validation
- **Custom Component Tests**: `pytest custom_components/<component_name>/test`
  - Runs test suite for specific custom component
- **HACS Validation**: `bash -c "cd custom_components/<component_name> && hacs validate"` 
  - Validates a custom component according to HACS standards

### Database Management
- **Database Maintenance**: `bash ha_db_maintenance.sh`
  - Performs database optimization
  - Only run when Home Assistant is stopped
- **Daily Database Optimization**: Automated at 3:30 AM via automation
  - Uses `recorder.purge` service with 30-day retention

### BLE Device Management
- **BLE Device Discovery**: `python /config/python_scripts/ble_device_discovery.py`
  - Scans for and discovers BLE devices
- **BLE Device Setup**: `bash /config/ble_device_setup.sh`
  - Sets up discovered BLE devices

## Z-Wave Management
- **Z-Wave JS Check**: `shell_command.check_zwave_js`
  - Checks Z-Wave JS connectivity
  - Creates log at `/config/logs/zwave_js_check.log`

## Script Usage Examples

### Hydroponics System
- **Fertigation Cycle**: 
  ```yaml
  service: script.fertigation_cycle
  data:
    duration: 15  # seconds
    force: false  # optional override
  ```

- **Waste Pump Control**:
  ```yaml
  service: script.waste_pump_control
  data:
    action: "on"  # or "off"
  ```

- **Generate Report**:
  ```yaml
  service: script.generate_hydro_report
  ```

## Coding Standards

### Important Notes
- Use "context7" for all coding or YAML work (as per CLAUDE.md)
- Follow Home Assistant YAML formatting standards
- Maintain automation and script structure from existing files
- Ensure proper indentation in YAML files (2 spaces)