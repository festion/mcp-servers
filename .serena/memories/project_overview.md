# AprilBrother BLE Gateway Suite - Project Overview

## Project Purpose
This Home Assistant integration suite forwards BLE (Bluetooth Low Energy) data from AprilBrother BLE Gateway V4 devices to Home Assistant's built-in Bluetooth component, providing comprehensive BLE device discovery and management capabilities.

## Key Components

### 1. AB BLE Gateway Integration (Custom Component)
- **Location**: `custom_components/ab_ble_gateway/`
- **Purpose**: Core integration for MQTT forwarding from AprilBrother BLE Gateway V4
- **Features**:
  - Automatic gateway discovery via SSDP
  - MQTT integration with Home Assistant
  - Real-time BLE advertisement processing
  - Validated MQTT settings during setup
  - Service for cleaning failed entries and reconnecting

### 2. Enhanced BLE Discovery Add-on 
- **Location**: `enhanced_ble_discovery/`
- **Purpose**: User-friendly dashboard and management tools for BLE devices
- **Features**:
  - Web-based dashboard for device management
  - Automatic device categorization
  - Signal strength monitoring (RSSI)
  - Device discovery and identification
  - Adaptive scanning intervals based on activity

## Installation Process
1. **HACS Installation**: Install custom component via HACS custom repository
2. **Add-on Installation**: Install Enhanced BLE Discovery add-on through HA add-on store
3. **MQTT Setup**: Configure MQTT integration in Home Assistant
4. **Gateway Configuration**: Set gateway to MQTT mode (connection type 3)

## Target Hardware
- **Primary**: AprilBrother BLE Gateway V4 (ESP32 and NRF52832-based)
- **Protocol**: MQTT for data forwarding
- **Network**: Local network communication via SSDP discovery

## Main Use Cases
- Home automation with BLE sensors (temperature, humidity, motion)
- Device tracking and presence detection
- Smart home device integration (lights, locks, speakers)
- Health device monitoring (fitness trackers, scales)
- Security and monitoring applications

## Repository Structure
- Dual-purpose repository serving both HACS custom component and HA add-on repository
- Dashboard YAML files for different complexity levels
- Comprehensive testing and development tools
- Documentation and setup instructions