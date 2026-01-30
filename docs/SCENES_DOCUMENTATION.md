# Home Assistant Scene Implementation - Documentation

## Overview
This documentation covers the implementation of activity-based scenes for a smart home with:
- **Full color support**: Kitchen lights (6 RGBCW bulbs + RF LED strips), Living room lights, 2 Zigbee bedside lamps
- **Brightness control**: Z-Wave dimmers and switches throughout the house
- **Alexa voice control**: Native HA scenes exposed to Alexa

---

## File Structure

```
config/
├── configuration.yaml
└── packages/
    ├── scenes_activity.yaml
    └── scenes_alexa.yaml
```

### configuration.yaml
Ensure packages are enabled:

```yaml
homeassistant:
  packages: !include_dir_named packages
```

---

## Package 1: Activity Scenes

**File**: `packages/scenes_activity.yaml`

```yaml
###############################################################################
# Activity-Based Scenes Package
# 
# Organizes lighting by activity type rather than room
# Supports full RGB color in kitchen and living room areas
# All other areas support brightness control
#
# RF LED Strips Note:
# Kitchen LED strips controlled via RM4 Pro (Broadlink)
# Occasionally requires command retry - handled by automation if needed
###############################################################################

scene:
  #############################################################################
  # MORNING ROUTINES
  #############################################################################
  
  - id: good_morning
    name: Good Morning
    icon: mdi:weather-sunny
    entities:
      # Kitchen - Bright cool white for morning energy
      light.kitchen_lights:
        state: on
        brightness: 255
        color_temp: 250  # ~4000K cool white
      light.kitchen_led_strips:
        state: on
        brightness: 255
      
      # Living Room - Comfortable neutral brightness
      light.livingroom_lights:
        state: on
        brightness: 200
        color_temp: 300  # ~3800K neutral white
      
      # Master Bedroom - Soft wake-up lighting
      light.kristy_s_lamp:
        state: on
        brightness: 150
        color_temp: 300
      light.jeremy_s_lamp:
        state: on
        brightness: 150
        color_temp: 300
      light.master_light:
        state: on
        brightness: 180
      
      # Common Areas - Full brightness
      light.dining_dimmer:
        state: on
        brightness: 200
      light.nook_light:
        state: on
        brightness: 180
      light.hall_light:
        state: on
        brightness: 200
      light.porch_light:
        state: on
        brightness: 150
      
      # Other Bedrooms - Off (let occupants control)
      light.hobby_light:
        state: off
      light.gavin_light:
        state: off
      light.linda_light:
        state: off
      light.guest_light:
        state: off

  #############################################################################
  # WORK & FOCUS
  #############################################################################
  
  - id: focused_work
    name: Focused Work
    icon: mdi:desk-lamp
    entities:
      # Kitchen - Bright cool light for clarity
      light.kitchen_lights:
        state: on
        brightness: 220
        color_temp: 250  # Cool white enhances focus
      light.kitchen_led_strips:
        state: on
        brightness: 180
      
      # Living Room - Reduced to minimize distraction
      light.livingroom_lights:
        state: on
        brightness: 100
        color_temp: 350  # Slightly warmer background
      
      # Task Lighting - Maximum for work areas
      light.kristy_s_lamp:
        state: on
        brightness: 255
        color_temp: 250  # Cool white for reading
      light.jeremy_s_lamp:
        state: on
        brightness: 255
        color_temp: 250
      
      # Minimize ambient lighting
      light.dining_dimmer:
        state: off
      light.nook_light:
        state: on
        brightness: 100
      light.hall_light:
        state: on
        brightness: 120
      light.porch_light:
        state: off

  #############################################################################
  # EVENING & RELAXATION
  #############################################################################
  
  - id: evening_relax
    name: Evening Relaxation
    icon: mdi:weather-sunset
    entities:
      # Kitchen - Warm accent lighting
      light.kitchen_lights:
        state: on
        brightness: 100
        color_temp: 400  # ~3200K warm white
      light.kitchen_led_strips:
        state: on
        brightness: 80
      
      # Living Room - Cozy warm ambiance
      light.livingroom_lights:
        state: on
        brightness: 150
        rgb_color: [255, 147, 41]  # Warm amber glow
      
      # Reading Lamps - Comfortable warm light
      light.kristy_s_lamp:
        state: on
        brightness: 180
        color_temp: 400  # Warm for relaxation
      light.jeremy_s_lamp:
        state: on
        brightness: 180
        color_temp: 400
      
      # Common Areas - Dimmed warm lighting
      light.dining_dimmer:
        state: on
        brightness: 100
      light.nook_light:
        state: on
        brightness: 120
      light.hall_light:
        state: on
        brightness: 60
      light.master_light:
        state: on
        brightness: 100
      
      # Exterior - Dim security lighting
      light.porch_light:
        state: on
        brightness: 80

  #############################################################################
  # ENTERTAINMENT
  #############################################################################
  
  - id: movie_time
    name: Movie Time
    icon: mdi:movie-open
    entities:
      # Kitchen - Minimal purple accent (bias lighting)
      light.kitchen_lights:
        state: on
        brightness: 30
        rgb_color: [150, 50, 200]  # Soft purple
      light.kitchen_led_strips:
        state: off
      
      # Living Room - Subtle bias lighting behind screen
      light.livingroom_lights:
        state: on
        brightness: 20
        rgb_color: [100, 30, 150]  # Deep purple/blue
      
      # Lamps - Off to avoid screen glare
      light.kristy_s_lamp:
        state: off
      light.jeremy_s_lamp:
        state: off
      light.master_light:
        state: off
      
      # Path Lighting Only
      light.dining_dimmer:
        state: off
      light.nook_light:
        state: on
        brightness: 20  # Minimal path light
      light.hall_light:
        state: on
        brightness: 30
      
      # All Other Rooms Off
      light.hobby_light:
        state: off
      light.gavin_light:
        state: off
      light.linda_light:
        state: off
      light.guest_light:
        state: off
      light.pantry_light:
        state: off
      light.porch_light:
        state: on
        brightness: 40  # Minimal exterior

  - id: gaming_mode
    name: Gaming Mode
    icon: mdi:controller
    entities:
      # Kitchen - Colorful accent (optional gaming theme)
      light.kitchen_lights:
        state: on
        brightness: 50
        rgb_color: [0, 255, 100]  # Green gaming aesthetic
      light.kitchen_led_strips:
        state: on
        brightness: 40
      
      # Living Room - Moderate bias lighting
      light.livingroom_lights:
        state: on
        brightness: 40
        rgb_color: [0, 150, 255]  # Blue gaming aesthetic
      
      # Everything else similar to movie mode
      light.kristy_s_lamp:
        state: off
      light.jeremy_s_lamp:
        state: off
      light.master_light:
        state: off
      light.dining_dimmer:
        state: off
      light.nook_light:
        state: on
        brightness: 30
      light.hall_light:
        state: on
        brightness: 40

  #############################################################################
  # COOKING & DINING
  #############################################################################
  
  - id: cooking_mode
    name: Cooking Mode
    icon: mdi:chef-hat
    entities:
      # Kitchen - Maximum task lighting
      light.kitchen_lights:
        state: on
        brightness: 255
        color_temp: 250  # Cool white for color accuracy
      light.kitchen_led_strips:
        state: on
        brightness: 255  # Full undercabinet illumination
      
      # Living Room - Background only
      light.livingroom_lights:
        state: on
        brightness: 80
        color_temp: 350
      
      # Dining Area - Prep for meal
      light.dining_dimmer:
        state: on
        brightness: 150
      light.nook_light:
        state: on
        brightness: 100
      
      # Lamps Off (not needed during cooking)
      light.kristy_s_lamp:
        state: off
      light.jeremy_s_lamp:
        state: off
      light.master_light:
        state: off
      
      # Minimal other areas
      light.hall_light:
        state: on
        brightness: 100

  - id: dinner_time
    name: Dinner Time
    icon: mdi:silverware-fork-knife
    entities:
      # Kitchen - Dimmed background
      light.kitchen_lights:
        state: on
        brightness: 60
        color_temp: 400  # Warm inviting
      light.kitchen_led_strips:
        state: on
        brightness: 40
      
      # Dining Area - Warm focused light
      light.dining_dimmer:
        state: on
        brightness: 200
      light.nook_light:
        state: on
        brightness: 180
      
      # Living Room - Warm ambient
      light.livingroom_lights:
        state: on
        brightness: 100
        rgb_color: [255, 160, 80]  # Warm orange glow
      
      # Lamps - Soft ambient lighting
      light.kristy_s_lamp:
        state: on
        brightness: 120
        color_temp: 450  # Very warm
      light.jeremy_s_lamp:
        state: on
        brightness: 120
        color_temp: 450
      
      # Hall - Moderate for movement
      light.hall_light:
        state: on
        brightness: 120

  - id: entertaining_guests
    name: Entertaining
    icon: mdi:party-popper
    entities:
      # Kitchen - Bright and welcoming
      light.kitchen_lights:
        state: on
        brightness: 220
        rgb_color: [255, 200, 150]  # Warm inviting white
      light.kitchen_led_strips:
        state: on
        brightness: 200
      
      # Living Room - Vibrant but comfortable
      light.livingroom_lights:
        state: on
        brightness: 200
        rgb_color: [255, 180, 100]  # Warm festive glow
      
      # Dining Area - Full brightness
      light.dining_dimmer:
        state: on
        brightness: 220
      light.nook_light:
        state: on
        brightness: 200
      
      # Lamps - Accent lighting
      light.kristy_s_lamp:
        state: on
        brightness: 180
        rgb_color: [255, 150, 80]  # Warm accent
      light.jeremy_s_lamp:
        state: on
        brightness: 180
        rgb_color: [255, 150, 80]
      
      # Common Areas - Well lit for guests
      light.master_light:
        state: on
        brightness: 180
      light.hall_light:
        state: on
        brightness: 200
      light.porch_light:
        state: on
        brightness: 255  # Welcome lighting

  #############################################################################
  # BEDTIME ROUTINES
  #############################################################################
  
  - id: goodnight
    name: Goodnight
    icon: mdi:sleep
    entities:
      # All Main Areas Off
      light.kitchen_lights:
        state: off
      light.kitchen_led_strips:
        state: off
      light.livingroom_lights:
        state: off
      light.dining_dimmer:
        state: off
      
      # Lamps Off
      light.kristy_s_lamp:
        state: off
      light.jeremy_s_lamp:
        state: off
      
      # Bedrooms Off
      light.master_light:
        state: off
      light.hobby_light:
        state: off
      light.gavin_light:
        state: off
      light.linda_light:
        state: off
      light.guest_light:
        state: off
      
      # Minimal Night Path Lighting
      light.nook_light:
        state: on
        brightness: 10  # Night light
      light.hall_light:
        state: on
        brightness: 20  # Safety path
      
      # Utility Areas Off
      light.pantry_light:
        state: off
      light.porch_light:
        state: off

  - id: night_feeding
    name: Night Feeding
    icon: mdi:baby-bottle
    entities:
      # Minimal warm lighting for nighttime tasks
      light.kitchen_lights:
        state: on
        brightness: 30
        color_temp: 500  # Very warm red-shifted
      light.kitchen_led_strips:
        state: off
      
      # Path lighting only
      light.hall_light:
        state: on
        brightness: 20
      light.nook_light:
        state: on
        brightness: 15
      
      # One lamp for task lighting
      light.kristy_s_lamp:
        state: on
        brightness: 40
        color_temp: 500  # Red-shifted to preserve night vision
      
      # Everything else off
      light.livingroom_lights:
        state: off
      light.jeremy_s_lamp:
        state: off
      light.master_light:
        state: off
      light.dining_dimmer:
        state: off

  #############################################################################
  # UTILITY SCENES
  #############################################################################
  
  - id: all_lights_on
    name: All Lights On
    icon: mdi:lightbulb-on
    entities:
      # Turn everything on at comfortable brightness
      light.kitchen_lights:
        state: on
        brightness: 200
        color_temp: 300
      light.kitchen_led_strips:
        state: on
        brightness: 200
      light.livingroom_lights:
        state: on
        brightness: 180
        color_temp: 300
      light.kristy_s_lamp:
        state: on
        brightness: 180
        color_temp: 300
      light.jeremy_s_lamp:
        state: on
        brightness: 180
        color_temp: 300
      light.master_light:
        state: on
        brightness: 180
      light.dining_dimmer:
        state: on
        brightness: 180
      light.nook_light:
        state: on
        brightness: 180
      light.hall_light:
        state: on
        brightness: 180
      light.hobby_light:
        state: on
        brightness: 180
      light.gavin_light:
        state: on
        brightness: 180
      light.linda_light:
        state: on
        brightness: 180
      light.guest_light:
        state: on
        brightness: 180
      light.porch_light:
        state: on
        brightness: 180

  - id: all_lights_off
    name: All Lights Off
    icon: mdi:lightbulb-off
    entities:
      # Turn everything off (use for leaving home)
      light.kitchen_lights:
        state: off
      light.kitchen_led_strips:
        state: off
      light.livingroom_lights:
        state: off
      light.kristy_s_lamp:
        state: off
      light.jeremy_s_lamp:
        state: off
      light.master_light:
        state: off
      light.dining_dimmer:
        state: off
      light.nook_light:
        state: off
      light.hall_light:
        state: off
      light.hobby_light:
        state: off
      light.gavin_light:
        state: off
      light.linda_light:
        state: off
      light.guest_light:
        state: off
      light.pantry_light:
        state: off
      light.porch_light:
        state: off
```

