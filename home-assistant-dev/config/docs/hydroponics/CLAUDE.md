# Hydroponics System Documentation for Claude

## System Overview

The hydroponics management system automates the care and monitoring of a hydroponic garden through Home Assistant. This system controls nutrient delivery (fertigation), waste water removal, and monitors critical parameters like water level, temperature, pH, and electrical conductivity.

## Primary Components

1. **Fertigation System**: Delivers nutrient solution on a configurable schedule
2. **Waste Water Management**: Controls drainage on a scheduled basis
3. **Environmental Monitoring**: Tracks water levels, temperature, pH, and EC
4. **Alert System**: Notifies of critical conditions or maintenance needs
5. **Reporting**: Provides status updates and historical analysis

## Key Files and Locations

```
/config/
├── automations/
│   └── hydroponics.yaml           # Main automation logic
├── scripts/
│   └── hydroponics.yaml           # Reusable script functions
├── dashboards/
│   └── hydroponics_dashboard.yaml # Dashboard interface
├── docs/
│   └── hydroponics/               # Documentation directory
└── input_helpers.yaml             # User configuration values
```

## Required Entities

**Sensors:**
- `sensor.wroommicrousb_reservoir_water_level`: Water level in cm
- `sensor.wroommicrousb_reservoir_current_volume`: Calculated volume in liters
- `sensor.wroommicrousb_reservoir_water_temp`: Water temperature in °C
- `sensor.water_quality_monitor_ph`: pH level
- `sensor.water_quality_monitor_electrical_conductivity`: EC level

**Switches:**
- `switch.tp_link_smart_plug_c82e_feed_pump`: Controls nutrient delivery pump
- `switch.tp_link_smart_plug_c82e_waste_pump`: Controls waste water pump

**Input Helpers:**
- `input_number.hydroponics_fertigation_interval_hours`: Hours between fertigation cycles
- `input_number.hydroponics_feed_pump_duration`: Feed pump run time in seconds
- `input_select.hydroponics_waste_pump_schedule`: Schedule mode for waste pump
- `input_select.hydroponics_alert_level`: Controls alert verbosity
- `input_datetime.last_fertigation_time`: Tracks last fertigation time

## Script Functions

### fertigation_cycle
Runs a single fertigation cycle
```yaml
service: script.fertigation_cycle
data:
  duration: 15  # seconds
```

### waste_pump_control
Controls the waste water pump
```yaml
service: script.waste_pump_control
data:
  action: "on"  # or "off"
```

### send_hydro_alert
Sends notification alerts
```yaml
service: script.send_hydro_alert
data:
  title: "Alert Title"
  message: "Alert message content"
  priority: "high"  # or "normal" or "low"
  tag: "hydroponics_alert"
```

### generate_hydro_report
Creates a comprehensive system report
```yaml
service: script.generate_hydro_report
```

## Automation Logic

The main automation (`hydroponics.yaml`) uses:

1. **Multiple triggers** for different events (scheduled times, sensor thresholds)
2. **Variables** for real-time parameter values and configuration
3. **Conditional actions** based on specific triggers and conditions
4. **Script calls** to perform modular operations

The automation is designed with a choose/condition/sequence pattern for clarity and troubleshooting.

## Troubleshooting Approach

1. **Check logs** for error messages
2. **Verify entity states** - especially sensor readings
3. **Test scripts** individually to isolate issues
4. **Review trigger conditions** to understand what's activating (or not)
5. **Use the dashboard** to manually trigger operations

Common issues include:
- Sensor inaccuracies
- Pump control failures
- Timing inconsistencies
- Notification failures

## Improvement Areas

For future enhancements, consider:

1. **Additional sensors** (dissolved oxygen, liquid flow rate)
2. **Automated pH/EC adjustment**
3. **Machine learning** for predictive maintenance
4. **Advanced scheduling** (light-dependent, temperature-adaptive)
5. **Energy optimization** (pump efficiency monitoring)
6. **Remote monitoring capabilities** (API integration)
7. **Growing cycle management** (seedling, vegetative, flowering phases)

## Programming Guidelines

When modifying the system:

1. **Maintain modularity** - Use the script system for reusable functions
2. **Document changes** - Update documentation to reflect modifications
3. **Test incrementally** - Test each component before integrating
4. **Follow naming conventions** - Use descriptive variable and entity names
5. **Add logging** - Include appropriate logging for troubleshooting
6. **Consider graceful degradation** - Handle failures and sensor outages
7. **Prioritize reliability** - Plant health depends on consistent operation

## User Experience Considerations

The system was designed for:

1. **Simplicity** - Clean dashboard with clear readings
2. **Configurability** - Adjustable settings via UI
3. **Reliability** - Robust error handling and notifications
4. **Transparency** - Clear reporting on system actions
5. **Low maintenance** - Automated operation with minimal user intervention

When making improvements, maintain these priorities to keep the system user-friendly.