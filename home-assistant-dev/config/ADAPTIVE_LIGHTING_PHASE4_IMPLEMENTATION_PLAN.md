# Adaptive Lighting Phase 4 Implementation Plan
*Created: June 25, 2025*

## Executive Summary
Phase 4 implements the Adaptive Lighting Control Center Dashboard and Centralized Temperature & Brightness Control for comprehensive management of all 14 adaptive lighting zones. This builds upon the completed Phase 3 double-click and visual feedback systems.

## Current System Analysis
- **14 zones configured** in adaptive_lighting.yaml
- **Existing dashboard** at dashboards/adaptive_lighting_dashboard.yaml (basic)
- **Master coordinator** automation system active
- **Individual zone controls** via adaptive lighting switches
- **Double-click detection** system operational (Phase 3)

## Implementation Plan

### Part 1: Enhanced Input Helpers (Foundation)
**Estimated Time**: 2-3 hours  
**Risk Level**: Low  
**Files to Modify**: `input_helpers.yaml`

#### New Input Helpers Required:
```yaml
# Master System Controls
input_boolean:
  adaptive_lighting_master_enable:
    name: "Adaptive Lighting Master Enable"
    icon: mdi:brightness-auto
  
input_number:
  # Master Temperature Control (2000K-6500K)
  adaptive_lighting_master_color_temp:
    name: "Master Color Temperature"
    min: 2000
    max: 6500
    step: 100
    unit_of_measurement: "K"
    icon: mdi:thermometer
    
  # Master Brightness Control (0-100%)
  adaptive_lighting_master_brightness:
    name: "Master Brightness"
    min: 0
    max: 100
    step: 5
    unit_of_measurement: "%"
    icon: mdi:brightness-6
    
  # Zone Scaling Factors (per zone 0.5x to 2.0x)
  adaptive_lighting_zone_1_scale:
    name: "Living Room Scale"
    min: 0.5
    max: 2.0
    step: 0.1
    initial: 1.0
  # ... repeat for all 14 zones

input_select:
  # Master Override Mode
  adaptive_lighting_override_mode:
    name: "Override Mode"
    options:
      - "Adaptive"
      - "Manual Override"
      - "Temporary (Auto-restore)"
      - "Persistent"
    initial: "Adaptive"
    
  # Auto-restore Timer
  adaptive_lighting_auto_restore:
    name: "Auto-restore Timer"
    options:
      - "Disabled"
      - "15 minutes"
      - "1 hour"
      - "3 hours"
      - "Next Reset"
    initial: "1 hour"

input_text:
  # System Status Display
  adaptive_lighting_system_status:
    name: "System Status"
    initial: "Adaptive Mode Active"
    max: 255
```

### Part 2: Master Control Automation System
**Estimated Time**: 4-5 hours  
**Risk Level**: Medium  
**Files to Modify**: `automations/adaptive_lighting.yaml`

#### Core Automations to Add:

1. **Master Temperature Control Handler**
   - Triggers on master color temp slider changes
   - Applies to all participating zones proportionally
   - Switches system to manual override mode
   - Updates system status display

2. **Master Brightness Control Handler**
   - Triggers on master brightness slider changes
   - Applies using individual zone scaling factors
   - Maintains proportional relationships between zones
   - Updates override mode status

3. **System Mode Manager**
   - Handles transitions between adaptive and manual modes
   - Manages auto-restore timer functionality
   - Coordinates with existing override detection system
   - Updates status displays and counters

4. **Zone Synchronization Manager**
   - "Sync All Zones" button functionality
   - Applies current master settings to all zones
   - Respects individual zone scaling factors
   - Provides visual feedback during sync

5. **Auto-Restore Timer Handler**
   - Countdown timer functionality
   - Returns to adaptive mode when timer expires
   - Configurable timeout periods
   - User notification of mode changes

### Part 3: Enhanced Dashboard Implementation
**Estimated Time**: 5-6 hours  
**Risk Level**: Medium  
**Files to Modify**: `dashboards/adaptive_lighting_dashboard.yaml`

