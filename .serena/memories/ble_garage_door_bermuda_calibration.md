# BLE Garage Door and Bermuda Calibration

## System Overview
- **BLE Garage Door Automation**: Uses April Brother MQTT BLE gateway to detect car beacons via RSSI thresholds
- **Bermuda BLE Trilateration**: Provides room-level presence detection using multiple ESPHome BLE proxies
- **Garage Door**: Meross Smart Garage Door entity `cover.smart_garage_door_2202145092509936103148e1e989a111_garage`

## BLE Garage Door Configuration

### RSSI Sensors (April Brother Gateway)
- **Topic**: `xbg` (MQTT)
- **Sensors**:
  - `sensor.driveway_car_1_rssi` - Car 1 RSSI (MAC: D0E29D3E51BA)
  - `sensor.driveway_car_2_rssi` - Car 2 RSSI  
  - `sensor.driveway_car_3_rssi` - Car 3 RSSI (currently unconfigured)

### Car Presence Detection
- **Binary Sensors**: `binary_sensor.car_1_present`, `binary_sensor.car_2_present`, `binary_sensor.car_3_present`
- **Logic**: `{{ rssi >= threshold }}` (e.g., -90 >= -100 = true)
- **Thresholds**: 
  - `input_number.ble_car1_rssi_threshold` (default: -100 dBm)
  - `input_number.ble_car2_rssi_threshold` (default: -100 dBm)
  - `input_number.ble_car3_rssi_threshold` (default: -100 dBm)
- **Car Count**: `sensor.driveway_cars_present_3` (correct sensor, counts present cars)

### Configuration Files
- **Main Package**: `/home/dev/workspace/home-assistant-config/packages/ble_garage_door.yaml`
- **MQTT Sensors**: `/home/dev/workspace/home-assistant-config/mqtt.yaml`
- **Dashboard**: `/home/dev/workspace/home-assistant-config/dashboards/ble_garage_door_dashboard.yaml`

### Important Notes
- RSSI threshold values persist across restarts via Home Assistant storage
- Initial threshold value is -100 dBm (configurable per car via UI)
- Automation currently **DISABLED** via `input_boolean.ble_garage_automation` for testing
- Car 3 MAC address cleared (beacon being used for Bermuda calibration testing)

## Bermuda BLE Trilateration System

### Active BLE Proxies (ESPHome)
1. **XIAO BLE Proxy 1** - Living Room (`sensor.xiao_ble_proxy1_uptime`)
2. **XIAO BLE Proxy 2** - Dining Room (`sensor.xiao_ble_proxy2_uptime`)
3. **XIAO BLE Proxy 3** - Kitchen (`sensor.xiao_ble_proxy3_uptime`)
4. **Master Room BLE Proxy 1** (`sensor.masterroom_ble_proxy1_uptime`)
5. **Master Room BLE Proxy 2** (`sensor.masterroom_ble_proxy2_7a4954_uptime`)
6. **Gavin Room BLE Proxy** (`sensor.gavinroom_ble_proxy_4fb0d0_uptime`)
7. **Linda Room BLE Proxy** (`sensor.lindaroom_ble_proxy_uptime`)
8. **Guest Room BLE Proxy** (`sensor.guestroom_ble_proxy_uptime`)
9. **Hobby Room BLE Proxy** (`sensor.hobbyroom_ble_proxy_88446c_uptime`)

### Bermuda Statistics
- **Total Devices Tracked**: 131 BLE devices (all ever seen)
- **Currently Visible**: 92 devices (actively detected)
- **Configured Entities**: Only 2 devices have full Home Assistant entities created
  - April Beacon N06 (device ID: `b5b182c7eab14988aa99b5c1517008d9_1_30306`, MAC: EE:C3:CA:48:62:76)
  - One other device (`bermuda_54e2dd2e21724a869b60736a51dd979b_100_40004`)

### Test Beacon Configuration
- **Device**: April Beacon N06 push button iBeacon
- **MAC Address**: EE:C3:CA:48:62:76
- **Bermuda Device ID**: b5b182c7eab14988aa99b5c1517008d9_1_30306
- **Entities**:
  - `sensor.b5b182c7eab14988aa99b5c1517008d9_1_30306_distance` (distance in feet)
  - `sensor.b5b182c7eab14988aa99b5c1517008d9_1_30306_area` (current area/room)
  - `device_tracker.b5b182c7eab14988aa99b5c1517008d9_1_30306_bermuda_tracker` (presence tracker)
  - `number.b5b182c7eab14988aa99b5c1517008d9_1_30306_calibration_ref_power_at_1m_0_for_default` (calibration)

### Calibration Notes

#### Reference Power Calibration
- **Purpose**: Sets expected signal strength at 1 meter distance
- **Default**: 0 dBm (works for most devices)
- **Tested Values**:
  - 0 dBm: 2.3 ft reading at 3.3 ft actual (close range, master room)
  - -35 dBm: 2.6 ft reading at 3 ft actual (very accurate, canna closet)
  - -55 dBm: Caused sensor to go "unknown" (too extreme, don't use)
  - -20 dBm: 2.3 ft reading (no significant change from 0 dBm)

#### Attenuation (Global Setting)
- **Purpose**: Controls signal falloff rate over distance
- **Default**: ~3.0 (assumes minimal obstacles)
- **For Better Long-Range**: Increase to 4.0-5.0 for environments with walls
- **Location**: Bermuda integration settings (not per-device)
- **Note**: Could not locate this setting via API, must be configured via UI

#### Bermuda Behavior
- **Area Switching**: Uses hysteresis - doesn't instantly switch to prevent flapping
- **Signal Averaging**: RSSI values are averaged over time for stability
- **Room Detection**: Excellent for room-level presence, less accurate for exact distance
- **Beacon Reactivation**: April Beacon N06 may need button press after going idle

### Calibration Test Results
1. **1 meter from Master BLE Proxy 2**: 2.3 ft (acceptable, within 1 ft margin)
2. **3 feet from Canna Closet proxy**: 2.6 ft (very accurate)
3. **3 feet from Kitchen proxy**: Showed 42 ft initially (was still locked to master_room)
4. **15 meters away**: Sensor went "unknown" after extreme Reference Power adjustment

### Known Issues
- Extreme Reference Power values (-55 dBm or lower) can cause sensor to stop functioning
- Requires button press to reactivate April Beacon N06 after going idle
- Area switching can take 15-30 seconds when moving between rooms
- Bermuda prefers strongest signal proxy, which may not always be physically closest

## Duplicate Sensor Cleanup (Completed)
- Removed duplicate "Driveway Cars Present" sensor from `templates.yaml` (was checking wrong entities)
- Dashboard updated to reference correct sensor: `sensor.driveway_cars_present_3`
- Old unavailable sensors deleted from entity registry

## Globe G1 Litter Box Integration (Completed Previously)
- Uses same notification script pattern as BLE garage door
- Alexa announcements working correctly
- Located in:
  - `/home/dev/workspace/home-assistant-config/scripts/globe_g1_litter_box.yaml`
  - `/home/dev/workspace/home-assistant-config/automations/globe_g1_litter_box_automations.yaml`

## Next Steps / TODO
1. Re-enable BLE garage automation after testing: `input_boolean.ble_garage_automation` → on
2. Configure Car 3 MAC address (find actual car beacon, not the April Beacon N06)
3. Consider adjusting global Attenuation in Bermuda for better long-range accuracy
4. Test actual car arrival/departure detection with proper beacons
5. Consider adding car beacons to Bermuda for room-level tracking (optional enhancement)
