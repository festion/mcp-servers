# Hydroponics Management System - Installation Guide

This guide will walk you through the process of installing and configuring the Hydroponics Management System in your Home Assistant instance.

## Prerequisites

Before installing, ensure you have:

1. A working Home Assistant installation
2. Access to the configuration directory
3. The following HACS custom cards (optional, for dashboard functionality):
   - mini-graph-card
   - apexcharts-card

## Installation

### Step 1: Copy Configuration Files

Copy the following files to their respective locations in your Home Assistant configuration directory:

| Source File | Destination |
|-------------|-------------|
| `scripts/hydroponics.yaml` | `/config/scripts/hydroponics.yaml` |
| `automations/hydroponics.yaml` | `/config/automations/hydroponics.yaml` |
| `dashboards/hydroponics_dashboard.yaml` | `/config/dashboards/hydroponics_dashboard.yaml` |

### Step 2: Update Configuration

Add the following sections to your `configuration.yaml` file:

```yaml
# Include scripts directory
script:
  - !include scripts.yaml
  - !include_dir_merge_named scripts/

# Include automations directory
automation:
  - !include automations.yaml
  - !include_dir_merge_list automations/

# Register hydroponics dashboard
lovelace:
  dashboards:
    hydroponics:
      mode: yaml
      filename: dashboards/hydroponics_dashboard.yaml
      title: Hydroponics
      icon: mdi:sprout
      show_in_sidebar: true
```

### Step 3: Add Input Helpers

Add the following configuration to your `input_helpers.yaml` file (or create it if it doesn't exist):

```yaml
# Hydroponics System Helpers
input_select:
  hydroponics_waste_pump_schedule:
    name: Waste Pump Schedule
    options:
      - "Off"
      - "6AM-9PM"
      - "Always On"
      - "Custom"
    initial: "6AM-9PM"
    icon: mdi:water-pump

  hydroponics_alert_level:
    name: Hydroponics Alert Level
    options:
      - "Critical Only" 
      - "Standard"
      - "Verbose"
    initial: "Standard"
    icon: mdi:alert-circle-outline

input_number:
  hydroponics_fertigation_interval_hours:
    name: Fertigation Interval
    initial: 3
    min: 0
    max: 12
    step: 1
    mode: slider
    unit_of_measurement: hours
    icon: mdi:timer-outline

  hydroponics_feed_pump_duration:
    name: Feed Pump Duration
    initial: 15
    min: 5
    max: 60
    step: 1
    mode: slider
    unit_of_measurement: seconds
    icon: mdi:pump

input_datetime:
  last_fertigation_time:
    name: Last Fertigation Time
    has_date: true
    has_time: true
    icon: mdi:calendar-clock
```

Then add the input helpers reference to your `configuration.yaml` if it's not already there:

```yaml
input_datetime: !include input_helpers.yaml
input_number: !include input_helpers.yaml
input_select: !include input_helpers.yaml
```

### Step 4: Create Required Directories

Ensure all required directories exist:

```bash
mkdir -p /config/scripts
mkdir -p /config/automations
mkdir -p /config/dashboards
```

### Step 5: Restart Home Assistant

Restart your Home Assistant instance to apply the changes.

## Configuration

### Mandatory Configuration

The system requires the following entities to be properly configured:

1. **Switches**:
   - `switch.tp_link_smart_plug_c82e_feed_pump`: The pump that delivers nutrient solution
   - `switch.tp_link_smart_plug_c82e_waste_pump`: The pump that removes waste water

2. **Sensors**:
   - `sensor.wroommicrousb_reservoir_water_level`: Water level sensor (cm)
   - `sensor.wroommicrousb_reservoir_current_volume`: Calculated volume (L)
   - `sensor.wroommicrousb_reservoir_water_temp`: Temperature sensor (°C)
   - `sensor.water_quality_monitor_ph`: pH sensor
   - `sensor.water_quality_monitor_electrical_conductivity`: EC sensor

If your entities have different names, you must update the references in:
- `/config/automations/hydroponics.yaml`
- `/config/dashboards/hydroponics_dashboard.yaml`

### Optional Configuration

The system can utilize these optional sensors if available:

- `sensor.reservoir_ph_change_last_24_hours`: Tracks pH changes
- `sensor.reservoir_ec_change_last_24_hours`: Tracks EC changes
- `sensor.wroommicrousb_average_volume_since_last_fertigation`: Volume tracking

## Testing the Installation

After installation, verify the system is working correctly:

1. Navigate to Developer Tools > Services
2. Call the `script.fertigation_cycle` service with default parameters
3. Verify the pump activates for the configured duration
4. Check that the notification was sent
5. Verify the last fertigation time was updated

## Upgrading

To upgrade the system:

1. Backup your configuration files
2. Copy the new files to their respective locations
3. Restart Home Assistant

## Troubleshooting Installation Issues

Common installation issues:

- **Scripts not appearing**: Check that `!include_dir_merge_named scripts/` is in your configuration
- **Automation not running**: Verify the automation is enabled in Home Assistant
- **Dashboard not visible**: Check the dashboard registration in the configuration
- **Custom cards missing**: Install required HACS custom cards

If issues persist, check Home Assistant logs for specific error messages.