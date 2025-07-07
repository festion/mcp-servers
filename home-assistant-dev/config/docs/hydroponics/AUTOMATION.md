# Hydroponics Automation System - Technical Documentation

This document provides a detailed technical explanation of the hydroponics automation system's design, components, and internal workings.

## Automation Architecture

The hydroponics management system follows a modular design pattern for maintainability and debugging:

```
┌───────────────────────────────────────┐
│            Main Automation            │
│  (Orchestrates operations based on    │
│       triggers and conditions)        │
└───────────────┬───────────────────────┘
                │
                ▼
┌───────────────────────────────────────┐
│              Scripts                  │
│  (Reusable functions for common       │
│       operations and tasks)           │
└───────────────┬───────────────────────┘
                │
                ▼
┌───────────────────────────────────────┐
│           Input Helpers               │
│  (User-configurable parameters        │
│       for system operation)           │
└───────────────────────────────────────┘
```

## Main Automation

The central automation (`/config/automations/hydroponics.yaml`) controls the entire system using a trigger-based approach:

### Triggers

The automation uses multiple triggers to respond to different events:

```yaml
triggers:
  # Scheduled fertigations
  - platform: time_pattern
    hours: "/{{ states('input_number.hydroponics_fertigation_interval_hours') | int }}"
    id: scheduled_fertigation
  
  # Waste pump schedule
  - platform: time
    at: "06:00:00"
    id: waste_pump_on
  
  - platform: time
    at: "21:00:00"
    id: waste_pump_off
  
  # Water level monitoring
  - platform: numeric_state
    entity_id: sensor.wroommicrousb_reservoir_current_volume
    below: 5
    for:
      minutes: 5
    id: low_water
  
  # Temperature monitoring
  - platform: numeric_state
    entity_id: sensor.wroommicrousb_reservoir_water_temp
    above: 30
    id: high_temp
  
  - platform: numeric_state
    entity_id: sensor.wroommicrousb_reservoir_water_temp
    below: 5
    id: low_temp
  
  # Water quality monitoring
  - platform: template
    id: parameter_change
    value_template: >
      {{ states('sensor.reservoir_ph_change_last_24_hours') | float(0) > 0.4 or 
         states('sensor.reservoir_ec_change_last_24_hours') | float(0) > 0.2 }}
  
  # Daily report
  - platform: time
    at: "08:00:00"
    id: daily_report
```

### Variables

Global variables provide context and configuration values:

```yaml
variables:
  # Status variables
  current_time: "{{ now().strftime('%H:%M:%S') }}"
  water_level: "{{ states('sensor.wroommicrousb_reservoir_water_level') }}"
  water_volume: "{{ states('sensor.wroommicrousb_reservoir_current_volume') }}"
  water_temp: "{{ states('sensor.wroommicrousb_reservoir_water_temp') }}"
  ph_level: "{{ states('sensor.water_quality_monitor_ph') }}"
  ec_level: "{{ states('sensor.water_quality_monitor_electrical_conductivity') }}"
  
  # Configuration settings
  alert_level: "{{ states('input_select.hydroponics_alert_level') }}"
  waste_pump_schedule: "{{ states('input_select.hydroponics_waste_pump_schedule') }}"
  pump_duration: "{{ states('input_number.hydroponics_feed_pump_duration') | int }}"
  
  # Alert flags
  is_daytime: "{{ now().hour >= 7 and now().hour < 22 }}"
  send_notification: "{{ is_daytime or alert_level == 'Verbose' }}"
```

### Condition-Action Blocks

The automation uses a `choose` structure with condition blocks for each type of trigger:

```yaml
choose:
  # FERTIGATION CYCLE
  - conditions:
      - condition: trigger
        id: scheduled_fertigation
    sequence:
      - service: script.fertigation_cycle
        data:
          duration: "{{ pump_duration }}"
  
  # WASTE PUMP CONTROL - MORNING ON
  - conditions:
      - condition: trigger
        id: waste_pump_on
      - condition: template
        value_template: "{{ waste_pump_schedule == '6AM-9PM' or waste_pump_schedule == 'Always On' }}"
    sequence:
      - service: script.waste_pump_control
        data:
          action: "on"
      - service: system_log.write
        data:
          message: "Hydroponics: Waste pump turned on at {{ current_time }}"
          level: info
  
  # Additional condition blocks for other triggers...
```

## Scripts API

The system uses modular scripts (`/config/scripts/hydroponics.yaml`) to perform common operations:

### fertigation_cycle

This script handles the nutrient delivery process:

```yaml
fertigation_cycle:
  alias: Fertigation Cycle
  description: Run a single fertigation cycle for the hydroponics system
  mode: restart
  fields:
    duration:
      name: Pump Duration
      description: How long to run the feed pump in seconds
      default: 15
      selector:
        number:
          min: 5
          max: 60
          unit_of_measurement: seconds
          mode: slider
  sequence:
    - service: switch.turn_on
      target:
        entity_id: switch.tp_link_smart_plug_c82e_feed_pump
    - delay:
        seconds: "{{ duration }}"
    - service: switch.turn_off
      target:
        entity_id: switch.tp_link_smart_plug_c82e_feed_pump
    - service: input_datetime.set_datetime
      target:
        entity_id: input_datetime.last_fertigation_time
      data:
        datetime: "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}"
    - service: esphome.wroommicrousb_set_last_fertigation_time
      data:
        timestamp: "{{ as_timestamp(now()) | int }}"
    - service: notify.mobile_app_pixel_9_pro_xl
      data:
        title: Hydroponics Update
        message: "Fertigation complete at {{ now().strftime('%H:%M') }}!"
```

### waste_pump_control

Controls the waste water removal pump:

