# Wireless Segmentation Implementation Plan - Phase 1 (Minimal Disruption)

**Version:** 1.0
**Created:** 2025-11-09
**Status:** Ready for Implementation
**Approach:** Phased by Device Type, Starting with SSIDs Only
**Target Completion:** 5-6 Weeks for Device Migration

---

## Executive Summary

This plan implements wireless network segmentation with **minimal disruption** by:
- Creating new SSIDs on existing network (VLAN 1) first
- Gradually migrating devices by type (IoT → Main → Linda → Guest)
- Deferring VLAN implementation until all devices are stable
- Keeping WAN configuration as active/passive with Frontier Fiber primary
- Zero infrastructure changes during initial migration

**Key Change:** All references to "Daughter" have been updated to "Linda" throughout the architecture.

---

## Phase 1: SSID Creation (Week 1) - ZERO DISRUPTION

Create four new SSIDs via Omada Controller, all initially on VLAN 1 (native/untagged).

### Access Omada Controller
```
URL: https://192.168.1.47:8043
Location: LXC 111 on Proxmox
```

### SSID Configuration

#### 1. Lakehouse-Main (Future VLAN 10)
```
Name: Lakehouse-Main
Security: WPA3-SAE with WPA2-PSK fallback
Password: [Strong password - document separately]
Bands: 2.4 GHz, 5 GHz, 6 GHz (Wi-Fi 7)
VLAN: 1 (Native - no tagging)
Band Steering: Enabled
Fast Roaming: Enabled
Purpose: Trusted user devices (laptops, phones, tablets)
```

#### 2. Lakehouse-IoT (Future VLAN 20)
```
Name: Lakehouse-IoT
Security: WPA2-PSK only (IoT device compatibility)
Password: [Strong password - document separately]
Bands: 2.4 GHz, 5 GHz (NO 6 GHz - many IoT devices don't support)
VLAN: 1 (Native initially)
Band Steering: Disabled (prefer 2.4 GHz for range)
Fast Roaming: Enabled
Purpose: 77 IoT devices from inventory
```

#### 3. Lakehouse-Linda (Future VLAN 30)
```
Name: Lakehouse-Linda
Security: WPA3-SAE with WPA2-PSK fallback
Password: [Strong password - Linda's choice]
Bands: 2.4 GHz, 5 GHz, 6 GHz (Wi-Fi 7)
VLAN: 1 (Native initially)
Band Steering: Enabled
Fast Roaming: Enabled
Purpose: Linda's private network with parental controls (future)
```

#### 4. Lakehouse-Guest (Future VLAN 99)
```
Name: Lakehouse-Guest
Security: WPA2-PSK
Password: [Easy to share password]
Bands: 2.4 GHz, 5 GHz
VLAN: 1 (Native initially)
Band Steering: Enabled
Fast Roaming: Enabled
Purpose: Guest internet access (will be isolated via VLAN later)
```

### Implementation Steps (Omada Controller)

```
1. Login to Omada Controller (https://192.168.1.47:8043)

2. Navigate to: Settings → Wireless Networks → WiFi

3. Click "Create New WiFi" for each SSID above

4. For each SSID:
   ├─ Name: [As specified above]
   ├─ Security Mode: [As specified]
   ├─ Password: [Create strong password]
   ├─ VLAN: None (or VLAN 1 if option available)
   ├─ Wireless Bands: [Select appropriate bands]
   ├─ Band Steering: [Enable/Disable as specified]
   ├─ Fast Roaming (802.11r): Enable
   └─ SSID Broadcast: Enable

5. Apply to Site

6. Verify both EAP773 APs adopt new SSIDs:
   ├─ Navigate to: Devices
   ├─ Select each EAP773 (Upstairs/Downstairs)
   └─ Verify all 4 SSIDs are broadcasting
```

### Testing Phase (Days 1-2)

**Test Device Connectivity:**
```
For each SSID:
□ Connect test device (phone/laptop)
□ Verify receives 192.168.1.x IP address
□ Verify gateway is 192.168.1.1 (Firewalla or current router)
□ Test internet connectivity: ping 8.8.8.8
□ Test DNS resolution: ping google.com
□ Test speed: Run speed test
□ Verify can access local resources (printer, NAS, etc.)
□ Document SSID password securely
```

**Expected Results:**
- All SSIDs behave identically (same network, same access)
- No segmentation yet (all devices can see each other)
- No service interruption (old SSIDs still available)

---

## Phase 2: IoT Device Migration (Week 2) - 77 DEVICES

Migrate IoT devices from existing SSIDs to **Lakehouse-IoT**. Since all SSIDs are on VLAN 1, this is zero-risk.

### IoT Device Inventory (from Firewalla_Devices.csv)

**Total Devices:** 77 IoT devices identified

#### Smart Lighting (18 devices)
```
Amico Smart Recessed Light 1   | C0:F8:53:08:CD:60 | 192.168.1.19
Amico Smart Recessed Light 2   | C0:F8:53:08:CE:7F | 192.168.1.187
Amico Smart Recessed Light 3   | C0:F8:53:08:CE:55 | 192.168.1.70
Amico Smart Recessed Light 4   | C0:F8:53:08:D5:43 | 192.168.1.12
Amico Smart Recessed Light 5   | C0:F8:53:08:C8:21 | 192.168.1.57
Amico Smart Recessed Light 6   | C0:F8:53:08:BA:99 | 192.168.1.26
Amico Smart Recessed Light 7   | C0:F8:53:08:D2:95 | 192.168.1.77
Amico Smart Recessed Light 8   | C0:F8:53:08:D7:04 | 192.168.1.60
Amico Smart Recessed Light 9   | C0:F8:53:08:D6:BA | 192.168.1.10
Amico Smart Recessed Light 10  | C0:F8:53:08:CC:85 | 192.168.1.88
Amico Smart Recessed Light 11  | C0:F8:53:08:C8:C9 | 192.168.1.71
Fireplace                      | CC:8C:BF:65:87:CA | 192.168.1.235
Tuya Smart Inc. (unknown)      | 38:2C:E5:FB:A5:4A | 192.168.1.86
Tuya Smart Inc. (Birdnet)      | 50:8B:B9:6E:0B:82 | 192.168.1.114
Globe 1 litter box             | F8:17:2D:91:B6:A8 | 192.168.1.75
Water quality monitor          | F8:17:2D:DC:FC:5A | 192.168.1.111
```

