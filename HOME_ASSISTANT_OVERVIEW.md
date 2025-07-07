# Home Assistant Overview

## Introduction

Home Assistant is an open-source home automation platform that provides unified control over smart home devices, sensors, and services. Our integration includes multiple components for comprehensive smart home management.

## System Architecture

### Core Components
- **Home Assistant Core** - Main automation platform (http://192.168.1.155:8123)
- **MCP Server Integration** - Claude Code connectivity via `hass-mcp-wrapper.sh`
- **BLE Gateway Suite** - Bluetooth Low Energy device integration
- **Z-Wave Network** - Z-Wave device management and troubleshooting

### Network Configuration
- **Primary Instance**: 192.168.1.155:8123
- **Authentication**: Long-lived access tokens
- **Network Access**: Local network with external access capabilities

## Available Integrations

### Device Management
- **[Device Integration](/home-assistant/devices)** - Adding and configuring smart devices
- **[Z-Wave Integration](/home-assistant/zwave)** - Z-Wave device setup and troubleshooting
- **[BLE Gateway Suite](/home-assistant/ble-gateway)** - Bluetooth device connectivity

### Automation & Control
- **[Automation Setup](/home-assistant/automation)** - Creating and managing automations
- **[Dashboard Configuration](/home-assistant/dashboard)** - Custom dashboard creation
- **Scene Management** - Predefined device states and scenarios

## MCP Integration Features

The Home Assistant MCP Server provides:
- **Entity Control** - Turn devices on/off, adjust settings
- **State Monitoring** - Real-time device status and sensor readings
- **Automation Management** - Create, modify, and trigger automations
- **History Access** - Device state history and usage patterns
- **System Information** - Version, health, and diagnostic data

## Key Projects

### HASS AB BLE Gateway Suite
Advanced Bluetooth Low Energy integration for Home Assistant:
- Custom dashboard development
- Device discovery and management
- Integration with existing Home Assistant infrastructure
- Real-time sensor data processing

### Z-Wave LED Troubleshooting
Comprehensive troubleshooting system for Z-Wave LED devices:
- Diagnostic procedures and tools
- Common issue resolution guides
- Network optimization strategies
- Device performance monitoring

## Configuration

### MCP Server Setup
```bash
# Home Assistant MCP wrapper configuration
/home/dev/workspace/hass-mcp-wrapper.sh

# Environment variables
HASS_URL=http://192.168.1.155:8123
HASS_TOKEN=<long-lived-access-token>
```

### Authentication
1. Generate long-lived access token in Home Assistant
2. Configure token in wrapper script
3. Test connectivity with MCP integration
4. Verify tool access and functionality

## Troubleshooting Resources

- **[Common Issues](/troubleshooting/common-issues)** - Frequent problems and solutions
- **[Diagnostic Tools](/troubleshooting/diagnostics)** - Testing and validation tools
- **[Error Resolution](/troubleshooting/error-resolution)** - Step-by-step problem solving

## Development Guidelines

### Best Practices
- Use test tokens during development
- Implement proper error handling
- Follow Home Assistant API guidelines
- Maintain security best practices
- Document custom integrations

### Testing Procedures
1. Verify MCP server connectivity
2. Test entity discovery and control
3. Validate automation functionality
4. Check error handling and recovery
5. Performance and reliability testing