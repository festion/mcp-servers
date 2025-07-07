# Hydroponics System - Troubleshooting Guide

This guide helps diagnose and fix common issues with the hydroponics management system.

## Diagnostic Approach

When troubleshooting issues, follow this structured approach:

1. **Identify symptoms** - What's not working as expected?
2. **Check logs** - Review Home Assistant logs for errors
3. **Verify entity states** - Are sensors reporting correct values?
4. **Test components** - Test scripts and individual components
5. **Make corrections** - Apply fixes systematically

## Common Issues

### Fertigation Issues

#### Fertigation Cycles Not Running

**Symptoms:**
- No pump activation at scheduled times
- Last fertigation time not updating

**Possible Causes:**
1. Automation disabled
2. Incorrect fertigation interval
3. Feed pump entity unavailable
4. Time-based trigger issues

**Diagnostic Steps:**
1. Check automation status in Home Assistant UI
2. Verify `input_number.hydroponics_fertigation_interval_hours` value
3. Check `switch.tp_link_smart_plug_c82e_feed_pump` availability
4. Test manual fertigation via dashboard or service call

**Solutions:**
```yaml
# Test via service call
service: script.fertigation_cycle
data:
  duration: 10
```

#### Pump Running Too Short/Long

**Symptoms:**
- Insufficient/excessive water delivery
- Overflow or plant dryness

**Possible Causes:**
1. Incorrect pump duration setting
2. Delay timing issue in script

**Diagnostic Steps:**
1. Check `input_number.hydroponics_feed_pump_duration` value
2. Time actual pump operation manually

**Solutions:**
- Adjust pump duration via dashboard slider
- Edit script duration parameter if necessary

### Sensor Issues

#### Water Level Sensor Erratic

**Symptoms:**
- Fluctuating water level readings
- False low water alerts

**Possible Causes:**
1. Sensor malfunction or interference
2. Loose wiring
3. Water turbulence affecting readings

**Diagnostic Steps:**
1. Check sensor raw values with fixed reference
2. Monitor readings over time
3. Inspect physical setup

**Solutions:**
```yaml
# Create temporary template sensor to filter readings
sensor:
  - platform: template
    sensors:
      filtered_water_level:
        friendly_name: "Filtered Water Level"
        value_template: >
          {% set raw = states('sensor.wroommicrousb_reservoir_water_level')|float %}
          {% if raw < 0 or raw > 100 %}
            {{ states('sensor.filtered_water_level') }}
          {% else %}
            {{ raw }}
          {% endif %}
        unit_of_measurement: "cm"
```

#### Temperature Sensor Issues

**Symptoms:**
- Unexpected temperature alerts
- Readings outside normal range

**Possible Causes:**
1. Sensor calibration drift
2. Sensor placement issues
3. Actual temperature problem

**Diagnostic Steps:**
1. Verify with secondary thermometer
2. Check sensor placement
3. Review temperature trend over time

**Solutions:**
- Recalibrate temperature sensor
- Adjust sensor placement
- Create offset in template if needed

### Alert Issues

#### Missing Notifications

**Symptoms:**
- System events occur but no notifications received
- Some alerts arrive but others missing

**Possible Causes:**
1. Alert level setting too restrictive
2. Notification service issues
3. Conditional logic preventing alerts

**Diagnostic Steps:**
1. Check `input_select.hydroponics_alert_level` setting
2. Test notification service directly
3. Review automation conditions

**Solutions:**
```yaml
# Test notification service directly
service: notify.mobile_app_pixel_9_pro_xl
data:
  title: "Test Alert"
  message: "Testing hydroponics notifications"
  data:
    tag: "hydro_test"
```

#### Too Many Notifications

**Symptoms:**
- Excessive alert frequency
- Duplicate notifications

**Possible Causes:**
1. Alert level set too verbose
2. Sensor fluctuations near threshold
3. Multiple triggers firing

**Diagnostic Steps:**
1. Check notification frequency and timing
2. Review sensor data for rapid fluctuations
3. Check for repeated trigger activations

**Solutions:**
- Change alert level to "Critical Only"
- Add hysteresis to sensor thresholds
- Adjust trigger conditions

### Dashboard Issues

#### Dashboard Not Showing

**Symptoms:**
- Hydroponics dashboard missing from sidebar
- Cannot access dashboard URL

**Possible Causes:**
1. Dashboard not registered correctly
2. YAML syntax error
3. Lovelace configuration issue

