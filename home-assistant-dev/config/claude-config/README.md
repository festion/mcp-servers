# Home Assistant Configuration Documentation

This directory contains documentation and resources for ongoing management of the Home Assistant configuration. These files are intended to provide continuity across sessions and assist with system understanding.

## Documentation Files

- **SESSION.md** - Overview of the Home Assistant configuration structure and session recovery process
- **HYDROPONICS.md** - Documentation for the hydroponics management system
- **SYSTEM_MAINTENANCE.md** - Information about system maintenance automations and processes
- **COMMANDS.md** - Reference for common commands and script usage examples

## Backups

The `backups/` directory contains copies of critical configuration files:
- `configuration.yaml` - Main configuration file
- `hydroponics.yaml` - Hydroponics automation configuration

## Usage

1. **Session Recovery**: If a session is interrupted, refer to SESSION.md to resume work
2. **System Understanding**: Use these documents to understand the system architecture
3. **Task Management**: Always maintain a todo list to track progress
4. **Command Reference**: Refer to COMMANDS.md for frequently used commands

## Important Notes

1. Never run `sync_home_assistant.sh` (as per CLAUDE.md instructions)
2. Use "context7" for all coding or YAML work (as per CLAUDE.md)
3. Database maintenance should be performed when Home Assistant is stopped

## Session Management

To ensure continuity across sessions:
1. Always create and maintain a todo list
2. Update documentation as changes are made
3. Create backups of modified files
4. Document the current state in SESSION.md