#### Smart Plugs & Switches (10 devices)
```
Smart Plug                     | 5C:62:8B:AA:EC:57 | 192.168.1.18
EP25 (1)                       | DC:62:79:39:95:44 | 192.168.1.166
EP25 (2)                       | DC:62:79:39:9A:04 | 192.168.1.203
EP25 (3)                       | DC:62:79:39:A4:F7 | 192.168.1.176
EP25 (4)                       | DC:62:79:39:69:89 | 192.168.1.177
EP40 (1)                       | 9C:53:22:A1:C8:2E | 192.168.1.109
EP40 (2)                       | A8:6E:84:37:5E:5B | 192.168.1.129
EP10                           | A8:6E:84:B0:1C:87 | 192.168.1.237
Kasa Strip                     | 5C:62:8B:0D:8B:BA | 192.168.1.128
Unknown Plug                   | B0:8B:A8:4A:7E:24 | 192.168.1.95
```

#### Climate Control (6 devices)
```
Honeywell Thermostat familyroom | 00:D0:2D:9F:7C:B7 | 192.168.1.107
Honeywell thermostat master     | 00:D0:2D:9F:79:6A | 192.168.1.58
Honeywell thermostat upstairs   | 00:D0:2D:9F:7C:A1 | 192.168.1.130
Levoit-Purifier                 | C4:5B:BE:B0:5C:9C | 192.168.1.99
AirPurifyer C545                | 84:72:07:7C:57:B2 | 192.168.1.103
Cur-a-tron                      | 3C:E9:0E:E5:47:D0 | 192.168.1.13
```

#### Voice Assistants & Audio (5 devices)
```
Linda's Bedroom (Sonos)        | 54:2A:1B:DF:BB:7E | 192.168.1.127
Master Echo Dot                | 08:57:FB:EA:AE:08 | 192.168.1.90
Linda's Bedroom (Echo)         | 6C:0C:9A:E6:F9:84 | 192.168.1.68
Amazon #4186                   | B4:10:7A:36:90:5B | 192.168.1.67
LG Soundbar                    | 4C:BA:D7:5B:EF:8E | 192.168.1.31
```

#### Security & Monitoring (5 devices)
```
Envisalink Alarm               | 00:1C:2A:01:B0:37 | 192.168.1.108
Ring-187f88940205              | 18:7F:88:94:02:05 | 192.168.1.222
Ring-dd9df1                    | 34:3E:A4:DD:9D:F1 | 192.168.1.76
Blink-Device                   | 08:C2:24:F8:BF:86 | 192.168.1.87
Tempest Weather Station        | 6C:2A:DF:E0:17:F1 | 192.168.1.82
```

#### Home Automation Hubs (16 devices)
```
SLZB-06 (Zigbee Coordinator)   | 94:54:C5:EA:35:23 | 192.168.1.78
SwitchBot-Hub-2-33E67C         | 84:FC:E6:33:E6:7C | 192.168.1.113
BroadLink-Remote-ba-72-82      | E8:70:72:BA:72:82 | 192.168.1.119
BLE Base                       | E8:31:CD:CC:CB:B0 | 192.168.1.115
AiDot                          | E8:06:90:C1:F3:48 | 192.168.1.118
ESPHome                        | BC:24:11:21:E6:0A | 192.168.1.169
ESP_4DA26A                     | 10:52:1C:4D:A2:6A | 192.168.1.22
Curatronesp                    | E4:B0:63:89:4A:80 | 192.168.1.54
guestroom-ble-proxy            | 6C:C8:40:87:34:8C | 192.168.1.165
upstairs-ble-proxy             | 6C:C8:40:86:78:7C | 192.168.1.66
hobbyroom-ble-proxy            | 6C:C8:40:88:44:6C | 192.168.1.89
gavinroom-ble-proxy            | 6C:C8:40:4F:B0:D0 | 192.168.1.91
masterroom-ble-proxy2          | F0:24:F9:7A:49:54 | 192.168.1.93
wroommicrousb                  | 8C:4F:00:30:5F:B8 | 192.168.1.92
xiao-ble-proxy-1               | 8C:BF:EA:CF:72:74 | 192.168.1.44
xiao-ble-proxy-2               | 8C:BF:EA:CF:85:30 | 192.168.1.72
xiao-ble-proxy-3               | 8C:BF:EA:CF:8B:D0 | 192.168.1.43
bleproxy_with_lux              | E4:B0:63:B3:DD:DC | 192.168.1.96
```

#### Appliances & Entertainment (17 devices)
```
Meross_Smart_Garage            | 48:E1:E9:89:A1:11 | 192.168.1.120
Hydrawise-7041 (Irrigation)    | FC:0F:E7:91:70:41 | 192.168.1.51
GrowHub                        | 34:85:18:36:7E:60 | 192.168.1.117
Samsung-Dryer                  | 28:6B:B4:37:81:F4 | 192.168.1.34
PitBoss Grill                  | 30:83:98:76:95:E8 | 192.168.1.15
Prusa-mini (3D Printer)        | 18:FE:34:F7:9D:65 | 192.168.1.124
BirdNET-go (Pi)                | B8:27:EB:4A:94:D5 | 192.168.1.80
Cloudflared (1)                | BC:24:11:16:7C:5C | 192.168.1.100
Cloudflared (2)                | 18:8B:0E:F3:E0:72 | 192.168.1.112
Jeremy's 4th TV (Fire Stick)   | 54:2B:1C:CB:D7:6B | 192.168.1.73
Jeremy's 4th TV (TV)           | E0:3E:CB:95:E3:B4 | 192.168.1.65
_service (Amazon)              | 54:2B:1C:AF:02:F5 | 192.168.1.116
A33EF821 (Amazon)              | AC:41:6A:47:2F:2A | 192.168.1.56
Cable Matters Inc.             | F4:4D:AD:04:E4:B5 | 192.168.1.126
Xiamen Intretech               | A4:0D:BC:08:06:D8 | 192.168.1.33
Net_a1_E5A8                    | B8:8C:29:C8:E5:A8 | 192.168.1.76
```

