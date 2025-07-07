# Hydroponics Dashboard Documentation

The hydroponics management system includes a dedicated dashboard for monitoring and controlling your hydroponic system. This document provides a detailed overview of the dashboard layout, available features, and customization options.

## Dashboard Layout

The dashboard is organized into multiple tabs to provide both real-time monitoring and historical analysis:

### Overview Tab

The main tab provides a comprehensive view of the current system status and controls.

![Dashboard Overview](https://github.com/home-assistant/example-assets/raw/master/dashboards/hydroponics-example.png)

#### System Status Card

Displays the current values for all critical system metrics:

- **Water Level**: Current water level in centimeters
- **Current Volume**: Calculated reservoir volume in liters
- **Water Temperature**: Current water temperature in °C
- **pH Level**: Current pH reading
- **EC Level**: Current electrical conductivity reading
- **Last Fertigation**: Timestamp of the most recent fertigation cycle
- **Pump Status**: Current state of feed and waste pumps

#### Trend Graphs

Quick-view mini-graphs showing the last 24 hours of data for:

- Water level trends
- Temperature variations
- pH levels
- EC levels

These graphs help identify recent trends or anomalies at a glance.

#### Controls Panel

Interactive controls for managing the system:

- **Fertigation Interval**: Slider to adjust hours between fertigation cycles
- **Feed Pump Duration**: Slider to adjust pump run time in seconds
- **Waste Pump Schedule**: Dropdown to select pump schedule mode
- **Alert Level**: Dropdown to adjust notification verbosity

#### Action Buttons

Quick-access buttons for common operations:

- **Run Fertigation Cycle**: Manually triggers a fertigation cycle
- **Generate System Report**: Creates a comprehensive system report

### History Tab

The history tab provides detailed historical data and analysis tools.

#### Parameter Histories

Individual history graphs for:

- **Water Level History**: 48-hour detailed view
- **Temperature History**: 48-hour detailed view
- **Water Quality History**: Combined 48-hour view of pH and EC

#### Weekly Analysis Chart

A comprehensive chart showing all major parameters over a 7-day period, allowing for:

- Trend identification
- Correlation analysis
- Pattern recognition

## Using the Dashboard

### Monitoring System Health

For daily monitoring:

1. Check the current parameter values in the System Status card
2. Review the trend graphs for any concerning patterns
3. Check the last fertigation time to ensure cycles are running as scheduled

### Making Adjustments

To adjust system settings:

1. Use the sliders/dropdowns in the Controls panel
2. Changes take effect immediately
3. The automation will use the new values for subsequent operations

### Manual Operations

To perform manual operations:

1. Use the "Run Fertigation Cycle" button to trigger an immediate feed cycle
2. The cycle will run for the duration specified in the Feed Pump Duration setting
3. Use the "Generate System Report" button to create an on-demand status report

### Reviewing Historical Data

To analyze system performance:

1. Navigate to the History tab
2. Use the individual parameter graphs for detailed 48-hour analysis
3. Use the weekly trends chart to identify longer-term patterns

## Customization

The dashboard can be customized by editing `/config/dashboards/hydroponics_dashboard.yaml`.

### Adjusting Graph Display

To modify the appearance of graphs:

```yaml
- type: custom:mini-graph-card
  name: Water Level
  entities:
    - entity: sensor.wroommicrousb_reservoir_water_level
      name: Water Level (cm)
  hours_to_show: 24  # Change to desired hours
  points_per_hour: 2  # Adjust resolution
  line_color: "#3498db"  # Change color
  line_width: 2  # Adjust line thickness
```

### Adding Additional Cards

To add new cards, add a new entry to the appropriate section:

```yaml
- type: entities
  title: Additional Metrics
  entities:
    - entity: sensor.new_hydroponic_sensor
      name: New Sensor
```

### Adding Custom Buttons

To add new action buttons:

```yaml
- type: button
  name: Custom Action
  icon: mdi:cog
  tap_action:
    action: call-service
    service: script.your_custom_script
    service_data:
      parameter: value
```

## Technical Information

### Required Custom Cards

The dashboard uses the following custom cards:

- **mini-graph-card**: For compact trend visualization
- **apexcharts-card**: For advanced historical analytics

These can be installed via HACS (Home Assistant Community Store).

### Entity Requirements

The dashboard expects the following entities:

- `sensor.wroommicrousb_reservoir_water_level`
- `sensor.wroommicrousb_reservoir_current_volume`
- `sensor.wroommicrousb_reservoir_water_temp`
- `sensor.water_quality_monitor_ph`
- `sensor.water_quality_monitor_electrical_conductivity`
- `input_datetime.last_fertigation_time`
- `switch.tp_link_smart_plug_c82e_feed_pump`
- `switch.tp_link_smart_plug_c82e_waste_pump`

If your entity IDs differ, update the dashboard configuration accordingly.

### Performance Considerations

- The history tab loads larger datasets and may be slower to render
- Consider adjusting `hours_to_show` and `points_per_hour` if performance is an issue
- The apexcharts card uses data aggregation to improve performance for longer time periods