---

## Package 2: Alexa Integration

**File**: `packages/scenes_alexa.yaml`

```yaml
###############################################################################
# Alexa Integration Package for Scenes
#
# Exposes Home Assistant scenes to Alexa for voice control
# Requires Home Assistant Cloud (Nabu Casa) or manual Alexa skill setup
#
# Voice Examples:
#   "Alexa, turn on Good Morning"
#   "Alexa, activate Movie Time"
#   "Alexa, turn on Cooking Mode"
###############################################################################

alexa:
  smart_home:
    filter:
      # Include all scenes and lights
      include_domains:
        - scene
        - light
      
      # Exclude technical/utility devices not needed in Alexa
      exclude_entities:
        - light.dev_hobby_light_mqtt
        - light.water_quality_monitor_backlight
        - light.prusa_printer_cam_camera_flash
        - light.smart_garage_door_2202145092509936103148e1e989a111_dnd
        - light.upstairs_motion
        - light.downstairs_motion
        # Exclude unavailable color bulbs
        - light.rgbcw_lightbulb1
        - light.rgbcw_lightbulb2
        - light.rgbcw_lightbulb3
        - light.rgbcw_lightbulb4
        - light.rgbcw_lightbulb5
    
    # Customize how entities appear in Alexa
    entity_config:
      # Morning Routine
      scene.good_morning:
        display_categories: SCENE_TRIGGER
        description: "Bright morning lighting throughout the house"
      
      # Work & Focus
      scene.focused_work:
        display_categories: SCENE_TRIGGER
        description: "Task lighting optimized for productive work"
      
      # Evening & Relaxation
      scene.evening_relax:
        display_categories: SCENE_TRIGGER
        description: "Warm relaxing evening ambiance"
      
      # Entertainment
      scene.movie_time:
        display_categories: SCENE_TRIGGER
        description: "Dim lighting optimized for watching movies or TV"
      
      scene.gaming_mode:
        display_categories: SCENE_TRIGGER
        description: "Lighting setup for gaming sessions"
      
      # Cooking & Dining
      scene.cooking_mode:
        display_categories: SCENE_TRIGGER
        description: "Maximum kitchen task lighting for food preparation"
      
      scene.dinner_time:
        display_categories: SCENE_TRIGGER
        description: "Warm dining atmosphere for meals"
      
      scene.entertaining_guests:
        display_categories: SCENE_TRIGGER
        description: "Welcoming lighting for hosting guests"
      
      # Bedtime
      scene.goodnight:
        display_categories: SCENE_TRIGGER
        description: "Turn off most lights with minimal path lighting"
      
      scene.night_feeding:
        display_categories: SCENE_TRIGGER
        description: "Minimal warm lighting for nighttime tasks"
      
      # Utility
      scene.all_lights_on:
        display_categories: SCENE_TRIGGER
        description: "Turn on all lights at comfortable brightness"
      
      scene.all_lights_off:
        display_categories: SCENE_TRIGGER
        description: "Turn off all lights in the house"
      
      # Customize light groups for better Alexa naming
      light.kitchen_all_lights:
        name: "Kitchen"
        description: "All kitchen lighting including LED strips"
      
      light.kitchen_lights:
        name: "Kitchen Overhead"
        description: "Kitchen color bulbs only"
      
      light.kitchen_led_strips:
        name: "Kitchen Counters"
        description: "Undercabinet LED strips"
      
      light.livingroom_lights:
        name: "Living Room"
        description: "Living room color lights"

###############################################################################
# RF LED Strip Retry Automation
#
# Ensures kitchen LED strips respond reliably to scene activations
# Automatically retries the command if strips don't respond
###############################################################################

automation:
  - id: kitchen_led_strip_scene_retry
    alias: "Kitchen LED Strips - Scene Retry"
    description: "Retry RF command if kitchen LED strips don't respond to scene"
    mode: queued
    max: 5
    
    trigger:
      # Trigger when any scene is activated
      - platform: event
        event_type: call_service
        event_data:
          domain: scene
          service: turn_on
    
    condition:
      # Only proceed if the scene includes kitchen LED strips
      - condition: template
        value_template: >
          {{ 'light.kitchen_led_strips' in trigger.event.data.service_data.entity_id | default([]) }}
    
    action:
      # Wait for strips to process command
      - delay:
          seconds: 2
      
      # Check if strips are in the expected state
      - choose:
          # If scene wanted strips ON but they're OFF
          - conditions:
              - condition: template
                value_template: >
                  {{ states('light.kitchen_led_strips') == 'off' and
                     trigger.event.data.service_data.target.entity_id is defined }}
            sequence:
              # Retry the ON command
              - service: light.turn_on
                target:
                  entity_id: light.kitchen_led_strips
                data:
                  brightness: >
                    {{ state_attr('light.kitchen_led_strips', 'brightness') | default(255) }}
              
              - service: system_log
                data:
                  message: "Retried kitchen LED strips ON command"
                  level: info

# Alternative: Simple script for manual retry if needed
script:
  kitchen_led_retry:
    alias: "Retry Kitchen LED Strips"
    mode: restart
    sequence:
      - service: light.turn_on
        target:
          entity_id: light.kitchen_led_strips
        data:
          brightness: "{{ brightness | default(255) }}"
      - delay:
          milliseconds: 500
      - service: light.turn_on
        target:
          entity_id: light.kitchen_led_strips
        data:
          brightness: "{{ brightness | default(255) }}"
```