### Migration Procedure (Phased by Risk)

#### Days 1-3: Non-Critical Devices (Low Risk)
**Start with simple, easily recovered devices:**

```
Migration Order:
1. Smart Plugs (10 devices) - Easy to reset if issues
2. Smart Lights (18 devices) - Test with 1-2 first, then batch
3. Basic Appliances (Coffee maker, etc.)

For each device:
□ Document current IP address
□ Put device in WiFi setup mode (method varies by device)
□ Connect to "Lakehouse-IoT" SSID
□ Verify gets new IP (will still be 192.168.1.x initially)
□ Test device functionality:
  - Cloud connectivity (app control)
  - Local control if applicable
  - Schedules/automations still work
□ Update device name/notes if needed
□ Move to next device

If issues occur:
✗ Reconnect to original SSID
✗ Document issue
✗ Continue with other devices
```

#### Days 4-5: Semi-Critical Devices (Medium Risk)
**Devices that require more testing:**

```
Migration Order:
1. Climate Control (6 devices) - One at a time!
   ├─ Test each thermostat individually
   ├─ Verify temperature control works
   ├─ Check Home Assistant integration
   └─ Wait 30 min to ensure stable before next one

2. Voice Assistants (5 devices)
   ├─ Alexa devices may need re-setup
   ├─ Test voice commands
   ├─ Verify smart home integration
   └─ Check music streaming

3. Entertainment Devices
   ├─ TVs, soundbar, streaming devices
   ├─ Verify streaming services work
   └─ Test casting (Chromecast/AirPlay)

For each device:
□ Pick low-usage time (late evening)
□ Reconnect to Lakehouse-IoT
□ Test all primary functions
□ Check Home Assistant entities
□ Monitor for 1 hour before marking complete
```

#### Days 6-7: Critical Devices (High Risk - Require Coordination)
**Devices that control critical home functions:**

```
⚠️ IMPORTANT: Coordinate these with Home Assistant downtime

Migration Order:
1. SLZB-06 Zigbee Coordinator
   ├─ This controls ALL Zigbee devices
   ├─ Schedule 30-minute maintenance window
   ├─ Notify household: "Zigbee devices may be unresponsive"
   ├─ Reconnect to Lakehouse-IoT
   ├─ Verify in Home Assistant: Settings → Integrations → Zigbee
   └─ Test several Zigbee devices to confirm

2. BLE Proxies (8 devices)
   ├─ These extend Bluetooth range for HA
   ├─ Migrate one at a time
   ├─ Check Home Assistant ESPHome integration
   └─ Verify BLE device connectivity

3. Security Devices
   ├─ Ring doorbell/cameras
   ├─ Envisalink alarm panel
   ├─ Test motion detection, alerts
   └─ Verify recording/notifications

4. Automation Hubs
   ├─ SwitchBot Hub
   ├─ BroadLink Remote
   ├─ ESPHome devices
   └─ Test automations after each

5. Other Smart Home Controllers
   ├─ Hydrawise (irrigation - can wait for off-season)
   ├─ Meross Garage (test open/close carefully!)
   └─ Weather station

Critical Device Checklist:
□ Schedule maintenance window
□ Notify household members
□ Have backup access method ready (e.g., garage door manual release)
□ Migrate device
□ Immediately test primary function
□ Check Home Assistant integration
□ Run test automation
□ Monitor for 2 hours
□ Document any issues
```

### Home Assistant Integration Updates

**After migrating devices, check these in HA:**

```bash
# SSH to Home Assistant
ssh root@192.168.1.155

# Check ESPHome devices:
Settings → Integrations → ESPHome
├─ Verify all BLE proxies online
├─ Check SLZB-06 connection
└─ Confirm ESPHome device status

# Check Zigbee:
Settings → Integrations → Zigbee Home Automation
├─ Verify coordinator connected
├─ Check device count (should match pre-migration)
└─ Test Zigbee device control

# Check other integrations:
├─ Ring (doorbell/cameras)
├─ Tuya (smart lights/plugs)
├─ Alexa Media Player
├─ Meross (garage)
└─ Weather (Tempest)

# Test automations:
Developer Tools → Services → Run automation
└─ Test critical automations to verify all devices respond
```

### Troubleshooting Common Issues

**Device Won't Connect to New SSID:**
```
1. Check SSID password (WPA2 only for IoT)
2. Verify 2.4 GHz band enabled on AP
3. Some devices need factory reset to change WiFi
4. Tuya devices: Use "Fast Setup" in app
5. Check device proximity to AP (weak signal?)
```

**Device Connects But No Cloud Access:**
```
1. Verify internet connectivity: ping 8.8.8.8
2. Check DNS resolution: nslookup google.com
3. Some devices need 2-3 min to re-establish cloud
4. Try power cycle device
5. Check manufacturer cloud status page
```

**Home Assistant Lost Device:**
```
1. Settings → Integrations → [Integration] → Reload
2. Check device IP changed (shouldn't on VLAN 1, but verify)
3. ESPHome devices: Re-add via ESPHome integration
4. Zigbee devices: Should auto-reconnect when coordinator returns
5. Check Home Assistant logs: Settings → System → Logs
```

**Automation Stopped Working:**
```
1. Developer Tools → Check Configuration
2. Settings → Automations → Click automation → Edit
3. Verify entity IDs haven't changed
4. Test automation manually
5. Check automation triggers (may reference old device names)
```

### Success Criteria for Phase 2

```
✓ All 77 IoT devices connected to Lakehouse-IoT SSID
✓ All devices maintain 192.168.1.x IP addresses
✓ Cloud connectivity working for all devices
✓ Home Assistant integrations functional
✓ No degradation in automation performance
✓ All critical systems operational
✓ Stable for 48+ hours before proceeding to Phase 3
```