#### Dashboard Sections to Implement:

1. **Master Control Panel** (Top Priority)
```yaml
# Master Temperature Control
- type: entities
  title: "🌡️ Master Temperature Control"
  entities:
    - entity: input_number.adaptive_lighting_master_color_temp
      name: "Color Temperature"
      icon: mdi:thermometer
    - entity: sensor.circadian_color_temperature
      name: "Adaptive Target"
      icon: mdi:brightness-auto
    # Quick preset buttons
    - entity: script.adaptive_lighting_temp_warm
      name: "Warm (2000K)"
    - entity: script.adaptive_lighting_temp_neutral
      name: "Neutral (4000K)"
    - entity: script.adaptive_lighting_temp_cool
      name: "Cool (6500K)"
    - entity: script.adaptive_lighting_temp_auto
      name: "Auto (Adaptive)"

# Master Brightness Control
- type: entities
  title: "💡 Master Brightness Control"
  entities:
    - entity: input_number.adaptive_lighting_master_brightness
      name: "System Brightness"
    - entity: sensor.circadian_brightness
      name: "Adaptive Target"
    # Quick preset buttons
    - entity: script.adaptive_lighting_brightness_dim
      name: "Dim (25%)"
    - entity: script.adaptive_lighting_brightness_medium
      name: "Medium (50%)"
    - entity: script.adaptive_lighting_brightness_bright
      name: "Bright (75%)"
    - entity: script.adaptive_lighting_brightness_auto
      name: "Auto (Adaptive)"
```

2. **System Status Overview**
```yaml
- type: markdown
  content: |
    ## 🎛️ System Control Center
    
    **Current Mode**: {{ states('input_select.adaptive_lighting_override_mode') }}
    **Participating Zones**: {{ states('sensor.adaptive_lighting_zones_active') }}/14
    **Override Timer**: {% if states('input_select.adaptive_lighting_auto_restore') != 'Disabled' %}{{ states('input_select.adaptive_lighting_auto_restore') }}{% else %}Manual Control{% endif %}
    **Last Sync**: {{ states('input_datetime.adaptive_lighting_last_sync') }}
    
    ### 📊 Current Targets
    **Master Temperature**: {{ states('input_number.adaptive_lighting_master_color_temp') }}K
    **Master Brightness**: {{ states('input_number.adaptive_lighting_master_brightness') }}%
    **Adaptive Target**: {{ states('sensor.circadian_color_temperature') }}K / {{ states('sensor.circadian_brightness') }}%
```

3. **Zone Status Cards** (14 individual zone cards)
```yaml
# Zone 1: Living Room Example
- type: entities
  title: "🛋️ Living Room (Zone 1)"
  entities:
    - entity: switch.adaptive_lighting_living_room
      name: "Adaptive Control"
    - entity: input_number.adaptive_lighting_zone_1_scale
      name: "Brightness Scale"
    - entity: binary_sensor.adaptive_lighting_living_room_override
      name: "Override Status"
    - entity: sensor.adaptive_lighting_living_room_last_sync
      name: "Last Sync"
  footer:
    type: buttons
    entities:
      - entity: script.adaptive_lighting_sync_zone_1
        name: "Sync Zone"
        icon: mdi:sync
      - entity: script.adaptive_lighting_flash_zone_1
        name: "Identify"
        icon: mdi:lightbulb-flash
```

4. **Quick Action Buttons**
```yaml
- type: horizontal-stack
  cards:
    - type: button
      entity: script.adaptive_lighting_sync_all
      name: "Sync All Zones"
      icon: mdi:sync-circle
      tap_action:
        action: call-service
        service: script.adaptive_lighting_sync_all
    - type: button
      entity: script.adaptive_lighting_return_to_adaptive
      name: "Resume Adaptive"
      icon: mdi:brightness-auto
      tap_action:
        action: call-service
        service: script.adaptive_lighting_return_to_adaptive
    - type: button
      entity: script.adaptive_lighting_master_reset
      name: "Reset System"
      icon: mdi:restore
      tap_action:
        action: call-service
        service: script.adaptive_lighting_master_reset
```