---

## Dashboard Configuration

Create a scene control panel in your Lovelace dashboard:

```yaml
###############################################################################
# Dashboard Card Configuration
# Add to your Lovelace YAML or use the UI editor
###############################################################################

type: vertical-stack
cards:
  # Morning & Daily Routines
  - type: horizontal-stack
    cards:
      - type: button
        entity: scene.good_morning
        name: Good Morning
        icon: mdi:weather-sunny
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.good_morning
      
      - type: button
        entity: scene.focused_work
        name: Focused Work
        icon: mdi:desk-lamp
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.focused_work
      
      - type: button
        entity: scene.evening_relax
        name: Evening
        icon: mdi:weather-sunset
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.evening_relax
  
  # Entertainment
  - type: horizontal-stack
    cards:
      - type: button
        entity: scene.movie_time
        name: Movie Time
        icon: mdi:movie-open
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.movie_time
      
      - type: button
        entity: scene.gaming_mode
        name: Gaming
        icon: mdi:controller
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.gaming_mode
  
  # Cooking & Dining
  - type: horizontal-stack
    cards:
      - type: button
        entity: scene.cooking_mode
        name: Cooking
        icon: mdi:chef-hat
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.cooking_mode
      
      - type: button
        entity: scene.dinner_time
        name: Dinner
        icon: mdi:silverware-fork-knife
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.dinner_time
      
      - type: button
        entity: scene.entertaining_guests
        name: Entertaining
        icon: mdi:party-popper
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.entertaining_guests
  
  # Bedtime
  - type: horizontal-stack
    cards:
      - type: button
        entity: scene.goodnight
        name: Goodnight
        icon: mdi:sleep
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.goodnight
      
      - type: button
        entity: scene.night_feeding
        name: Night Mode
        icon: mdi:baby-bottle
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.night_feeding
  
  # Utility Controls
  - type: horizontal-stack
    cards:
      - type: button
        entity: scene.all_lights_on
        name: All On
        icon: mdi:lightbulb-on
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.all_lights_on
      
      - type: button
        entity: scene.all_lights_off
        name: All Off
        icon: mdi:lightbulb-off
        tap_action:
          action: call-service
          service: scene.turn_on
          target:
            entity_id: scene.all_lights_off
```