---

## Phase 3: Main Device Migration (Week 3)

Migrate trusted user devices to **Lakehouse-Main** SSID.

### Device Categories

**Personal Devices:**
```
- Laptops/workstations
- Personal phones
- Personal tablets
- E-readers
```

**Shared Devices:**
```
- Printers
- Scanners
- Network storage (if WiFi connected)
```

### Migration Approach

**Lower Risk - Same Network:**
Since all SSIDs still on VLAN 1 (192.168.1.x), this is low-risk.

```
Day 1: Your Personal Devices
□ Connect your laptop to Lakehouse-Main
□ Connect your phone to Lakehouse-Main
□ Verify all services work:
  - Internet access
  - Printer access
  - NAS/file sharing
  - Home Assistant access
  - Proxmox/TrueNAS admin access
□ Use as daily driver for 24 hours

Day 2: Other Household Devices
□ Migrate other family member devices one at a time
□ Test each before moving to next
□ Document any issues

Day 3: Shared Devices
□ Printers (carefully - test printing from all devices)
□ Other shared resources
□ Smart TVs if not already in IoT category
```

### Testing Checklist (Per Device)

```
□ Connect to "Lakehouse-Main"
□ Verify IP address: 192.168.1.x
□ Test internet: Open web browser
□ Test local services:
  ├─ Ping Home Assistant: ping 192.168.1.155
  ├─ Ping TrueNAS: ping 192.168.1.10
  ├─ Access Proxmox: https://192.168.1.137:8006
  └─ Access Omada: https://192.168.1.47:8043
□ Test printing (if applicable)
□ Test file sharing/NAS access
□ Verify VPN works (if used)
□ Use for 1-2 hours before marking complete
```

---

## Phase 4: Linda's Network Setup (Week 4)

Create Linda's private network on **Lakehouse-Linda** SSID.

### Linda's Devices

**Primary Devices:**
```
- Linda's phone
- Linda's tablet (if applicable)
- Linda's laptop (if applicable)
```

**Linda's Smart Devices (Already Migrated to IoT):**
```
- Linda's Bedroom Sonos (54:2A:1B:DF:BB:7E) - Already on IoT
- Linda's Bedroom Echo (6C:0C:9A:E6:F9:84) - Already on IoT
```

### Migration Steps

```
Day 1: Discuss with Linda
□ Explain new private network
□ Set password together (Linda chooses)
□ Explain benefits: private network, future parental controls
□ Schedule migration time

Day 2: Migrate Linda's Devices
□ Connect Linda's phone to "Lakehouse-Linda"
  ├─ Show Linda how to connect
  ├─ Save password in phone
  └─ Test internet access together
□ Connect Linda's tablet (if applicable)
□ Connect Linda's laptop (if applicable)
□ Test all devices together

Day 3-4: Monitoring
□ Verify Linda can access internet
□ Verify Linda can control her IoT devices (Sonos, Echo)
  - These stay on IoT SSID but can be controlled from Linda's network
□ No issues for 48 hours
```

### Future Parental Controls (Post-VLAN Implementation)

**Will be configured on Firewalla Gold for VLAN 30:**
```
Content Filtering:
├─ Safe Search: Enforced
├─ Adult Content: Blocked
├─ Violence/Weapons: Blocked
└─ Social Media: Schedule-based

Time Limits:
├─ Weekdays: 6 PM - 10 PM
└─ Weekends: 9 AM - 11 PM

Activity Monitoring:
├─ Website history
├─ App usage
└─ Bandwidth monitoring

Pause Internet:
└─ Available for timeout/study time
```

---

## Phase 5: Guest Network Activation (Week 5)

Set up and publicize guest network on **Lakehouse-Guest** SSID.

### Configuration

**Guest Network Characteristics:**
```
SSID: Lakehouse-Guest
Password: [Easy to share, document on guest info card]
Purpose: Visitors internet access only
```

### Setup Steps

```
Day 1: Prepare Guest Materials
□ Create guest network info card:
  ┌─────────────────────────────────────┐
  │ Welcome to Lakehouse!               │
  │                                     │
  │ WiFi Network: Lakehouse-Guest       │
  │ Password: [password]                │
  │                                     │
  │ Questions? Ask your host            │
  └─────────────────────────────────────┘
□ Print and laminate card
□ Place in guest room

Day 2: Test Guest Network
□ Connect test device to "Lakehouse-Guest"
□ Verify internet access
□ Verify CANNOT access local network:
  - Try to ping router: ping 192.168.1.1
  - Try to access local services (should work on VLAN 1 initially)
  - Note: True isolation requires VLAN 99 implementation
□ Test with guest device (if visitor available)

Day 3-7: Soft Launch
□ Use with 1-2 guests
□ Collect feedback
□ Adjust password if too complex
□ Monitor usage
```

### Important Notes

**Current Limitation (VLAN 1):**
```
⚠️ Guest devices can currently access local network
└─ True isolation requires VLAN 99 implementation (Phase 6)
```

**Acceptable Interim State:**
```
✓ Provides separate SSID for guests
✓ Keeps guest devices off main SSID
✓ Easy to share password
✗ Not yet isolated from local network (requires VLAN)
```

---

## Phase 6: Future VLAN Implementation (TBD - After 2+ Weeks Stable)

Once all devices successfully migrated and stable, implement true VLAN segmentation.

### Prerequisites

```
✓ All devices on correct SSIDs for 2+ weeks
✓ No connectivity issues observed
✓ All IoT devices stable and functional
✓ Home Assistant integrations working correctly
✓ Family comfortable with new SSIDs
✓ Ready for brief network reconfiguration
```

### Step 1: Firewalla Gold VLAN Configuration