```yaml
waste_pump_control:
  alias: Waste Pump Control
  description: Control the hydroponics waste water pump
  mode: single
  fields:
    action:
      name: Action
      description: Turn the pump on or off
      selector:
        select:
          options:
            - "on"
            - "off"
  sequence:
    - service: "switch.turn_{{ action }}"
      target:
        entity_id: switch.tp_link_smart_plug_c82e_waste_pump
```

### send_hydro_alert

Manages notification delivery:

```yaml
send_hydro_alert:
  alias: Send Hydroponics Alert
  description: Send notification alerts for hydroponics system events
  mode: queued
  fields:
    title:
      name: Title
      description: Alert notification title
      required: true
      selector:
        text:
    message:
      name: Message
      description: Alert notification body
      required: true
      selector:
        text:
          multiline: true
    priority:
      name: Priority
      description: Alert priority level
      default: "normal"
      selector:
        select:
          options:
            - "low"
            - "normal"
            - "high"
    notification_id:
      name: Notification ID
      description: Persistent notification ID
      required: false
      selector:
        text:
    tag:
      name: Tag
      description: Mobile notification tag
      default: "hydroponics_alert"
      selector:
        text:
  sequence:
    - service: persistent_notification.create
      data:
        title: "{{ title }}"
        message: "{{ message }}"
        notification_id: "{{ notification_id | default('hydro_alert_' ~ now().strftime('%Y%m%d%H%M%S')) }}"
    - service: notify.mobile_app_pixel_9_pro_xl
      data:
        title: "{{ title }}"
        message: "{{ message }}"
        data:
          tag: "{{ tag }}"
          ttl: 0
          priority: "{{ priority }}"
```

### generate_hydro_report

Creates comprehensive system reports:

```yaml
generate_hydro_report:
  alias: Generate Hydroponics Report
  description: Generate a comprehensive report of hydroponics system status
  mode: single
  sequence:
    - variables:
        water_level: "{{ states('sensor.wroommicrousb_reservoir_water_level') }}"
        volume: "{{ states('sensor.wroommicrousb_reservoir_current_volume') }}"
        avg_volume: "{{ states('sensor.wroommicrousb_average_volume_since_last_fertigation') }}"
        water_temp: "{{ states('sensor.wroommicrousb_reservoir_water_temp') }}"
        ph_level: "{{ states('sensor.water_quality_monitor_ph') }}"
        ec_level: "{{ states('sensor.water_quality_monitor_electrical_conductivity') }}"
        last_fert: "{{ states('sensor.wroommicrousb_last_fertigation_time') }}"
    - service: persistent_notification.create
      data:
        title: "Hydroponics System Report"
        message: >
          ## Hydroponics Status Report
          Generated: {{ now().strftime('%Y-%m-%d %H:%M') }}

          ### Reservoir Stats
          - Water Level: {{ water_level }} cm
          - Current Volume: {{ volume }} L
          - Avg Volume Since Last Fertigation: {{ avg_volume }} L
          - Water Temperature: {{ water_temp }}°C

          ### Water Quality
          - pH Level: {{ ph_level }}
          - EC Level: {{ ec_level }}

          ### System Status
          - Last Fertigation: {{ last_fert }}
        notification_id: "hydro_daily_report"
```

## Helper Entities

The system uses various input helpers to make configuration user-friendly:

### Input Numbers

```yaml
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
```

### Input Selects

```yaml
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
```

### Input Datetime

```yaml
last_fertigation_time:
  name: Last Fertigation Time
  has_date: true
  has_time: true
  icon: mdi:calendar-clock
```

## Flow Diagrams

### Fertigation Cycle Flow

```
┌─────────────────┐    ┌────────────────┐    ┌─────────────────┐
│  Time Pattern   │───>│ Check Interval │───>│  Run Script:    │
│  Trigger        │    │  Condition     │    │ fertigation_cycle│
└─────────────────┘    └────────────────┘    └────────┬────────┘
                                                     │
┌─────────────────┐    ┌────────────────┐    ┌───────▼────────┐
│ Send            │<───│ Update Last    │<───│ Run Feed Pump  │
│ Notification    │    │ Fertigation    │    │ for Duration   │
└─────────────────┘    └────────────────┘    └────────────────┘
```

### Alert System Flow

```
┌─────────────────┐    ┌────────────────┐    ┌─────────────────┐
│ Sensor Trigger  │───>│ Check Alert    │───>│ Determine Alert │
│ (temp, level)   │    │ Level Setting  │    │ Priority        │
└─────────────────┘    └────────────────┘    └────────┬────────┘
                                                     │
┌─────────────────┐    ┌────────────────┐    ┌───────▼────────┐
│ Mobile          │<───│ Create         │<───│ Format Alert   │
│ Notification    │    │ Persistent     │    │ Message        │
└─────────────────┘    │ Notification   │    └────────────────┘
                      └────────────────┘
```

## Extending the System

The modular design makes the system easy to extend:

### Adding New Triggers

To add a new trigger to the main automation:

1. Add a new trigger entry with a unique ID:
   ```yaml
   - platform: state
     entity_id: binary_sensor.new_sensor
     to: 'on'
     id: new_trigger
   ```

2. Add a corresponding condition-action block:
   ```yaml
   - conditions:
       - condition: trigger
         id: new_trigger
     sequence:
       - service: script.your_action
   ```

### Adding New Scripts

To add a new reusable function:

1. Create a new script in `scripts/hydroponics.yaml`:
   ```yaml
   new_hydro_function:
     alias: New Hydro Function
     description: Description of what this does
     mode: single
     fields:
       parameter_name:
         name: Parameter
         description: What this parameter does
         selector:
           text:
     sequence:
       - service: some_service
   ```

2. Call it from the main automation or the dashboard.