---

## RGB Color Reference

For easy customization of color scenes:

| Color | RGB Value | Use Case |
|-------|-----------|----------|
| Warm White | `[255, 200, 150]` | Evening, dining |
| Warm Amber | `[255, 147, 41]` | Relaxation |
| Warm Orange | `[255, 160, 80]` | Cozy ambiance |
| Soft Purple | `[150, 50, 200]` | Movie bias lighting |
| Deep Purple | `[100, 30, 150]` | Movie ambiance |
| Blue Gaming | `[0, 150, 255]` | Gaming aesthetic |
| Green Gaming | `[0, 255, 100]` | Gaming aesthetic |
| Red Night | `[255, 50, 20]` | Night vision preservation |

---

## Color Temperature Reference

| Description | Kelvin | Mireds | Use Case |
|-------------|--------|--------|----------|
| Cool White | 5000K | 200 | Energizing, focus work |
| Neutral White | 4000K | 250 | Balanced daytime |
| Warm White | 3000K | 333 | Comfortable evening |
| Very Warm | 2500K | 400 | Relaxing, cozy |
| Extra Warm | 2000K | 500 | Night mode, sleep |

---

## Implementation Steps

1. **Create package files**:
   - `config/packages/scenes_activity.yaml`
   - `config/packages/scenes_alexa.yaml`

