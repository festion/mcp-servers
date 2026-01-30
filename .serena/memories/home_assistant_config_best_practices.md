# Home Assistant Configuration Best Practices

## Multi-Device Targeting Strategy

When targeting multiple devices in automations, scripts, or service calls, follow this hierarchy:

### 1. **Use Labels/Tags** (Preferred for multi-device operations)
When a built-in group doesn't exist or doesn't support the required services:
- Create semantic labels like "blinds", "outdoor_lights", "bedroom_sensors"
- Use `label_id` in service call targets
- Benefits: Dynamic, easy to modify via UI, works with all service types

**Example:**
```yaml
script:
  morning_routine_windows:
    sequence:
      - service: cover.set_cover_position
        target:
          label_id: blinds  # Targets all entities with "blinds" label
        data:
          position: 50
```

### 2. **Use Areas** (Good for location-based operations)
When devices are logically grouped by physical location:
- Use `area_id` for room-based operations
- Best for "turn off all lights in living room" type operations

**Example:**
```yaml
action:
  - service: light.turn_off
    target:
      area_id: living_room
```

### 3. **Use Entity Lists** (Fallback/Explicit control)
When you need explicit control or immediate fix without UI changes:
- List entities directly in `entity_id`
- More maintainable than groups for operations requiring specific services

**Example:**
```yaml
action:
  - service: cover.set_cover_position
    target:
      entity_id:
        - cover.blind_tilt_1
        - cover.blind_tilt_2
        - cover.blind_tilt_3
        - cover.blind_tilt_4
    data:
      position: 50
```

### ⚠️ **Group Limitations**
Not all group platforms support all services:
- `cover.group` only supports: `open_cover`, `close_cover`, `stop_cover`
- `cover.group` does **NOT** support: `set_cover_position`, `set_cover_tilt_position`
- For positional control of multiple covers, use labels or entity lists instead

## Package Organization (Strongly Preferred)

### Why Use Packages
- **Encapsulation**: All related entities in one file
- **Maintainability**: Easy to find and modify related configuration
- **Portability**: Can move entire feature sets between installations
- **Version Control**: Easier to track changes to complete features

### Package Structure
```
packages/
├── window_coverings.yaml      # Covers + automations + scripts + scenes
├── lighting_control.yaml      # Lights + automations + schedules
├── climate_control.yaml       # Thermostats + sensors + automations
├── security_system.yaml       # Alarms + cameras + notifications
└── appliance_monitoring.yaml  # Smart plugs + energy + notifications
```

### Package Contents
Each package should contain ALL related configuration:
- Platform entities (covers, lights, sensors, etc.)
- Input helpers (input_boolean, input_number, input_text)
- Template sensors and binary sensors
- Automations specific to the feature
- Scripts for common operations
- Scenes for preset states
- Customizations for UI appearance

### Package Example Structure
```yaml
# packages/window_coverings.yaml

# Cover entities
cover:
  - platform: group
    name: All Blinds
    entities: [...]

# Input helpers
input_number:
  blinds_preset_position:
    name: Blinds Preset Position
    [...]

# Scripts
script:
  blinds_open:
    alias: "Open All Blinds"
    sequence: [...]

# Automations
automation:
  - id: morning_blinds_schedule
    alias: "Morning Blinds Schedule"
    trigger: [...]
    action: [...]

# Template sensors
template:
  - sensor:
      - name: "Blinds Average Position"
        state: >
          {% set blinds = [...] %}
          [...]

# Customizations
homeassistant:
  customize:
    cover.all_blinds:
      friendly_name: "All Blinds"
      icon: mdi:blinds
```

### When NOT to Use Packages
- Single entities without related automation/scripts
- Quick testing or prototyping
- Entities that need to be in main config for technical reasons

## Migration Strategy

### Moving to Labels
1. **Audit existing groups**: Identify groups used only for service targeting
2. **Create semantic labels**: "blinds", "outdoor_lights", "smart_plugs"
3. **Assign labels via UI**: Entity → Settings → Labels
4. **Update automations**: Replace `entity_id: group.xyz` with `label_id: xyz`
5. **Test thoroughly**: Verify all automations still work
6. **Remove obsolete groups**: Clean up groups no longer needed

### Consolidating to Packages
1. **Identify related entities**: Group by feature, not entity type
2. **Create package file**: `packages/feature_name.yaml`
3. **Move all related config**: Entities, helpers, automations, scripts
4. **Test in dev environment**: Reload config, test all functionality
5. **Deploy via CI/CD**: Use version control workflow
6. **Document in package**: Add comments explaining feature purpose

## Configuration Loading

Enable packages in `configuration.yaml`:
```yaml
homeassistant:
  packages: !include_dir_named packages
```

This allows all `.yaml` files in `packages/` directory to be loaded as complete configuration units.

## Version Control Best Practices

- **Commit packages atomically**: One feature per commit
- **Descriptive commit messages**: "Add window covering automation package"
- **Test before production**: Always test package changes in dev environment
- **Use CI/CD**: Never modify production config directly
- **Document breaking changes**: Note when packages require specific HA versions

## Related Errors to Avoid

### Service Not Supported on Groups
```
Error: Entity cover.all_blinds does not support action cover.set_cover_position
```
**Solution**: Use labels or entity lists for positional services

### Incorrect Target Format
```yaml
# Wrong
service: cover.set_cover_position
entity_id: cover.blind_1
data:
  position: 50

# Correct
service: cover.set_cover_position
target:
  entity_id: cover.blind_1
data:
  position: 50
```

### Group vs Label Confusion
- **Groups**: Create new entities that aggregate state
- **Labels**: Tags for targeting existing entities
- Use groups for state representation, labels for bulk operations
