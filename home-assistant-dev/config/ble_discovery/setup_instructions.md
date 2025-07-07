# BLE Discovery Add-on Setup Instructions

The add-on requires specific input helpers to function correctly. You need to add the following to your Home Assistant configuration.

## Option 1: Add to Your Configuration Files

Add these sections to your appropriate configuration files:

### For input_text.yaml:
```yaml
discovered_ble_devices:
  name: Discovered BLE Devices
  initial: '{}'
  max: 1024
  icon: mdi:bluetooth-transfer

selected_ble_device:
  name: Selected BLE Device
  initial: ''
  max: 255
  icon: mdi:bluetooth
  
ble_device_name:
  name: BLE Device Name
  initial: ''
  max: 255
  icon: mdi:rename
  
ble_device_icon:
  name: BLE Device Icon
  initial: 'mdi:bluetooth'
  max: 255
  icon: mdi:pencil
```

### For input_button.yaml (or in configuration.yaml):
```yaml
input_button:
  bluetooth_scan:
    name: Bluetooth Scan
    icon: mdi:bluetooth-search
```

### For input_select.yaml:
```yaml
ble_device_type:
  name: BLE Device Type
  options:
    - presence
    - temperature
    - humidity
    - motion
    - contact
    - button
    - light
    - lock
    - scale
    - wearable
    - speaker
    - other
  initial: presence
  icon: mdi:devices
```

### For input_number.yaml:
```yaml
ble_rssi_threshold:
  name: BLE RSSI Threshold
  min: -100
  max: -40
  step: 1
  initial: -80
  unit_of_measurement: dBm
  icon: mdi:signal
```

## Option 2: Use Helper UI

You can also create these helpers using the Home Assistant UI:
1. Go to Configuration → Helpers
2. Click "Add Helper"
3. Create each helper with the attributes listed above

After adding the helpers, restart Home Assistant and then restart this add-on.