**Create VLAN Interfaces:**
```
Via Firewalla Web Interface (https://my.firewalla.com):

1. Network Manager → Create Network → VLAN Network

2. VLAN 10 - Main LAN:
   ├─ Name: Main-LAN
   ├─ VLAN ID: 10
   ├─ IP Range: 192.168.10.0/24
   ├─ Gateway: 192.168.10.1 (FWG)
   ├─ DHCP Server: Enabled
   ├─ DHCP Range: 192.168.10.100-192.168.10.199
   └─ DNS: FWG forwards to 1.1.1.1, 8.8.8.8

3. VLAN 20 - IoT:
   ├─ Name: IoT-Network
   ├─ VLAN ID: 20
   ├─ IP Range: 192.168.20.0/24
   ├─ Gateway: 192.168.20.1 (FWG)
   ├─ DHCP Server: Enabled
   ├─ DHCP Range: 192.168.20.100-192.168.20.199
   └─ DNS: FWG forwards to 1.1.1.1, 8.8.8.8

4. VLAN 30 - Linda's Network:
   ├─ Name: Linda-Network
   ├─ VLAN ID: 30
   ├─ IP Range: 192.168.30.0/24
   ├─ Gateway: 192.168.30.1 (FWG)
   ├─ DHCP Server: Enabled
   ├─ DHCP Range: 192.168.30.100-192.168.30.199
   └─ DNS: FWG forwards to 1.1.1.1, 8.8.8.8

5. VLAN 99 - Guest:
   ├─ Name: Guest-Network
   ├─ VLAN ID: 99
   ├─ IP Range: 192.168.99.0/24
   ├─ Gateway: 192.168.99.1 (FWG)
   ├─ DHCP Server: Enabled
   ├─ DHCP Range: 192.168.99.10-192.168.99.250
   └─ DNS: FWG forwards to 1.1.1.1, 8.8.8.8

6. Configure Trunk Port:
   ├─ Port 1 (to SG3218-M2): VLAN Trunk
   ├─ Native VLAN: 1 (management)
   └─ Tagged VLANs: 10, 20, 30, 99
```

### Step 2: Switch VLAN Configuration (Omada Controller)

**Update Switch Port Configuration:**
```
Via Omada Controller (https://192.168.1.47:8043):

1. Settings → Wired Networks → LAN Networks

2. Create VLANs on switch:
   For each VLAN (10, 20, 30, 99):
   ├─ Click "Create New LAN"
   ├─ Name: [Main-LAN, IoT, Linda, Guest]
   ├─ VLAN ID: [10, 20, 30, 99]
   ├─ Gateway/Subnet: [As defined above]
   ├─ DHCP Mode: Relay to Firewalla
   └─ Apply to Site

3. Update AP Trunk Ports:
   Devices → SW-Main-SG3218XP → Port Config

   Port 4 (EAP773 Upstairs):
   ├─ Mode: Trunk
   ├─ PVID: 1 (management)
   ├─ Tagged VLANs: 1, 10, 20, 30, 99
   └─ PoE: 802.3bt Enabled

   Port 8 (EAP773 Downstairs):
   ├─ Mode: Trunk
   ├─ PVID: 1 (management)
   ├─ Tagged VLANs: 1, 10, 20, 30, 99
   └─ PoE: 802.3bt Enabled

4. Apply configuration
```

### Step 3: SSID to VLAN Mapping (Omada Controller)

**Update SSID Configurations:**
```
Settings → Wireless Networks → WiFi

For each SSID, click Edit:

1. Lakehouse-Main:
   └─ VLAN: 10 (change from 1)

2. Lakehouse-IoT:
   └─ VLAN: 20 (change from 1)

3. Lakehouse-Linda:
   └─ VLAN: 30 (change from 1)

4. Lakehouse-Guest:
   └─ VLAN: 99 (change from 1)

Apply to Site
```

### Step 4: Device IP Migration

**After VLAN implementation, devices will get new IPs:**

```
Main LAN Devices:
192.168.1.x → 192.168.10.x

IoT Devices:
192.168.1.x → 192.168.20.x

Linda's Devices:
192.168.1.x → 192.168.30.x

Guest Devices:
192.168.1.x → 192.168.99.x
```

**Migration Day Procedure:**
```
1. Notify household: "Network maintenance 1-2 hours"

2. Apply VLAN configurations (Steps 1-3 above)

3. Reconnect all devices (will get new IPs automatically):
   ├─ Devices forget WiFi and reconnect
   ├─ Or simply wait for DHCP lease renewal
   └─ Or reboot devices

4. Verify each VLAN:
   ├─ Connect test device to each SSID
   ├─ Verify correct IP subnet
   ├─ Test internet access
   └─ Test inter-VLAN rules

5. Update static IPs if needed:
   ├─ Servers/infrastructure stay on VLAN 1
   ├─ Update firewall rules for new subnets
   └─ Update Home Assistant integrations
```

### Step 5: Firewall Rules Configuration

**Critical: Configure inter-VLAN security**

```
Via Firewalla: Rules → Access Control

Priority Order (top to bottom):

1. Allow Main LAN → IoT (Control):
   ├─ Source: 192.168.10.0/24
   ├─ Dest: 192.168.20.0/24
   ├─ Protocol: TCP/UDP
   ├─ Ports: 80, 443, 1883 (HTTP, HTTPS, MQTT)
   ├─ Action: Allow
   └─ Logging: No

2. Allow IoT → Home Assistant:
   ├─ Source: 192.168.20.0/24
   ├─ Dest: 192.168.1.155 (Home Assistant)
   ├─ Protocol: ALL
   ├─ Action: Allow
   └─ Logging: No

3. Block IoT → Main LAN:
   ├─ Source: 192.168.20.0/24
   ├─ Dest: 192.168.10.0/24
   ├─ Protocol: ALL
   ├─ Action: Block
   └─ Logging: YES (important!)

4. Allow IoT → Internet:
   ├─ Source: 192.168.20.0/24
   ├─ Dest: Internet
   ├─ Protocol: HTTP, HTTPS, DNS
   ├─ Action: Allow
   └─ Logging: No

5. Block Linda → Main LAN:
   ├─ Source: 192.168.30.0/24
   ├─ Dest: 192.168.10.0/24
   ├─ Protocol: ALL
   ├─ Action: Block
   └─ Logging: YES

6. Block Guest → All Local:
   ├─ Source: 192.168.99.0/24
   ├─ Dest: 192.168.0.0/16, 10.0.0.0/8
   ├─ Protocol: ALL
   ├─ Action: Block
   └─ Logging: YES

7. Allow Guest → Internet:
   ├─ Source: 192.168.99.0/24
   ├─ Dest: Internet
   ├─ Protocol: HTTP, HTTPS, DNS
   ├─ Action: Allow
   └─ Logging: No

8. Default Deny All:
   ├─ Source: ALL
   ├─ Dest: ALL
   ├─ Action: Block
   └─ Logging: YES
```

