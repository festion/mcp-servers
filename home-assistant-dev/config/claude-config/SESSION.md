# Home Assistant Configuration Documentation

## Session Documentation
This document serves as a reference point for tracking our work and ensuring session continuity in case of crashes or disconnects.

## System Overview
Home Assistant is configured with the following structure:

- **Main Configuration**: `/config/configuration.yaml`
- **Automations**: 
  - GUI automations: `/config/automations.yaml`
  - YAML automations: `/config/automations/` (directory)
- **Scripts**: 
  - Core scripts: `/config/scripts.yaml`
  - Extended scripts: `/config/scripts/` (directory)
- **Custom Components**: `/config/custom_components/` (various integrations)
- **Dashboards**: `/config/dashboards/` (includes hydroponics dashboard)
- **Input Configurations**: Various files for input_text, input_select, etc.

## Special Systems

### Hydroponics Management System
A comprehensive automation solution for managing hydroponics operations:
- Scripts in `/config/scripts/hydroponics.yaml`
- Configuration helpers in input config files
- Main automation in `/config/automations/hydroponics.yaml`
- Dashboard interface in `/config/dashboards/hydroponics_dashboard.yaml`

### Key Configuration Files
- `configuration.yaml`: Main configuration file
- `automations/`: Directory containing YAML automations
- `scripts/`: Directory containing organized scripts
- `custom_components/`: Contains custom integrations and HACS components

## Session Recovery Process
If a session crashes:
1. Review this document and the TODO list
2. Check the last completed tasks
3. Resume work from the last checkpoint
4. Verify configuration integrity before making changes

## Special Instructions
- Never run `sync_home_assistant.sh` (as per CLAUDE.md)
- Use "context7" for all coding or YAML work (as per CLAUDE.md)
- Database maintenance should be performed when HA is stopped

## Testing Commands
- Custom component tests: `pytest custom_components/<component_name>/test`
- Custom component validation: `bash -c "cd custom_components/<component_name> && hacs validate"`