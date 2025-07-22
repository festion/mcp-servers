# Alexa Entity Cleanup Instructions

Follow these steps to clean up the Alexa entity configuration:

1. Go to **Configuration** > **Integrations** in the Home Assistant UI
2. Find and click on the **Alexa** integration
3. Click on **Configure**
4. Select the **Manage Entities** tab
5. Look for entities that frequently show in the logs with errors like:
   - binary_sensor.kitchen_room_dishwasher_door_kitchen_room_dishwasher_door_door_state_simple
   - binary_sensor.front_door_sensor_front_door_sensor_door_state_simple
   - binary_sensor.eye_of_sauron_eye_of_sauron_cover_status
   - sensor.cure_a_tron_temperature
   - binary_sensor.front_door_lock_current_status_of_the_door
   - binary_sensor.front_door_sensor_front_door_sensor_cover_status
   - Any other entities showing the "NO_SUCH_ENDPOINT" error in the logs
6. For each of these entities:
   - Set **Expose** to **No**
   - Or click the **trash can icon** to remove the entity completely if it no longer exists
7. Click **Save** to apply the changes

This will prevent Alexa from trying to report states for entities that don't exist or aren't properly configured.