### Step 6: mDNS Relay Configuration (Service Discovery)

**Enable mDNS relay for AirPlay/Chromecast:**

```
Firewalla App/Web → Settings → Advanced

mDNS Reflector (Service Discovery):
├─ Enable for networks:
│  ├─ Main LAN (VLAN 10) ✓
│  ├─ IoT Network (VLAN 20) ✓
│  └─ Linda Network (VLAN 30) ✓
└─ Verify multicast forwarding:
   ├─ 224.0.0.251 (mDNS)
   └─ 239.255.255.250 (SSDP)

⚠️ IMPORTANT: Disable IGMP Snooping on switch!
└─ See original plan Section 5.2 for details
```

### Step 7: Testing and Validation

**Comprehensive VLAN Testing:**

```
Test 1: VLAN Isolation
□ From Main LAN device, try to ping IoT device:
  └─ ping 192.168.20.x (should FAIL)
□ From IoT device, try to ping Main LAN:
  └─ Should FAIL (no ping utility on most IoT)
□ From Guest device, try to access:
  └─ ping 192.168.1.1 (should FAIL)
  └─ ping 192.168.10.1 (should FAIL)

Test 2: Allowed Communication
□ From Main LAN, control IoT device:
  └─ Open smart light app, toggle light (should WORK)
□ From Main LAN, access Home Assistant:
  └─ https://192.168.1.155 (should WORK)
  └─ Control IoT devices via HA (should WORK)
□ From Linda network, access internet:
  └─ Browse websites (should WORK)

Test 3: Service Discovery
□ From Main LAN device:
  └─ Open AirPlay menu (should see Apple TV on IoT VLAN)
  └─ Open Chromecast (should see devices on IoT VLAN)
□ From Linda network:
  └─ Verify can discover and cast to Linda's devices

Test 4: Internet Access
□ All VLANs should have internet:
  ├─ Main LAN: ping 8.8.8.8 ✓
  ├─ IoT: (cloud apps work) ✓
  ├─ Linda: ping 8.8.8.8 ✓
  └─ Guest: ping 8.8.8.8 ✓

Test 5: Firewall Logging
□ Check Firewalla logs for blocked attempts:
  └─ Rules → View Logs
  └─ Should see IoT → Main LAN blocks (if devices trying)
  └─ Should see Guest → LAN blocks
```

### Step 8: Linda's Parental Controls

**After VLAN 30 active, configure Family Protect:**

```
Firewalla Family → Create Profile

Profile Name: Linda's Network
Apply to: Network 192.168.30.0/24

Settings:
├─ Safe Search: Enforced
├─ Adult Content: Blocked
├─ Violence/Weapons: Blocked
├─ Social Media: Schedule-based
├─ Gaming: Schedule-based
│
├─ Schedule:
│  ├─ Weekdays: 6 PM - 10 PM
│  └─ Weekends: 9 AM - 11 PM
│
├─ Pause Internet: Available
└─ Activity Monitoring: Enabled

Test:
□ From Linda's device, try to access blocked content
□ Try to access internet outside allowed hours
□ Verify safe search enforced (Google, Bing, YouTube)
□ Check activity logs
```

---

## WAN Configuration (No Changes Planned)

### Current State (Maintained)
```
Primary WAN: Frontier Fiber 2.0 Gbps (Active)
Secondary WAN: Spectrum 1 GB (Passive/Failover)

Configuration:
└─ Frontier handles all traffic by default
└─ Spectrum activates on Frontier failure
└─ No policy-based routing yet
└─ No load balancing yet
```

### Future Enhancement (Optional - Not Part of This Plan)
```
If/when implementing dual-WAN optimization:
├─ Configure Firewalla WAN ports (Port 3, Port 4)
├─ Enable WAN monitoring (ping 1.1.1.1, 8.8.8.8)
├─ Set Frontier as primary route
├─ Configure automatic failover
└─ Optionally: Policy-based routing for specific VLANs

See original plan Section 1.3 for details.
```

---

## Documentation Updates Required

### Update Master Plan Document

**File:** `docs/network/UNIFIED_NETWORK_ARCHITECTURE_PLAN.md`

**Global Find/Replace:**
```
Find: "Daughter"
Replace: "Linda"

Affected Sections:
├─ Line 97: VLAN table
├─ Line 336: SSID table
├─ Section 4.2: Firewall rules
├─ Section 4.4: Parental controls
├─ Section 8.2: Timeline
└─ Appendix B (line 2286): IP allocations
```

**Add New Section After 8.2:**
```
### 8.2.1 Phased Wireless Migration (Lower Risk Alternative)

[Insert content from this document - Phases 1-5]

Purpose: For users who want to migrate devices gradually
         before implementing VLANs.
```

**Add New Appendix:**
```
### Appendix E: IoT Device Inventory

Complete list of 77 IoT devices with MAC addresses
From: Firewalla_Devices (1).csv export 2025-11-08

[Insert device tables from Phase 2 above]
```

### Create Migration Tracking Spreadsheet

**File:** `docs/network/wireless-migration-tracker.xlsx`

**Columns:**
```
| Device Name | MAC Address | Old IP | Old SSID | New SSID | New IP | Date | Status | Notes |
```

**Status Values:**
- Not Started
- In Progress
- Complete
- Issue (describe in Notes)
- Rolled Back

### Create Quick Reference Card

**File:** `docs/network/SSID-QUICK-REFERENCE.md`