2. **Verify configuration**:
   ```bash
   # Check configuration is valid
   Developer Tools > YAML > Check Configuration
   ```

3. **Reload configuration**:
   ```bash
   # Reload without restart
   Developer Tools > YAML > Scenes
   Developer Tools > YAML > Automations
   ```
   Or full restart if needed.

4. **Test scenes locally**:
   - Use Developer Tools > Services
   - Call `scene.turn_on` with each scene
   - Verify lighting behavior

5. **Enable Alexa sync**:
   - If using Home Assistant Cloud: Configuration > Home Assistant Cloud > Alexa > Sync Entities
   - If using manual skill: Trigger discovery in Alexa app

6. **Test voice commands**:
   - "Alexa, discover devices"
   - "Alexa, turn on Good Morning"
   - Test each scene

7. **Add to dashboard**:
   - Settings > Dashboards
   - Add scene control cards

---

## Customization Guide

### Adjusting Brightness Levels
Change brightness values (0-255):
- **Very Dim**: 10-30 (night lighting, path lights)
- **Dim**: 40-80 (ambient, background)
- **Medium**: 100-180 (comfortable living)
- **Bright**: 200-230 (task lighting)
- **Maximum**: 240-255 (precision work)

### Adjusting Color Temperature
Change color_temp values (Mireds):
- **Cool White (5000K)**: `color_temp: 200` - Energizing, focus
- **Neutral White (4000K)**: `color_temp: 250` - Balanced, daytime
- **Warm White (3000K)**: `color_temp: 333` - Comfortable, evening
- **Very Warm (2500K)**: `color_temp: 400` - Relaxing, cozy
- **Extra Warm (2000K)**: `color_temp: 500` - Night mode, sleep