**Diagnostic Steps:**
1. Check `configuration.yaml` for proper dashboard registration
2. Validate YAML syntax
3. Review Home Assistant logs for errors

**Solutions:**
- Update dashboard registration
- Fix YAML syntax errors
- Clear browser cache

#### Graph Data Missing

**Symptoms:**
- Empty graphs on dashboard
- Partial data display

**Possible Causes:**
1. Sensor entities unavailable
2. History data missing
3. Custom card configuration error

**Diagnostic Steps:**
1. Check sensor availability
2. Review database recorder settings
3. Inspect custom card configuration

**Solutions:**
- Verify entities exist and report data
- Ensure recorder is properly configured
- Update custom card configuration

## Script Debugging

### Testing Individual Scripts

To isolate automation issues, test scripts individually:

1. Navigate to Developer Tools > Services
2. Select the script to test (e.g., `script.fertigation_cycle`)
3. Enter appropriate parameters
4. Call the service and observe behavior

### Checking Script Execution

To verify script execution:

```yaml
# Add temporary logging to scripts
- service: system_log.write
  data:
    message: "Script X executed with parameters: {{ param_name }}"
    level: debug
```

## Automation Debugging

### Trigger Diagnosis

To identify which triggers are firing:

```yaml
# Add debug logging to automation
- service: system_log.write
  data:
    message: "Hydroponics trigger fired: {{ trigger.id }}"
    level: debug
```

### Condition Testing

To test specific conditions:

```yaml
# Template sensor for condition testing
sensor:
  - platform: template
    sensors:
      hydro_condition_test:
        friendly_name: "Hydro Condition Test"
        value_template: >
          {% if states('sensor.wroommicrousb_reservoir_water_level')|float < 5 %}
            true
          {% else %}
            false
          {% endif %}
```

## Advanced Troubleshooting

### Automation Tracing

Use Home Assistant's built-in trace feature:

1. Go to Developer Tools > Events
2. Look for `automation_triggered` events
3. Review the event data for insights

### Timeline Analysis

Create a timeline of events to troubleshoot timing issues:

1. Enable DEBUG logging for automation components
2. Collect logs during a problem period
3. Construct a timeline of events from logs
4. Look for patterns or issues in the sequence

### Entity State Dumps

Capture entity states during issues:

```yaml
# Create debug script
debug_hydro_states:
  alias: Debug Hydro States
  sequence:
    - service: persistent_notification.create
      data:
        title: "Hydroponics Debug Dump"
        message: >
          ## Hydroponics System State
          Time: {{ now() }}
          
          Water Level: {{ states('sensor.wroommicrousb_reservoir_water_level') }}
          Volume: {{ states('sensor.wroommicrousb_reservoir_current_volume') }}
          Temperature: {{ states('sensor.wroommicrousb_reservoir_water_temp') }}
          pH: {{ states('sensor.water_quality_monitor_ph') }}
          EC: {{ states('sensor.water_quality_monitor_electrical_conductivity') }}
          
          Feed Pump: {{ states('switch.tp_link_smart_plug_c82e_feed_pump') }}
          Waste Pump: {{ states('switch.tp_link_smart_plug_c82e_waste_pump') }}
          
          Fertigation Interval: {{ states('input_number.hydroponics_fertigation_interval_hours') }}
          Feed Duration: {{ states('input_number.hydroponics_feed_pump_duration') }}
          Waste Schedule: {{ states('input_select.hydroponics_waste_pump_schedule') }}
          Alert Level: {{ states('input_select.hydroponics_alert_level') }}
        notification_id: "hydro_debug_dump"
```

## Hardware Troubleshooting

### Pump Issues

**For unresponsive pumps:**

1. Check physical power connection
2. Test pump with manual switch
3. Verify switch entity control
4. Check for excessive back pressure or clogs

**For pumps running continuously:**

1. Turn off automation temporarily
2. Reset switch state manually
3. Check for switch state desync
4. Look for configuration issues in schedules

### Sensor Hardware

**For sensor issues:**

1. Check physical connections
2. Clean sensors per manufacturer recommendations
3. Test with known references (pH buffer solutions, known water levels)
4. Replace if consistently inaccurate

## Getting Help

If problems persist after trying these troubleshooting steps:

1. Collect diagnostic information:
   - Home Assistant logs
   - Entity state dumps
   - Screenshots of issues
   - Timeline of events

2. Check for updates to:
   - Home Assistant
   - Custom components
   - Hydroponics system scripts

3. Consider system recovery options:
   - Restore from backup
   - Reset problem components
   - Reinstall automation components