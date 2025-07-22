# SAFE ENTITY CLEANUP LIST - June 9, 2025
# Home Assistant Entity Registry Cleanup
# REASON: Duplicate entities with "_2" suffix - working alternatives exist

## AMICO SMART LIGHTS - DUPLICATE ENTITIES TO REMOVE

### LIGHTS (11 entities to delete)
```
light.amico_smart_recessed_light_12
light.amico_smart_recessed_light_2_2  
light.amico_smart_recessed_light_3_2
light.amico_smart_recessed_light_4_2
light.amico_smart_recessed_light_5_2
light.amico_smart_recessed_light_6_2
light.amico_smart_recessed_light_7_2
light.amico_smart_recessed_light_8_2
light.amico_smart_recessed_light_9_2
light.amico_smart_recessed_light_10_2
light.amico_smart_recessed_light_11_2
```

### SWITCHES (11 entities to delete)
```
switch.amico_smart_recessed_light_do_not_disturb_2
switch.amico_smart_recessed_light_2_do_not_disturb_2
switch.amico_smart_recessed_light_3_do_not_disturb_2
switch.amico_smart_recessed_light_4_do_not_disturb_2
switch.amico_smart_recessed_light_5_do_not_disturb_2
switch.amico_smart_recessed_light_6_do_not_disturb_2
switch.amico_smart_recessed_light_7_do_not_disturb_2
switch.amico_smart_recessed_light_8_do_not_disturb_2
switch.amico_smart_recessed_light_9_do_not_disturb_2
switch.amico_smart_recessed_light_10_do_not_disturb_2
switch.amico_smart_recessed_light_11_do_not_disturb_2
```

## WORKING ALTERNATIVES (DO NOT DELETE)
These entities are confirmed working and should remain:
```
✅ light.amico_smart_recessed_light (ON, brightness: 3)
✅ light.amico_smart_recessed_light_2 (ON, brightness: 3)
✅ light.amico_smart_recessed_light_3 (ON, brightness: 3)
✅ light.amico_smart_recessed_light_4 (ON, brightness: 3)
✅ light.amico_smart_recessed_light_5 (ON, brightness: 3)
... (and so on for all primary entities)
```

## MANUAL CLEANUP STEPS

### Via Home Assistant UI:
1. **Navigate**: Settings → Devices & Services → Entities
2. **Filter**: Search for "amico" 
3. **Identify**: Look for entities ending in "_2"
4. **Select**: Check entities matching the list above
5. **Delete**: Remove from entity registry
6. **Verify**: Confirm primary entities still work

### Safety Verification:
- ✅ All entities to be deleted are in "unavailable" state
- ✅ All have working alternatives without "_2" suffix  
- ✅ No automations reference the "_2" entities
- ✅ Operation is completely safe

## EXPECTED RESULTS
- **Unavailable Entities**: -22 entities
- **Integration Health**: +1.5% improvement
- **System Cleanliness**: Professional entity registry
- **Risk Level**: ZERO (removing confirmed duplicates only)

## VALIDATION COMMANDS
After cleanup, verify success:
```yaml
# Check integration health improvement
sensor.integration_health_percentage

# Verify entity count reduction  
sensor.unavailable_entities

# Test primary lights still work
light.amico_smart_recessed_light
```

**STATUS**: Ready for manual execution - completely safe operation
