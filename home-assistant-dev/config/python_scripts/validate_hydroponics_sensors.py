"""
Hydroponics Sensor Validation Script
This script validates the state of critical hydroponics sensors and creates a report
"""

# This is a Home Assistant Python Script - runs in HA's Python environment
# Access to hass object is automatic in this context

# Define critical sensors
CRITICAL_SENSORS = [
    "sensor.wroommicrousb_reservoir_current_volume",  # Water level
    "sensor.wroommicrousb_reservoir_water_temp",      # Water temperature
    "switch.tp_link_smart_plug_c82e_feed_pump",       # Feed pump
    "switch.tp_link_smart_plug_c82e_waste_pump"       # Waste pump
]

# Define input helpers
INPUT_HELPERS = [
    "input_number.hydroponics_feed_pump_duration",    # Feed pump duration
    "input_datetime.last_fertigation_timestamp"       # Last fertigation time
]

# Create report
report = []
report.append("HYDROPONICS SENSOR VALIDATION REPORT")
report.append("=====================================")
report.append(f"Generated: {hass.states.get('sensor.date_time').state}")
report.append("")
report.append("CRITICAL SENSORS STATUS:")
report.append("------------------------")

# Check critical sensor states
problematic_sensors = []
for sensor_id in CRITICAL_SENSORS:
    sensor = hass.states.get(sensor_id)
    status = "OK"
    details = ""
    
    if sensor is None:
        status = "MISSING"
        problematic_sensors.append(f"{sensor_id}: Entity not found")
    elif sensor.state in ["unavailable", "unknown", ""]:
        status = "UNAVAILABLE"
        problematic_sensors.append(f"{sensor_id}: State is {sensor.state}")
        details = f"Last changed: {sensor.last_changed}"
    
    report.append(f"{sensor_id}: {status}")
    if details:
        report.append(f"  - {details}")
    
    # Add current value for available sensors
    if status == "OK":
        report.append(f"  - Current value: {sensor.state}")
        if sensor_id == "sensor.wroommicrousb_reservoir_current_volume" and float(sensor.state) < 10:
            problematic_sensors.append(f"{sensor_id}: Low water level ({sensor.state}%)")
            report.append(f"  - WARNING: Water level below 10%")

report.append("")
report.append("INPUT HELPERS STATUS:")
report.append("---------------------")

# Check input helpers
for helper_id in INPUT_HELPERS:
    helper = hass.states.get(helper_id)
    status = "OK"
    details = ""
    
    if helper is None:
        status = "MISSING"
        problematic_sensors.append(f"{helper_id}: Entity not found")
    elif helper.state in ["unavailable", "unknown", ""]:
        status = "UNAVAILABLE"
        problematic_sensors.append(f"{helper_id}: State is {helper.state}")
        details = f"Last changed: {helper.last_changed}"
    
    report.append(f"{helper_id}: {status}")
    if details:
        report.append(f"  - {details}")
    
    # Add current value for available helpers
    if status == "OK":
        report.append(f"  - Current value: {helper.state}")

# Check condition templates
report.append("")
report.append("CONDITION VALIDATION:")
report.append("--------------------")

# Check primary safety condition
feed_pump = hass.states.get("switch.tp_link_smart_plug_c82e_feed_pump")
feed_pump_ok = feed_pump is not None and feed_pump.state not in ["unavailable", "unknown", ""]
report.append(f"Feed pump availability: {'OK' if feed_pump_ok else 'FAIL'}")

# Check water level condition
water_level = hass.states.get("sensor.wroommicrousb_reservoir_current_volume")
water_level_value = "unavailable"
water_level_ok = False

if water_level is None:
    water_level_condition = "FAIL - Sensor missing"
elif water_level.state in ["unavailable", "unknown", ""]:
    water_level_condition = "WARNING - Using fallback (assumed OK)"
    water_level_ok = True  # Per automation, this should allow fertigation
else:
    water_level_value = float(water_level.state)
    water_level_ok = water_level_value >= 5
    water_level_condition = f"{'OK' if water_level_ok else 'FAIL'} - Level is {water_level_value}%"

report.append(f"Water level safety check: {water_level_condition}")

# Calculate morning condition result
morning_condition_result = "{{ not volume_available or current_volume >= 10 }}"
volume_available = water_level is not None and water_level.state not in ["unavailable", "unknown", ""]
current_volume = water_level_value if volume_available else "unavailable"
morning_condition_met = not volume_available or (isinstance(current_volume, (int, float)) and current_volume >= 10)

report.append(f"Morning fertigation specific condition: {'OK' if morning_condition_met else 'FAIL'}")
report.append(f"  - Template: {morning_condition_result}")
report.append(f"  - volume_available = {volume_available}")
report.append(f"  - current_volume = {current_volume}")

# Summary
report.append("")
report.append("SUMMARY:")
report.append("--------")
report.append(f"All conditions met for fertigation: {'YES' if feed_pump_ok and water_level_ok and morning_condition_met else 'NO'}")

if problematic_sensors:
    report.append("Issues detected:")
    for issue in problematic_sensors:
        report.append(f"  - {issue}")
else:
    report.append("No issues detected in sensor states.")

# Create persistent notification with report
service_data = {
    "title": "Hydroponics Validation Report",
    "message": "\n".join(report),
    "notification_id": "hydroponics_validation"
}
hass.services.call("persistent_notification", "create", service_data, False)

# Log findings
for line in report:
    logger.info(line)

# Return sensor values for debugging
return {
    "feed_pump_status": "available" if feed_pump_ok else "unavailable",
    "water_level_status": "available" if volume_available else "unavailable",
    "water_level_value": current_volume,
    "morning_condition_met": morning_condition_met,
    "all_conditions_met": feed_pump_ok and water_level_ok and morning_condition_met
}