### Adding New Scenes
1. Copy an existing scene block
2. Change the `id` and `name`
3. Modify entity states for your needs
4. Add to Alexa configuration
5. Reload scenes

### Room-Specific Scenes
To add bedroom-specific scenes:
```yaml
- id: bedroom_reading
  name: Bedroom Reading
  icon: mdi:book-open-variant
  entities:
    light.master_light:
      state: on
      brightness: 180
    light.kristy_s_lamp:
      state: on
      brightness: 255
      color_temp: 300
    light.jeremy_s_lamp:
      state: on
      brightness: 100
      color_temp: 400
```

---

## Troubleshooting

### RF LED Strips Not Responding
- Verify `light.kitchen_led_strips` entity exists
- Check RM4 Pro is online: `remote.rm4_pro` state
- Manually test strips from UI
- Enable retry automation (included above)
- Consider adding delay before critical scenes

### Scenes Not Appearing in Alexa
1. Verify Alexa integration in HA
2. Check `configuration.yaml` has `alexa:` section
3. Sync entities in HA Cloud or Alexa app
4. Wait 5 minutes for cloud propagation
5. Say "Alexa, discover devices"

### Colors Not Matching Expectations
- Some bulbs interpret RGB differently
- Use color_temp for consistency when possible
- Test and adjust RGB values per bulb model
- Consider using Kelvin values if supported

### Scene Activation Slow
- Z-Wave mesh may need time to propagate
- Split scenes into sequences if needed
- Use groups to control multiple lights together
- Consider adding transition times

---

## Maintenance

### Regular Updates
- Review scenes seasonally
- Adjust for daylight saving time
- Update when adding new lights
- Refine based on usage patterns

### Best Practices
- Test scenes before adding to production
- Document custom changes
- Keep backup of working configuration
- Use descriptive scene names
- Version control with Git

---

## Advanced: Time-Based Scene Automation

