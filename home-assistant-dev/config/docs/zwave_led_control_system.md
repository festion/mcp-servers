# Z-Wave LED Control System Documentation

## System Overview

The Z-Wave LED Control System provides automated and manual control over LED indicator lights on Z-Wave switches throughout the home. The system reduces light pollution in sleeping areas while maintaining helpful navigation LEDs in common areas.

### Key Features
- **Automatic Night Mode**: LEDs turn off at 10 PM and restore at 7 AM
- **Manual Override**: Immediate control during night hours (10 PM - 7 AM)
- **Preset Configurations**: Quick bedroom preset and all-off/all-on options
- **Real-time Status**: Dashboard with live status indicators and controls
- **Flexible Selection**: Individual control over each switch's LED indicator

## System Architecture

### Core Components

#### 1. **Hardware Devices**
- **Light Switches**: 10x Leviton DZ1KD dimmer switches (parameter 7 controls LED)
- **Fan Switches**: 5x Leviton ZW4SF fan controllers (parameter 3 controls LED)
- **Total Devices**: 15 Z-Wave switches with controllable LED indicators

#### 2. **Configuration Files**
```
/config/automations/zwave_led_control.yaml    # Main automation logic
/config/scripts/zwave_led_control.yaml        # Convenience scripts
/config/input_boolean.yaml                    # Individual switch toggles (lines 12-85)
/config/dashboards/zwave_led_control_dashboard.yaml  # Control interface
/config/packages/zwave_led_night_mode.yaml    # Night mode module
```

#### 3. **Entity Structure**
- **Input Booleans**: 15 entities for individual switch LED control
- **Automations**: 3 main automations for scheduled and manual control
- **Scripts**: 4 convenience scripts for common operations
- **Sensors**: Status tracking and counting sensors
- **Binary Sensor**: Night mode active status

### Device Mapping

#### Light Switches (DZ1KD - Parameter 7)
| Entity ID | Location | LED Control Entity |
|-----------|----------|-------------------|
| `light.hobby_light` | Hobby/Craft Room | `input_boolean.zwave_led_darken_hobby_light` |
| `light.gavin_light` | Gavin's Room | `input_boolean.zwave_led_darken_gavin_light` |
| `light.pantry_light` | Pantry | `input_boolean.zwave_led_darken_pantry_light` |
| `light.master_light` | Master Bedroom | `input_boolean.zwave_led_darken_master_light` |
| `light.nook_light` | Nook | `input_boolean.zwave_led_darken_nook_light` |
| `light.guest_light` | Guest Room | `input_boolean.zwave_led_darken_guest_light` |
| `light.porch_light` | Porch | `input_boolean.zwave_led_darken_porch_light` |
| `light.hall_light` | Hall | `input_boolean.zwave_led_darken_hall_light` |
| `light.dining_light` | Dining Room | `input_boolean.zwave_led_darken_dining_light` |
| `light.linda_light` | Linda's Room | `input_boolean.zwave_led_darken_linda_light` |

#### Fan Switches (ZW4SF - Parameter 3)
| Entity ID | Location | LED Control Entity |
|-----------|----------|-------------------|
| `fan.hobby_fan` | Hobby/Craft Room | `input_boolean.zwave_led_darken_hobby_fan` |
| `fan.master_fan` | Master Bedroom | `input_boolean.zwave_led_darken_master_fan` |
| `fan.linda_fan` | Linda's Room | `input_boolean.zwave_led_darken_linda_fan` |
| `fan.guest_fan` | Guest Room | `input_boolean.zwave_led_darken_guest_fan` |
| `fan.gavin_fan` | Gavin's Room | `input_boolean.zwave_led_darken_gavin_fan` |

## Automation Logic

### 1. Night Mode Automation (`zwave_led_night_mode_on`)
- **Trigger**: Daily at 10:00 PM
- **Action**: Checks each input boolean and turns off corresponding LED if enabled
- **Logic**: Individual conditional checks for each of the 15 switches

### 2. Day Mode Automation (`zwave_led_day_mode_on`)
- **Trigger**: Daily at 7:00 AM
- **Action**: Restores ALL LED indicators to normal operation (value=1)
- **Logic**: Bulk operation on all light and fan switches

### 3. Manual Control Automation (`zwave_led_manual_control`)
- **Trigger**: State change of any input boolean during night hours
- **Condition**: Only active between 10 PM - 7 AM
- **Action**: Immediately applies LED change using choose/conditions logic
- **Mode**: Parallel execution (max: 20)

### Parameter Values
- **Value 0**: LED off when load is off (darkened)
- **Value 1**: LED on when load is off (normal operation/navigation aid)

## User Interface

### Dashboard Organization
1. **Status Overview**: Current time, night mode status, LED count
2. **Quick Actions**: All on/off, bedroom preset, apply night settings
3. **Bedroom Area Controls**: All bedroom and guest room switches
4. **Common Area Controls**: Hall, porch, dining, pantry, hobby areas
5. **System Status**: Automation status and last-triggered times

### Available Scripts
- `zwave_led_restore_all`: Immediately restore all LEDs to normal
- `zwave_led_turn_off_all`: Immediately turn off all LEDs
- `zwave_led_bedroom_preset`: Turn off bedroom LEDs, keep common areas on
- `zwave_led_apply_night_settings`: Manually trigger night mode logic

