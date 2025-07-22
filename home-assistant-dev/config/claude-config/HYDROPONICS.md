# Hydroponics Management System Documentation

## Overview
The Hydroponics Management System is a custom Home Assistant automation solution that manages hydroponics operations through scheduled fertigation, waste pump control, environmental monitoring, and alerts.

## System Components

### 1. Main Automation (`/config/automations/hydroponics.yaml`)
Central automation that handles:
- Scheduled fertigation cycles
- Waste pump scheduling
- Water level monitoring
- Temperature monitoring and alerts

### 2. Scripts (`/config/scripts/hydroponics.yaml`)
Reusable scripts providing core functionality:
- `fertigation_cycle`: Runs the feed pump for a specified duration
- `waste_pump_control`: Controls the waste water pump
- `send_hydro_alert`: Sends notification alerts for system events
- `generate_hydro_report`: Creates a comprehensive system status report

### 3. Dashboard (`/config/dashboards/hydroponics_dashboard.yaml`)
Custom UI for monitoring and controlling the hydroponics system.

### 4. Input Helpers
Configuration options stored in input helpers:
- `hydroponics_fertigation_interval_hours`: Hours between fertigation
- `hydroponics_feed_pump_duration`: Feed pump run time
- `hydroponics_waste_pump_schedule`: Waste pump schedule
- `hydroponics_alert_level`: Notification verbosity

## Main Automation Logic

The main automation (`hydroponics_management`) handles these triggers:
1. **Midnight fertigation** (00:05:00)
2. **Scheduled fertigations** based on interval
3. **Waste pump scheduling** (on at 06:00, off at 21:00)
4. **Low water level detection** (below 5L for 5 minutes)
5. **Temperature monitoring** (alerts for too high/low)

## Hardware Components
The system controls:
- Feed pump: `switch.tp_link_smart_plug_c82e_feed_pump`
- Waste pump: `switch.tp_link_smart_plug_c82e_waste_pump`

And monitors:
- Water level: `sensor.wroommicrousb_reservoir_current_volume`
- Water temperature: `sensor.wroommicrousb_reservoir_water_temp`
- pH level: `sensor.water_quality_monitor_ph`
- EC level: `sensor.water_quality_monitor_electrical_conductivity`

## Usage Examples

### Running a Manual Fertigation Cycle
```yaml
service: script.fertigation_cycle
data:
  duration: 20  # seconds
  force: true   # run regardless of time restrictions
```

### Controlling the Waste Pump
```yaml
service: script.waste_pump_control
data:
  action: "on"  # or "off"
```

### Generating a System Report
```yaml
service: script.generate_hydro_report
```

## Troubleshooting

Common issues:
- **Missed fertigation cycles**: Check `hydroponics_fertigation_interval_hours` setting
- **Pump not activating**: Verify power to pump and switch entity state
- **Missing notifications**: Check mobile app notification settings