Add automatic scene activation based on time:

```yaml
# Add to packages/scenes_alexa.yaml or separate automation package

automation:
  - id: auto_morning_scene
    alias: "Auto: Morning Scene"
    trigger:
      - platform: sun
        event: sunrise
        offset: "-00:30:00"
    condition:
      - condition: state
        entity_id: person.jeremy
        state: home
      - condition: state
        entity_id: person.kristy
        state: home
    action:
      - service: scene.turn_on
        target:
          entity_id: scene.good_morning

  - id: auto_evening_scene
    alias: "Auto: Evening Scene"
    trigger:
      - platform: sun
        event: sunset
        offset: "00:00:00"
    condition:
      - condition: state
        entity_id: person.jeremy
        state: home
    action:
      - service: scene.turn_on
        target:
          entity_id: scene.evening_relax

  - id: auto_goodnight_scene
    alias: "Auto: Goodnight Scene"
    trigger:
      - platform: time
        at: "23:00:00"
    condition:
      - condition: state
        entity_id: person.jeremy
        state: home
    action:
      - service: scene.turn_on
        target:
          entity_id: scene.goodnight
```

---

## Scene Activity Reference

Quick reference for all included scenes:

| Scene ID | Voice Command | Primary Use | Key Features |
|----------|---------------|-------------|--------------|
| `good_morning` | "Alexa, turn on Good Morning" | Morning wake-up | Bright cool white, energizing |
| `focused_work` | "Alexa, turn on Focused Work" | Productive work | Task lighting, minimal distraction |
| `evening_relax` | "Alexa, turn on Evening Relaxation" | Evening wind-down | Warm amber, comfortable |
| `movie_time` | "Alexa, turn on Movie Time" | Watch TV/movies | Minimal bias lighting, purple accent |
| `gaming_mode` | "Alexa, turn on Gaming Mode" | Gaming sessions | Blue/green accent, moderate brightness |
| `cooking_mode` | "Alexa, turn on Cooking Mode" | Food preparation | Maximum kitchen lighting |
| `dinner_time` | "Alexa, turn on Dinner Time" | Dining | Warm focused dining area |
| `entertaining_guests` | "Alexa, turn on Entertaining" | Hosting guests | Bright welcoming throughout |
| `goodnight` | "Alexa, turn on Goodnight" | Bedtime | Minimal path lighting only |
| `night_feeding` | "Alexa, turn on Night Feeding" | Nighttime tasks | Red-shifted warm minimal |
| `all_lights_on` | "Alexa, turn on All Lights" | Utility | Everything at comfortable level |
| `all_lights_off` | "Alexa, turn off All Lights" | Leaving home | Turn off all lights |

---

## Summary

This documentation provides a complete scene implementation using Home Assistant packages. The configuration:

✅ Organizes 12 activity-based scenes  
✅ Supports full RGB color in kitchen and living room  
✅ Controls brightness for all other areas  
✅ Integrates with Alexa voice control  
✅ Handles RF LED strip reliability  
✅ Provides dashboard controls  
✅ Includes customization guidance  

**Next Steps**: Copy the YAML configurations into your package files, reload, and start using your new scene system!

---

## Appendix: Entity Map

### Color Capable Lights
- `light.kitchen_lights` - 6 RGBCW bulbs (color_temp + RGB)
- `light.kitchen_led_strips` - RF controlled via RM4 Pro (color_temp)
- `light.livingroom_lights` - Color group (color_temp + RGB)
- `light.kristy_s_lamp` - Zigbee lamp (color_temp + XY color)
- `light.jeremy_s_lamp` - Zigbee lamp (color_temp + XY color)

### Brightness Only Lights
- `light.master_light` - Z-Wave dimmer
- `light.hobby_light` - Z-Wave dimmer
- `light.gavin_light` - Z-Wave dimmer
- `light.nook_light` - Z-Wave dimmer
- `light.guest_light` - Z-Wave dimmer
- `light.porch_light` - Z-Wave dimmer
- `light.hall_light` - Z-Wave dimmer
- `light.linda_light` - Z-Wave dimmer
- `light.pantry_light` - Z-Wave dimmer
- `light.dining_dimmer` - Z-Wave dimmer

### Motion Sensors (Available for Automations)
- `light.upstairs_motion`
- `light.downstairs_motion`

---

*Documentation Version 1.0*  
*Created: October 19, 2025*  
*For Home Assistant using Package Configuration*
