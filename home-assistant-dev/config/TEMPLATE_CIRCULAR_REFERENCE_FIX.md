# CRITICAL FIX: Template Circular Reference
# File: Z:\packages\zwave_led_night_mode.yaml
# Line: ~16

## PROBLEM
The template for `binary_sensor.night_mode_active` contains a circular reference where it references itself in the icon template, causing template loop errors.

## CURRENT PROBLEMATIC CODE (around line 16):
```yaml
icon: >
  {% if is_state('binary_sensor.night_mode_active', 'on') %}
    mdi:weather-night
  {% else %}
    mdi:weather-sunny
  {% endif %}
```

## FIXED CODE:
```yaml
icon: >
  {% set current_time = now().time() %}
  {% set night_start = strptime('22:00:00', '%H:%M:%S').time() %}
  {% set night_end = strptime('07:00:00', '%H:%M:%S').time() %}
  {% if current_time >= night_start or current_time < night_end %}
    mdi:weather-night
  {% else %}
    mdi:weather-sunny
  {% endif %}
```

## COMPLETE TEMPLATE SECTION (for reference):
```yaml
template:
  - binary_sensor:
      - name: "Night Mode Active"
        device_class: motion
        state: >
          {% set current_time = now().time() %}
          {% set night_start = strptime('22:00:00', '%H:%M:%S').time() %}
          {% set night_end = strptime('07:00:00', '%H:%M:%S').time() %}
          {{ current_time >= night_start or current_time < night_end }}
        icon: >
          {% set current_time = now().time() %}
          {% set night_start = strptime('22:00:00', '%H:%M:%S').time() %}
          {% set night_end = strptime('07:00:00', '%H:%M:%S').time() %}
          {% if current_time >= night_start or current_time < night_end %}
            mdi:weather-night
          {% else %}
            mdi:weather-sunny
          {% endif %}
```

## STEPS TO APPLY:
1. Open `Z:\packages\zwave_led_night_mode.yaml` in text editor
2. Locate the template section around line 16
3. Replace the icon template with the fixed version above
4. Save the file
5. Reload Home Assistant YAML configuration
6. Check error logs for template loop resolution

## EXPECTED RESULT:
- Template loop errors eliminated
- Configuration reloads work properly
- Night mode sensor functions correctly with proper icons