```markdown
# Lakehouse WiFi Networks - Quick Reference

## For Family Members

### Lakehouse-Main
- **Who:** Trusted devices (laptops, phones, tablets)
- **Password:** [Document separately]
- **Use for:** Your personal devices

### Lakehouse-IoT
- **Who:** Smart home devices only
- **Password:** [Document separately]
- **Use for:** Smart lights, plugs, thermostats, etc.

### Lakehouse-Linda
- **Who:** Linda's devices
- **Password:** [Linda's choice]
- **Use for:** Linda's phone, tablet, laptop

### Lakehouse-Guest
- **Who:** Visitors
- **Password:** [Easy to share]
- **Use for:** Guest devices

## For Troubleshooting

Old SSID: [Your current SSID]
Password: [Current password]

If issues, reconnect to old SSID and notify admin.
```

---

## Risk Assessment and Mitigation

### Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Device won't connect to new SSID | Medium | Low | Keep old SSID active, reconnect if needed |
| IoT device requires factory reset | Low | Medium | Document reset procedures, do non-critical first |
| Home Assistant loses device | Low | High | Test one device per integration, have restore plan |
| Zigbee network disruption | Low | High | Schedule maintenance window, notify household |
| Automation failure | Low | Medium | Test automations after each critical device |
| Family member frustration | Medium | Low | Clear communication, gradual rollout |
| VLAN misconfiguration | Low | High | Phase 6 only - after thorough testing |

### Rollback Procedures

**If Issues During Phases 1-5:**
```
1. Device-level rollback:
   └─ Simply reconnect device to original SSID
   └─ Device returns to previous state
   └─ No configuration changes needed

2. SSID-level rollback:
   └─ Disable new SSID in Omada Controller
   └─ All devices revert to original SSID
   └─ Zero data loss

3. Complete rollback:
   └─ Delete all new SSIDs
   └─ Network returns to original state
   └─ Zero infrastructure impact
```

**If Issues During Phase 6 (VLAN Implementation):**
```
⚠️ More complex - requires network reconfiguration

1. Remove VLAN tagging from SSIDs:
   └─ Set all SSIDs back to VLAN 1 (native)

2. Remove VLAN interfaces from Firewalla:
   └─ Delete VLANs 10, 20, 30, 99

3. Update switch trunk ports:
   └─ Remove VLAN tags from AP ports

4. Devices automatically return to 192.168.1.x

5. Verify services restored

Downtime: 15-30 minutes
```

---

## Timeline Summary

### Weeks 1-5: Device Migration (Low Risk)
```
Week 1: Create SSIDs, test
Week 2: Migrate 77 IoT devices
Week 3: Migrate main LAN devices
Week 4: Setup Linda's network
Week 5: Activate guest network

Characteristics:
✓ All on same network (VLAN 1)
✓ No infrastructure changes
✓ Easy rollback
✓ Can take longer if needed
✓ Pause anytime without issues
```

### Week 6+: Stabilization
```
Monitor for 2+ weeks:
□ All devices stable
□ No connectivity issues
□ Home Assistant working properly
□ Automations functioning
□ Family comfortable with changes
□ Ready for VLAN implementation
```

### Future: VLAN Implementation (Phase 6)
```
Scheduled maintenance window (TBD):
├─ 2-4 hours
├─ Weekend morning
├─ All household members aware
└─ Rollback plan ready

Steps:
1. Configure Firewalla VLANs (30 min)
2. Update switch configuration (15 min)
3. Map SSIDs to VLANs (5 min)
4. Devices reconnect (30-60 min)
5. Configure firewall rules (30 min)
6. Enable mDNS relay (5 min)
7. Test thoroughly (60 min)
8. Monitor for issues (ongoing)
```

---

## Success Metrics

### Phase 1-5 Success Criteria
```
✓ All 4 SSIDs created and broadcasting
✓ All 77 IoT devices connected to Lakehouse-IoT
✓ All main devices connected to Lakehouse-Main
✓ Linda's devices on Lakehouse-Linda
✓ Guest SSID available and tested
✓ Zero service disruptions
✓ Home Assistant integrations functional
✓ All automations working
✓ Stable for 2+ weeks
```

### Phase 6 Success Criteria (Future)
```
✓ All VLANs operational (10, 20, 30, 99)
✓ Devices receive correct IP subnets
✓ IoT isolation verified (cannot reach main LAN)
✓ Guest isolation verified (cannot reach local network)
✓ Service discovery working (AirPlay, Chromecast)
✓ Internet access on all VLANs
✓ Firewall rules enforced
✓ Linda's parental controls active
✓ No false-positive blocks
✓ Stable for 1 week
```

---

## Support and Troubleshooting

### Quick Diagnostics

**Device Won't Connect:**
```bash
# Check SSID is broadcasting:
# From laptop: View WiFi networks list

# Check AP status (Omada):
https://192.168.1.47:8043 → Devices → EAP773

# Check SSID configuration:
Settings → Wireless Networks → WiFi → [SSID]

# Common fixes:
1. Verify password correct
2. Check device compatibility (WPA2 vs WPA3)
3. Verify 2.4 GHz enabled (IoT devices)
4. Check device WiFi settings (forget + reconnect)
5. Reboot AP if needed
```

**Device Has No Internet:**
```bash
# Verify DHCP:
# Device should have 192.168.1.x IP (initially)

# Test connectivity:
ping 192.168.1.1  # Gateway
ping 8.8.8.8      # Internet
nslookup google.com  # DNS

# Common fixes:
1. Renew DHCP lease
2. Check gateway configured (192.168.1.1)
3. Verify DNS servers assigned
4. Power cycle device
5. Check Firewalla WAN status
```

**Home Assistant Lost Device:**
```bash
# SSH to HA:
ssh root@192.168.1.155

# Check logs:
Settings → System → Logs

# Reload integration:
Settings → Integrations → [Integration] → Reload

# Check device IP:
# For VLAN 1 migration, IP shouldn't change
# If it did, update HA configuration

# Common fixes:
1. Reload integration
2. Restart Home Assistant
3. Re-add device to integration
4. Check device connectivity
5. Verify firewall not blocking
```

