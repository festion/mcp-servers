#!/bin/bash

# BLE Device Configuration Setup Script for Home Assistant OS

# Fail on any error
set -e

# Ensure Home Assistant configuration directory exists
HASS_CONFIG="/config"
if [[ ! -d "$HASS_CONFIG" ]]; then
    echo "Home Assistant configuration directory not found!"
    exit 1
fi

# Function to safely update configuration
update_config() {
    local file="$1"
    local content="$2"
    local temp_file=$(mktemp)
    
    # If file doesn't exist, create it
    if [[ ! -f "$file" ]]; then
        echo "$content" > "$file"
        echo "Created $file"
        return
    fi

    # Read existing content
    cat "$file" > "$temp_file"
    
    # Append new content if not already present
    if ! grep -qF "$content" "$file"; then
        echo "$content" >> "$temp_file"
        mv "$temp_file" "$file"
        echo "Updated $file"
    else
        rm "$temp_file"
    fi
}

# Ensure scripts directory exists
mkdir -p "$HASS_CONFIG/scripts"

# 1. Update input_helpers.yaml
INPUT_HELPERS_FILE="$HASS_CONFIG/input_helpers.yaml"
INPUT_HELPERS_CONTENT="
# BLE Device Management Input Helpers
input_text:
  ble_device_name:
    name: BLE Device Name
    icon: mdi:tag-text

  ble_device_mac:
    name: BLE Device MAC Address
    icon: mdi:bluetooth
    pattern: \"^([0-9A-Fa-f]{2}[:-]?){5}([0-9A-Fa-f]{2})$\"

input_select:
  ble_device_type:
    name: BLE Device Type
    options:
      - presence
      - temperature
      - other
    initial: presence
    icon: mdi:devices

  ble_device_icon:
    name: BLE Device Icon
    options:
      - Car (mdi:car)
      - Phone (mdi:cellphone)
      - Watch (mdi:watch)
      - Tag (mdi:tag)
      - Sensor (mdi:access-point)
      - Thermometer (mdi:thermometer)
      - Bluetooth (mdi:bluetooth)
    initial: Car (mdi:car)
    icon: mdi:format-list-bulleted

input_number:
  ble_rssi_threshold:
    name: RSSI Threshold
    min: -100
    max: -40
    step: 1
    initial: -80
    unit_of_measurement: dBm
    icon: mdi:signal-variant
"
update_config "$INPUT_HELPERS_FILE" "$INPUT_HELPERS_CONTENT"

# 2. Update templates.yaml for BLE tracking
# This section has been removed as it referenced the AB_BLE gateway integration
# If you need BLE tracking templates, please use the Bermuda BLE integration instead
# No changes will be made to templates.yaml by this script

# 3. Create a script for BLE Device Management
SCRIPTS_FILE="$HASS_CONFIG/scripts.yaml"
SCRIPTS_CONTENT='

# Optional: BLE Device Scan Script
scan_bluetooth_devices:
  alias: Scan for Bluetooth Devices
  sequence:
    - service: button.press
      target:
        entity_id: button.bluetooth_scan
    - delay: 
        seconds: 3
    - service: persistent_notification.create
      data:
        title: "Bluetooth Scan"
        message: "Scan for Bluetooth devices completed"
'
update_config "$SCRIPTS_FILE" "$SCRIPTS_CONTENT"

# 4. Shell Command for Adding BLE Devices
SHELL_COMMAND_FILE="$HASS_CONFIG/shell_command.yaml"
SHELL_COMMAND_CONTENT='
add_ble_device: >
  python3 /config/scripts/add_ble_device.py 
  /config/templates.yaml 
  "{{ device_name }}" 
  "{{ mac_address }}" 
  "{{ device_type }}" 
  "{{ rssi_threshold }}" 
  "{{ icon }}"
'
update_config "$SHELL_COMMAND_FILE" "$SHELL_COMMAND_CONTENT"

# 5. Create add_ble_device.py script
ADD_BLE_DEVICE_SCRIPT="$HASS_CONFIG/scripts/add_ble_device.py"
ADD_BLE_DEVICE_CONTENT='#!/usr/bin/env python3
import sys
import yaml
import os

def update_templates(template_file, device_name, mac_address, device_type, rssi_threshold, icon):
    # Ensure file exists and is readable/writable
    if not os.path.exists(template_file):
        print(f"Template file {template_file} does not exist!")
        sys.exit(1)

    # Read existing templates
    with open(template_file, "r") as f:
        templates = yaml.safe_load(f) or []

    # Normalize device name and create unique identifiers
    safe_device_name = device_name.lower().replace(" ", "_")
    
    # Check if device already exists
    for item in templates:
        if "sensor" in item:
            for sensor in item["sensor"]:
                if sensor.get("unique_id") == f"{safe_device_name}_rssi_from_json":
                    print(f"Device {device_name} already exists.")
                    return

    # This script has been modified to remove AB_BLE gateway references
    # Please use the Bermuda BLE integration for BLE device tracking
    print("Note: This script has been modified to remove AB_BLE gateway references.")
    print("Please use the Bermuda BLE integration for BLE device tracking.")
    
    # Create placeholder entries that direct to Bermuda
    new_sensor = {
        "name": f"{device_name} RSSI Placeholder",
        "unique_id": f"{safe_device_name}_rssi_placeholder",
        "icon": "mdi:bluetooth",
        "state": "See Bermuda BLE integration",
    }
    
    new_binary_sensor = {
        "name": f"{device_name} Presence Placeholder",
        "unique_id": f"{safe_device_name}_presence_placeholder",
        "device_class": "presence",
        "state": "off",
        "icon": "mdi:bluetooth-off"
    }

    # Append to templates
    templates.append({"sensor": [new_sensor]})
    templates.append({"binary_sensor": [new_binary_sensor]})

    # Write back to file
    with open(template_file, "w") as f:
        yaml.safe_dump(templates, f, default_flow_style=False)

    print(f"Added BLE device {device_name}")

if __name__ == "__main__":
    if len(sys.argv) != 6:
        print("Usage: add_ble_device.py template_file device_name mac_address device_type rssi_threshold icon")
        sys.exit(1)

    update_templates(*sys.argv[1:])
'
echo "$ADD_BLE_DEVICE_CONTENT" > "$ADD_BLE_DEVICE_SCRIPT"
chmod +x "$ADD_BLE_DEVICE_SCRIPT"

echo "BLE Device Configuration Setup Complete!"
echo "Please restart Home Assistant to apply changes."
exit 0
'
