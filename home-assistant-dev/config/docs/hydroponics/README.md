# Hydroponics Management System Documentation

## Overview

The Hydroponics Management System is a comprehensive automation solution for managing hydroponics operations within Home Assistant. The system handles scheduling of fertigation cycles, waste pump control, environmental monitoring, and provides timely alerts for system maintenance and potential issues.

## System Architecture

The system is built with a modular architecture for maintainability and easy troubleshooting:

```
Hydroponics Management System
├── Reusable Scripts (scripts/hydroponics.yaml)
├── Configuration Helpers (input_helpers.yaml)
├── Main Automation (automations/hydroponics.yaml)
└── Dashboard Interface (dashboards/hydroponics_dashboard.yaml)
```

### Key Components

1. **Scripts**: Modular, reusable functions for common operations
2. **Input Helpers**: Configurable settings accessible from the UI 
3. **Main Automation**: Central automation that manages all system operations
4. **Dashboard**: Custom UI for monitoring and controlling the system

## Functionality

### 1. Fertigation Control

The system manages regular nutrient delivery through scheduled fertigation cycles:

- Scheduled based on configurable interval (default: every 3 hours)
- Customizable pump duration
- Records timestamp of last fertigation
- Provides notification on completion

### 2. Waste Pump Management

Controls drainage cycles through waste pump scheduling:

- Configurable schedule (Off, 6AM-9PM, Always On, Custom)
- Automatic operation based on schedule settings
- Manual override through dashboard controls

### 3. Monitoring & Alerts

Comprehensive monitoring of system parameters:

- Water level monitoring with low-level alerts
- Temperature monitoring with alerts for too high/low values
- Water quality monitoring (pH and EC) with change detection
- Alert levels are configurable (Critical Only, Standard, Verbose)

### 4. Reporting

Generates detailed reports on system status:

- Daily automatic reports at 8:00 AM
- On-demand reporting through dashboard
- Historical data tracking and visualization

## Configuration Options

### Input Helpers

| Helper | Description | Default | Range |
|--------|-------------|---------|-------|
| `hydroponics_fertigation_interval_hours` | Hours between fertigation cycles | 3 | 0-12 |
| `hydroponics_feed_pump_duration` | Duration to run feed pump (seconds) | 15 | 5-60 |
| `hydroponics_waste_pump_schedule` | Schedule type for waste pump | 6AM-9PM | Off/6AM-9PM/Always On/Custom |
| `hydroponics_alert_level` | Controls notification verbosity | Standard | Critical Only/Standard/Verbose |

## Scripts API

The system provides reusable scripts that can be called from other automations:

### fertigation_cycle

Runs a single fertigation cycle.

**Parameters:**
- `duration`: Pump run time in seconds (default: 15)

**Example:**
```yaml
service: script.fertigation_cycle
data:
  duration: 20
```

### waste_pump_control

Controls the waste water pump.

**Parameters:**
- `action`: "on" or "off"

**Example:**
```yaml
service: script.waste_pump_control
data:
  action: "on"
```

### send_hydro_alert

Sends notification alerts for system events.

**Parameters:**
- `title`: Alert title
- `message`: Alert content
- `priority`: Alert priority ("low", "normal", "high")
- `notification_id`: Persistent notification ID (optional)
- `tag`: Mobile notification tag (default: "hydroponics_alert")

**Example:**
```yaml
service: script.send_hydro_alert
data:
  title: "Low Water Level"
  message: "Reservoir water level is critically low. Please refill!"
  priority: "high"
  tag: "hydroponics_water"
```

### generate_hydro_report

Generates a comprehensive system status report.

**Example:**
```yaml
service: script.generate_hydro_report
```

## Dashboard

The system includes a dedicated dashboard for monitoring and controlling the hydroponics system. The dashboard is organized into:

1. **Overview Tab**
   - System status display
   - Real-time metrics (water level, temperature, pH, EC)
   - Control panel for system settings
   - Action buttons for common operations

2. **History Tab**
   - Historical graphs for all system metrics
   - 48-hour detailed view
   - 7-day trend analysis

Access the dashboard from the sidebar menu under "Hydroponics".

## Troubleshooting

If issues occur with the hydroponics system, follow these steps:

1. **Check the logs**: Look for system messages related to hydroponics
2. **Verify sensor readings**: Ensure sensors are reporting accurate values
3. **Test individual scripts**: Run scripts individually to isolate issues
4. **Check schedules**: Verify time-based triggers are functioning

Common issues:

- **Missed fertigation cycles**: Check `hydroponics_fertigation_interval_hours` setting
- **Pump not activating**: Verify power to pump and switch entity state
- **Missing notifications**: Check `hydroponics_alert_level` setting

## Sensor Requirements

For full functionality, the system expects the following sensors:

- `sensor.wroommicrousb_reservoir_water_level`: Water level (cm)
- `sensor.wroommicrousb_reservoir_current_volume`: Reservoir volume (L)
- `sensor.wroommicrousb_reservoir_water_temp`: Water temperature (°C)
- `sensor.water_quality_monitor_ph`: Water pH level
- `sensor.water_quality_monitor_electrical_conductivity`: Water EC level

## Extension Points

The system can be extended in several ways:

1. Add additional monitoring sensors (dissolved oxygen, nutrients, etc.)
2. Integrate with climate control systems 
3. Add automated pH/EC adjustment capabilities
4. Implement ML-based prediction of system maintenance needs