### Escalation Path

**Level 1: Self-Service (This Document)**
- Follow troubleshooting steps
- Check device compatibility
- Verify basic connectivity

**Level 2: Vendor Documentation**
- Omada Controller documentation
- Device manufacturer support (Tuya, TP-Link, etc.)
- Home Assistant community forums

**Level 3: Professional Support**
- Firewalla support (if VLAN issues in Phase 6)
- TP-Link Omada support
- Network consultant (if needed)

### Emergency Contacts

```
Omada Controller: https://192.168.1.47:8043
Firewalla Dashboard: https://my.firewalla.com
Home Assistant: https://192.168.1.155

TP-Link Support: 1-866-225-8139
Firewalla Support: support@firewalla.com
```

---

## Appendices

### Appendix A: SSID Password Recommendations

**Password Strength Guidelines:**
```
Main LAN (Lakehouse-Main):
├─ Length: 16+ characters
├─ Complexity: Mixed case, numbers, symbols
├─ Example format: [Word]-[Word]-[Number]-[Symbol]
└─ Document securely (password manager)

IoT (Lakehouse-IoT):
├─ Length: 12+ characters
├─ Complexity: Mixed case, numbers
├─ Avoid symbols (some IoT devices have issues)
└─ Keep simple enough to type on device apps

Linda (Lakehouse-Linda):
├─ Length: 12+ characters
├─ Let Linda choose (within guidelines)
├─ Should be memorable for Linda
└─ Different from other networks

Guest (Lakehouse-Guest):
├─ Length: 10+ characters
├─ Easy to communicate verbally
├─ Easy to type (avoid confusing characters: 0 vs O, 1 vs l)
└─ Example: "Welcome2025!"
```

### Appendix B: Device Reset Procedures

**Common IoT Device Reset Methods:**
```
Tuya Smart Lights/Plugs:
1. Turn on/off 3 times rapidly
2. Light/LED flashes rapidly = ready to pair
3. Use Tuya app "Add Device" → "Fast Setup"

TP-Link Kasa Devices:
1. Hold button 5+ seconds
2. LED flashes amber/green = ready
3. Use Kasa app to reconfigure

Alexa Devices:
1. Hold Action button 25 seconds
2. Light ring turns orange = setup mode
3. Use Alexa app to reconfigure

Ring Devices:
1. Hold setup button 20 seconds
2. Light flashes = ready
3. Use Ring app to reconfigure

Thermostats (Honeywell):
1. Menu → WiFi → Reset Network
2. Reconfigure via app
3. Will maintain schedules

ESPHome/BLE Proxies:
1. May need physical access to flash
2. Or: use ESPHome web interface
3. Update WiFi credentials in config
```

### Appendix C: Home Assistant Integration Checklist

**Post-Migration Verification:**
```
□ ESPHome Integration:
  ├─ All devices online
  ├─ No "unavailable" entities
  └─ BLE proxies showing activity

□ Zigbee Home Automation:
  ├─ Coordinator connected
  ├─ Device count matches pre-migration
  ├─ Test several devices
  └─ Check signal strength map

□ Tuya Integration:
  ├─ All smart lights responding
  ├─ All smart plugs responding
  └─ Control via HA dashboard works

□ Amazon Alexa:
  ├─ All Echo devices online
  ├─ Voice commands work
  └─ Media player entities functional

□ Ring Integration:
  ├─ Doorbell/cameras online
  ├─ Motion detection working
  └─ Live view functional

□ Other Integrations:
  ├─ Weather (Tempest)
  ├─ Meross (garage door)
  ├─ Hydrawise (irrigation)
  └─ Any custom integrations
```

### Appendix D: Firmware Versions (As of 2025-11-09)

**Document current versions before starting:**
```
Omada Controller: [Version]
├─ Location: LXC 111 (192.168.1.47)
└─ Update status: [Current/Available]

EAP773 APs:
├─ Upstairs: [Version]
├─ Downstairs: [Version]
└─ Update status: [Current/Available]

SG3218XP-M2 Switch:
├─ Version: [Version]
├─ Location: 192.168.1.210
└─ Update status: [Current/Available]

Firewalla Gold:
├─ Version: [Version if FWG deployed]
└─ Auto-update: [Enabled/Disabled]

Recommendation: Apply updates BEFORE migration
```

---

## Checklist: Ready to Start?

**Pre-Implementation Verification:**
```
□ Omada Controller accessible (https://192.168.1.47:8043)
□ EAP773 APs online and managed by Omada
□ Current network stable (no ongoing issues)
□ IoT device CSV reviewed (77 devices identified)
□ Passwords chosen for all 4 SSIDs
□ Family notified of upcoming changes
□ Backup taken of Omada configuration
□ This document printed/accessible for reference
□ Set aside 1-2 hours for Phase 1 (SSID creation)
□ Scheduled 2-3 weeks for gradual device migration
□ Understand rollback procedure (reconnect to old SSID)
□ Questions answered, ready to proceed
```

**Phase 6 Pre-Implementation (Future):**
```
□ All devices on correct SSIDs for 2+ weeks
□ Zero connectivity issues observed
□ Home Assistant stable
□ Family comfortable with current setup
□ Firewalla Gold deployed and configured
□ Scheduled 2-4 hour maintenance window
□ Household notified of network downtime
□ Backup of all configurations taken
□ Rollback plan documented and understood
□ Ready for VLAN implementation
```

---

**Document End**

For questions, refer to:
- Original Plan: `docs/network/UNIFIED_NETWORK_ARCHITECTURE_PLAN.md`
- Device Inventory: `docs/network/Firewalla_Devices (1).csv`
- Omada Controller: https://192.168.1.47:8043

**Implementation Start Date:** _____________

**Phase 1 Completion:** _____________

**Phase 2 Completion:** _____________

**Phase 3 Completion:** _____________

**Phase 4 Completion:** _____________

**Phase 5 Completion:** _____________

**Phase 6 Planned:** _____________

**Notes:**
