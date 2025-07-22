# SCRIPT SERVICE CALL FIX
# File: Z:\scripts.yaml
# Error: "Invalid data for call_service at pos 1: extra keys not allowed @ data['entity_id']"

## PROBLEM
The `test_appliance_announcements` script is using incorrect service call syntax for Alexa Media notifications.

## CURRENT PROBLEMATIC CODE:
```yaml
test_appliance_announcements:
  alias: "Test All Announcements"
  icon: mdi:bullhorn
  description: "Test the appliance notification system - EMERGENCY FIXED VERSION"
  sequence:
    # INCORRECT - Using target with entity_id for notify service
    - service: notify.alexa_media
      continue_on_error: true
      target:
        entity_id: media_player.everywhere
      data:
        message: "Testing appliance announcement system. All devices responding."
        data:
          type: announce
```

## FIXED CODE:
```yaml
test_appliance_announcements:
  alias: "Test All Announcements"
  icon: mdi:bullhorn
  description: "Test the appliance notification system - FIXED VERSION"
  sequence:
    # FIXED - Using correct notify.alexa_media_everywhere service
    - service: notify.alexa_media_everywhere
      continue_on_error: true
      data:
        message: "Testing appliance announcement system. All devices responding."
        data:
          type: announce
    
    # Test mobile notification as fallback
    - service: notify.mobile_app_pixel_9_pro_xl
      data:
        title: "Appliance Test Complete"
        message: "Notification system test completed at {{ now().strftime('%I:%M %p') }}"
    
    # Update status
    - service: input_text.set_value
      data:
        entity_id: input_text.appliance_last_announcement
        value: "System test completed at {{ now().strftime('%H:%M') }}"
```

## ADDITIONAL SCRIPT FIXES NEEDED:

### Fix manual_energy_report script:
```yaml
manual_energy_report:
  alias: "Manual Energy Report"
  icon: mdi:chart-bar
  description: "Generate immediate energy consumption report - FIXED"
  sequence:
    # FIXED - Using correct service call
    - service: notify.alexa_media_everywhere
      continue_on_error: true
      data:
        message: >
          Current appliance energy usage: 
          Dishwasher {{ states('sensor.dishwasher_electric_consumption_w') }} watts.
          Washing machine {{ states('sensor.washing_machine_electric_consumption_w') }} watts.
          {% if states('sensor.dryer_power') not in ['unknown', 'unavailable'] %}
          Dryer {{ states('sensor.dryer_power') }} watts.
          {% endif %}
        data:
          type: announce
```

### Fix reload_appliance_automations script:
```yaml
reload_appliance_automations:
  alias: "Reload Appliance Automations"
  icon: mdi:reload
  description: "Reload all automations and notify of completion - FIXED"
  sequence:
    - service: automation.reload
    
    # FIXED - Using correct service call
    - delay:
        seconds: 2
    - service: notify.alexa_media_everywhere
      continue_on_error: true
      data:
        message: "Appliance automations have been reloaded successfully."
        data:
          type: announce
```

## KEY CHANGES:
1. Changed `service: notify.alexa_media` to `service: notify.alexa_media_everywhere`
2. Removed `target:` section with `entity_id:`
3. Kept `data:` section intact

## STEPS TO APPLY:
1. Open `Z:\scripts.yaml` in text editor
2. Locate the three scripts mentioned above
3. Replace the notify service calls with the fixed versions
4. Save the file
5. Reload scripts in Home Assistant
6. Test the scripts to verify they work without errors

## EXPECTED RESULT:
- Script service call errors eliminated
- Test appliance announcements script works properly
- All notification scripts function correctly