## Night Mode Module Features

### Preset Management
- **All LEDs On**: Disables all LED darkening
- **Bedroom LEDs Off**: Darkens only bedroom/sleeping areas
- **All LEDs Off**: Darkens all LED indicators
- **Custom Selection**: Manual individual control

### Status Sensors
- `sensor.zwave_led_off_count`: Total number of LEDs currently darkened
- `sensor.zwave_led_bedroom_count`: Number of bedroom LEDs darkened
- `binary_sensor.night_mode_active`: True during night hours (10 PM - 7 AM)

### Notifications
- Persistent notifications when night/day mode begins
- Automatic dismissal of day mode notifications after 5 minutes

## Installation & Setup

### Prerequisites
- Home Assistant with Z-Wave JS integration
- 15 Leviton Z-Wave switches (DZ1KD/ZW4SF) properly included in network
- Package integration enabled in configuration.yaml

### Configuration Steps
1. Ensure all Z-Wave devices are included and named correctly
2. Add input boolean entities for each switch
3. Deploy automation, script, and package files
4. Add dashboard configuration
5. Test manual control during night hours
6. Verify automatic scheduling at 10 PM and 7 AM

## Usage Guide

### Daily Operation
1. **Automatic**: System runs automatically with 10 PM/7 AM schedule
2. **Manual Override**: Use dashboard toggles during night hours for immediate changes
3. **Presets**: Use quick action buttons for common scenarios

### Best Practices
- **Bedroom Preset**: Recommended for typical night use
- **Manual Testing**: Use "Apply Night Settings" button to test configurations
- **Status Monitoring**: Check LED count sensors to verify operation

### Common Scenarios
- **Bedtime Routine**: Use bedroom preset or manual toggles at 10 PM
- **Guest Visits**: Temporarily enable guest room navigation LEDs
- **Sick Days**: Use "All LEDs Off" for complete darkness
- **Travel**: Use "All LEDs On" to maintain security lighting appearance

## Troubleshooting

### Common Issues

#### LEDs Not Responding to Commands
1. **Check Z-Wave Network**: Verify device is online in Z-Wave JS
2. **Parameter Verification**: Confirm parameter 7 (lights) or 3 (fans) is correct
3. **Manual Test**: Use Z-Wave JS service call directly
4. **Entity Names**: Verify light/fan entity IDs match automation

#### Manual Control Not Working
1. **Time Check**: Manual control only works during night hours (10 PM - 7 AM)
2. **Automation Status**: Verify `automation.z_wave_leds_manual_control` is enabled
3. **Trigger Test**: Check automation traces for trigger events
4. **Parallel Mode**: Ensure automation mode is set to parallel

#### Automation Not Triggering
1. **Time Zone**: Verify Home Assistant time zone matches local time
2. **Automation State**: Check if automations are enabled
3. **Entity Availability**: Confirm all referenced entities exist
4. **Log Analysis**: Check Home Assistant logs for automation errors

### Diagnostic Commands
```bash
# Check Z-Wave device status
grep -E "zwave.*led|led.*zwave" /config/home-assistant.log | tail -10

# Check automation errors
grep -E "ERROR.*zwave_led" /config/home-assistant.log

# Verify entity states
# Use Developer Tools > States to check input_boolean states
```

### Manual Recovery Procedures

#### Reset All LEDs to Normal
```yaml
# Use Developer Tools > Services
service: script.zwave_led_restore_all
```

#### Force Night Mode Application
```yaml
# Use Developer Tools > Services
service: script.zwave_led_apply_night_settings
```

#### Individual Switch Recovery
```yaml
# Example for hobby light
service: zwave_js.set_config_parameter
target:
  entity_id: light.hobby_light
data:
  parameter: 7
  value: 1  # or 0 for off
```

## Maintenance

### Regular Tasks
- **Monthly**: Verify all automations are functioning via traces
- **Quarterly**: Test manual overrides during night hours
- **Annually**: Review and update preset configurations
- **As Needed**: Update entity names if devices are replaced

### Performance Monitoring
- Monitor automation execution times in traces
- Check for Z-Wave network congestion during 10 PM mass updates
- Verify parallel mode is handling manual changes efficiently

### Updates and Changes
- **Adding Devices**: Update all relevant files with new entity references
- **Changing Schedule**: Modify time triggers in night/day mode automations
- **Preset Modifications**: Update package preset logic and dashboard

## Security Considerations
- LED indicators can reveal occupancy patterns to external observers
- Night mode helps maintain privacy by reducing visible switch activity
- Common area LEDs provide security lighting for navigation
- System provides good balance between privacy and safety

## Integration Points
- **Adaptive Lighting**: Can coordinate with other lighting automation
- **Security System**: LED status can indicate armed/disarmed states
- **Sleep Tracking**: Night mode status available for other automations
- **Energy Monitoring**: LED power consumption is minimal but trackable

---

**Last Updated**: 2025-05-25  
**System Version**: 1.2  
**Compatibility**: Home Assistant 2024.x+ with Z-Wave JS integration  
**Author**: Home Assistant Z-Wave LED Control System