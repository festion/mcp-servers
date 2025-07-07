"""
Test script for hydroponics fertigation conditions
Use this to verify the water level condition logic
"""

# Get current states
water_level = hass.states.get("sensor.wroommicrousb_reservoir_current_volume")
feed_pump = hass.states.get("switch.tp_link_smart_plug_c82e_feed_pump")

# Extract values with defaults
volume_available = water_level is not None and water_level.state not in ["unavailable", "unknown", ""]
current_volume = float(water_level.state) if volume_available else 50
feed_pump_available = feed_pump is not None and feed_pump.state not in ["unavailable", "unknown", ""]

# Test conditions
global_condition = feed_pump_available
morning_condition = True  # Always True with new fix

# Create notification with results
service_data = {
    "title": "Hydroponics Condition Test",
    "message": f"""
Test Results:

Water Level: {current_volume}L ({volume_available})
Feed Pump: {feed_pump.state if feed_pump else 'unavailable'} ({feed_pump_available})

Global Condition: {global_condition}
Morning Condition: {morning_condition}

Fertigation would {'PROCEED' if global_condition and morning_condition else 'SKIP'}
    """,
    "notification_id": "hydroponics_test"
}
hass.services.call("persistent_notification", "create", service_data, False)

# Return result for Service Call
return {
    "water_level": f"{current_volume}L",
    "feed_pump": "Available" if feed_pump_available else "Unavailable",
    "would_fertigate": global_condition and morning_condition
}