# ESPHome Development Environment

## Current Setup
- **ESPHome Configs**: Located at `/home/dev/workspace/home-assistant-config/esphome/`
- **Integration**: ESPHome addon within Home Assistant
- **Devices**: Multiple ESP32 devices configured (BLE proxies, voice assistants, etc.)

## Existing ESPHome Devices
- M5Stack Atom Echo (voice assistant)
- ESP32 BLE Proxies (kitchen, living room, dining room)
- ESP32 DevKit V4
- XIAO ESP32C6
- Various IoT sensor devices

## Development Considerations
- Currently using Home Assistant ESPHome addon
- Configurations stored in Home Assistant config directory
- Devices configured for BLE proxy, voice assistant, and sensor functions
- Certificate management for secure connections

## Development Environment Options
1. **Current Addon Approach**: ESPHome addon within Home Assistant
2. **Standalone Container**: Dedicated ESPHome container for development
3. **Hybrid Approach**: Development container + production addon