### Part 4: Supporting Scripts Implementation
**Estimated Time**: 3-4 hours  
**Risk Level**: Low  
**Files to Modify**: `scripts/adaptive_lighting.yaml`

#### Scripts to Implement:

1. **Master Control Scripts**
   - `adaptive_lighting_sync_all`: Apply master settings to all zones
   - `adaptive_lighting_return_to_adaptive`: Restore adaptive control
   - `adaptive_lighting_master_reset`: Reset system to defaults

2. **Zone Management Scripts**
   - `adaptive_lighting_sync_zone_X`: Sync individual zones (14 scripts)
   - `adaptive_lighting_flash_zone_X`: Identify zones with flash (14 scripts)

3. **Preset Scripts**
   - Temperature presets: warm, neutral, cool, auto
   - Brightness presets: dim, medium, bright, auto

### Part 5: Integration Testing & Validation
**Estimated Time**: 2-3 hours  
**Risk Level**: Medium  
**Testing Requirements**:

1. **Master Control Testing**
   - Verify master temperature control affects all zones
   - Test master brightness with individual zone scaling
   - Validate override mode transitions
   - Check auto-restore timer functionality

2. **Dashboard Functionality Testing**
   - Test all buttons and sliders
   - Verify real-time status updates
   - Check zone identification flash
   - Validate sync operations

3. **Integration Testing**
   - Test with existing Phase 3 double-click system
   - Verify existing automation compatibility
   - Check performance impact
   - Validate manual override detection

## Risk Assessment & Mitigation

### High Risk Items
- **Master control conflicts** with existing automation system
  - Mitigation: Careful coordination with existing master coordinator
  - Testing: Isolated testing environment first

### Medium Risk Items
- **Dashboard complexity** may impact Home Assistant performance
  - Mitigation: Optimize dashboard updates and reduce polling
  - Testing: Monitor system performance metrics

- **Zone scaling calculation** errors affecting light levels
  - Mitigation: Thorough testing of scaling mathematics
  - Testing: Verify all 14 zones with various scaling factors

### Low Risk Items
- **Input helper conflicts** with existing configuration
  - Mitigation: Use unique naming conventions
  - Testing: Configuration validation before deployment

## Implementation Dependencies

### Required Completions Before Start
- ✅ Phase 3 double-click system operational
- ✅ Master coordinator automation functional
- ✅ All 14 zones configured in adaptive_lighting.yaml
- ✅ Existing dashboard structure in place

### External Dependencies
- **Home Assistant version**: 2025.6.3+ (current)
- **Adaptive Lighting integration**: Latest version
- **Lovelace dashboard**: Standard cards (no custom components required)

## Success Criteria

### Functional Requirements
- ✅ Master temperature control affects all participating zones
- ✅ Master brightness control respects individual zone scaling
- ✅ Override mode management works correctly
- ✅ Auto-restore timer functions as specified
- ✅ Zone identification and sync operations work
- ✅ Dashboard provides real-time status updates

### Performance Requirements
- ✅ System response time < 2 seconds for control actions
- ✅ Dashboard load time < 5 seconds
- ✅ No degradation in existing automation performance
- ✅ System health metrics remain stable

### User Experience Requirements
- ✅ Intuitive dashboard layout and controls
- ✅ Clear status indicators and feedback
- ✅ Easy transition between manual and adaptive modes
- ✅ Reliable zone identification and management

## Post-Implementation Tasks

### Documentation Updates
- Update main CLAUDE.md with Phase 4 completion status
- Create user guide for new dashboard features
- Document new automation behaviors and dependencies
- Update troubleshooting guide with Phase 4 scenarios

### Monitoring & Maintenance
- Set up monitoring for new input helpers and automations
- Establish baseline performance metrics
- Create backup of configuration before implementation
- Plan regular testing schedule for master controls

### Future Enhancements (Phase 5 Preparation)
- Voice control integration preparation
- Machine learning data collection setup
- Scene integration planning
- Mobile-responsive dashboard optimization