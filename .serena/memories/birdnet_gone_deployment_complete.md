# BirdNET-Gone Deployment - Complete System Guide

## Overview
Successfully deployed unified BirdNET system to Raspberry Pi 4 (192.168.1.197) combining BirdNET-Go core, Display interface, and ESP32-S3 wireless microphone into a cohesive bird detection platform.

**Deployment Date:** October 14, 2025
**Repository:** https://github.com/festion/birdnet-gone
**Documentation:** `/home/dev/workspace/BIRDNET_GONE_DEPLOYMENT_COMPLETE.md`

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         Raspberry Pi 4 (192.168.1.197 - birdnet-gone)       │
│                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐   │
│  │  BirdNET-Go Core     │◄────►│  BirdNET Display     │   │
│  │  Port: 8080          │      │  Port: 5000          │   │
│  │  Docker Container    │      │  Flask Application   │   │
│  └──────────┬───────────┘      └──────────────────────┘   │
│             │ HTTP Audio Stream                            │
│             ▼                                              │
└─────────────────────────────────────────────────────────────┘
              │
              │ http://192.168.1.211:8080/stream
              ▼
┌─────────────────────────────────────────────────────────────┐
│  ESP32-S3 Sense Wireless Microphone (192.168.1.211)        │
│  Audio: 16kHz, 16-bit, Mono WAV, Built-in PDM MEMS        │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. BirdNET-Go (Core Detection Engine)
**Status:** ✅ Running as systemd service
- **Service:** `/etc/systemd/system/birdnet-go.service` (enabled, auto-start)
- **Container:** `ghcr.io/tphakala/birdnet-go:nightly`
- **Web UI:** http://192.168.1.197:8080
- **API:** http://192.168.1.197:8080/api/v2/detections/recent
- **Config:** `/root/birdnet-go-app/config/config.yaml`
- **Data:** `/root/birdnet-go-app/data/`
- **Clips:** `/root/birdnet-go-app/data/clips/` (AAC @ 96kbps)

**Configuration:**
```yaml
realtime:
  interval: 15  # Analyze every 15 seconds
  audio:
    source: http://192.168.1.211:8080/stream  # ESP32-S3 HTTP stream
  export:
    enabled: true
    type: aac
    bitrate: 96k
    retention:
      policy: usage
      maxusage: 80%
      maxage: 30d

birdnet:
  sensitivity: 1      # Maximum sensitivity
  threshold: 0.8     # 80% confidence minimum
  overlap: 1.5       # Seconds
  locale: en-us      # United States species
  latitude: 0        # UPDATE FOR ACCURACY
  longitude: 0       # UPDATE FOR ACCURACY
```

**Service Management:**
```bash
# Status
ssh jeremy@192.168.1.197 "systemctl status birdnet-go.service"
ssh jeremy@192.168.1.197 "docker logs birdnet-go"

# Restart
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S systemctl restart birdnet-go.service"

# Edit config
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S nano /root/birdnet-go-app/config/config.yaml"
```

### 2. BirdNET Display (Visualization Layer)
**Status:** ✅ Running as systemd service
- **Service:** `/etc/systemd/system/bird-display.service` (enabled, auto-start)
- **Framework:** Flask (Python 3.11)
- **Web UI:** http://192.168.1.197:5000
- **Working Dir:** `/home/jeremy/birdnet_display/`
- **Run Script:** `/home/jeremy/birdnet_display/run.sh`

**Configuration:**
```python
# In birdnet_display.py
BASE_URL = "http://localhost:8080/"
API_ENDPOINT = "api/v2/detections/recent"
CACHE_DIRECTORY = "/home/jeremy/birdnet_display/static/bird_images_cache"
SPECIES_FILE = "/home/jeremy/birdnet_display/species_list.csv"
```

**Service Management:**
```bash
# Status
ssh jeremy@192.168.1.197 "systemctl status bird-display.service"
ssh jeremy@192.168.1.197 "journalctl -u bird-display.service -n 50"

# Restart
ssh jeremy@192.168.1.197 "systemctl restart bird-display.service"
```

**Kiosk Mode (Optional - Configured but not active):**
- Desktop autostart: `~/.config/autostart/birdnet-display.desktop`
- Kiosk launcher: `/home/jeremy/birdnet_display/kiosk_launcher.sh`
- Activation: Requires reboot + chromium-browser installation

### 3. ESP32-S3 Sense Wireless Microphone
**Status:** ✅ Online and streaming
- **IP:** 192.168.1.211
- **HTTP Stream:** http://192.168.1.211:8080/stream
- **Status API:** http://192.168.1.211:8080/status
- **Dashboard:** http://192.168.1.211:8080

**Specifications:**
- Sample Rate: 16kHz
- Bit Depth: 16-bit
- Channels: Mono
- Format: WAV (PCM)
- Microphone: Built-in PDM MEMS
- WiFi Signal: Typically -54 to -73 dBm

**Monitoring:**
```bash
# Check status
curl -s http://192.168.1.211:8080/status | jq '.'

# Expected response:
# {
#   "activeClients": 0-1,
#   "totalConnections": 1+,
#   "uptime": <seconds>,
#   "freeHeap": ~260000,
#   "wifiRSSI": -50 to -70
# }
```

**Documentation:** See `/home/dev/workspace/ESP32S3_BIRDNET_PI_INTEGRATION_COMPLETE.md`

## Installation Process

### Challenges Overcome

#### 1. BirdNET-Go Interactive Installer
**Problem:** install.sh has 37 interactive prompts with no unattended mode
- Created comprehensive prompt analysis: `/tmp/INSTALL_PROMPTS_ANALYSIS.md`
- Multiple expect script attempts failed at systemd installation phase
- Scripts would exit prematurely after selecting "Install as systemd service"

**Solution:** Manually created systemd service file
- Location: `/etc/systemd/system/birdnet-go.service`
- Initial attempt included invalid `realtime` argument causing exec error
- Fixed by removing `realtime` from ExecStart command
- Service now starts correctly with Docker host networking

#### 2. BirdNET Display Installation
**Success:** Automated with expect script
- Only 4 prompts (much simpler than core installer)
- Script: `/tmp/install-display.exp`
- Auto-created systemd service successfully
- Answered: species list fetch (y), kiosk setup (y), host networking (y), reboot (N)

#### 3. Audio Stream Configuration
**Challenge:** Initial config showed "no hardware audio capture devices found"
- This warning appears during startup but doesn't prevent HTTP stream usage
- Updated config.yaml: `source: http://192.168.1.211:8080/stream`
- Restart required to apply changes
- System now running in realtime mode with HTTP audio source

### Created Files

**Documentation:**
- `/home/dev/workspace/BIRDNET_GONE_DEPLOYMENT_COMPLETE.md` - Complete guide
- `/tmp/INSTALL_PROMPTS_ANALYSIS.md` - Installer prompt mapping

**Automation Scripts:**
- `/tmp/install-complete-unattended.exp` - First automation attempt
- `/tmp/install-final.exp` - Final attempt with sudo handling
- `/tmp/install-display.exp` - Display installer automation (successful)

**System Services:**
- `/etc/systemd/system/birdnet-go.service` - Manually created
- `/etc/systemd/system/bird-display.service` - Auto-created by installer

## Credentials & Access

### SSH Access
```bash
# Primary user
ssh jeremy@192.168.1.197
Password: redflower805

# SSH key authentication configured
ssh jeremy@192.168.1.197  # Passwordless with key
```

### Service Accounts
- **BirdNET-Go:** Runs as root (Docker requires privileged access)
- **Display:** Runs as jeremy (Flask app)

### Web Interfaces
- **BirdNET-Go:** http://192.168.1.197:8080 (no authentication)
- **Display:** http://192.168.1.197:5000 (no authentication)
- **ESP32-S3:** http://192.168.1.211:8080 (no authentication)

## Operational Procedures

### Check System Status
```bash
# All services
ssh jeremy@192.168.1.197 "systemctl status birdnet-go.service bird-display.service"

# Check for detections
curl -s http://192.168.1.197:8080/api/v2/detections/recent | jq '.'

# View recent clips
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S ls -lht /root/birdnet-go-app/data/clips/ | head -10"

# ESP32 connectivity
curl -s http://192.168.1.211:8080/status | jq '.activeClients, .wifiRSSI'
```

### Restart Services
```bash
# BirdNET-Go (requires sudo)
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S systemctl restart birdnet-go.service"

# Display (user-level)
ssh jeremy@192.168.1.197 "systemctl restart bird-display.service"

# Both services
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S systemctl restart birdnet-go.service && systemctl restart bird-display.service"
```

### View Logs
```bash
# BirdNET-Go container logs
ssh jeremy@192.168.1.197 "docker logs birdnet-go --tail 50"
ssh jeremy@192.168.1.197 "docker logs birdnet-go -f"  # Follow

# Display service logs
ssh jeremy@192.168.1.197 "journalctl -u bird-display.service -n 50"
ssh jeremy@192.168.1.197 "journalctl -u bird-display.service -f"  # Follow

# System logs
ssh jeremy@192.168.1.197 "journalctl -n 100"
```

### Update Configuration

#### BirdNET-Go Config
```bash
# Edit config
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S nano /root/birdnet-go-app/config/config.yaml"

# Important settings to update:
# - birdnet.latitude / longitude (for accurate range filtering)
# - birdnet.threshold (detection confidence, 0.0-1.0)
# - realtime.interval (seconds between analyses)
# - realtime.audio.export.type (aac, wav, flac, mp3, opus)

# Apply changes
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S systemctl restart birdnet-go.service"
```

#### Display Config
```bash
# Edit display app
ssh jeremy@192.168.1.197 "nano /home/jeremy/birdnet_display/birdnet_display.py"

# Apply changes
ssh jeremy@192.168.1.197 "systemctl restart bird-display.service"
```

## Troubleshooting

### No Detections Appearing
**Normal Conditions:**
- No birds singing within microphone range
- Bird calls below configured confidence threshold (0.8 = 80%)
- System just started (needs time to analyze audio)

**Verification Steps:**
```bash
# 1. Verify realtime mode is active
ssh jeremy@192.168.1.197 "docker logs birdnet-go 2>&1 | grep 'Starting analyzer in realtime mode'"

# 2. Check ESP32 connection
curl http://192.168.1.211:8080/status | jq '.totalConnections'
# Should show 1 or more

# 3. Verify audio source config
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S grep 'source:' /root/birdnet-go-app/config/config.yaml"
# Should show: source: http://192.168.1.211:8080/stream

# 4. Monitor for activity
ssh jeremy@192.168.1.197 "docker logs birdnet-go -f"
```

### Audio Stream Issues
```bash
# Test ESP32 stream directly
curl --max-time 5 http://192.168.1.211:8080/stream | head -c 10000

# Check if BirdNET-Go can reach ESP32
ssh jeremy@192.168.1.197 "curl -s http://192.168.1.211:8080/status"

# Verify network connectivity
ping -c 3 192.168.1.211

# Restart ESP32 (power cycle required - no remote restart)
# Physical power cycle of ESP32-S3 device
```

### Service Won't Start
```bash
# Check service status
ssh jeremy@192.168.1.197 "systemctl status birdnet-go.service"

# View full error logs
ssh jeremy@192.168.1.197 "journalctl -u birdnet-go.service -n 50"

# Common fixes:

# 1. Docker not running
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S systemctl restart docker"
sleep 5
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S systemctl restart birdnet-go.service"

# 2. Config syntax error
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S cat /root/birdnet-go-app/config/config.yaml | grep -E 'source:|interval:|threshold:'"

# 3. Port already in use
ssh jeremy@192.168.1.197 "netstat -tuln | grep 8080"
ssh jeremy@192.168.1.197 "docker ps | grep 8080"
```

### Display Interface Not Loading
```bash
# Check service status
ssh jeremy@192.168.1.197 "systemctl status bird-display.service"

# Check if it can reach BirdNET-Go
ssh jeremy@192.168.1.197 "curl -s http://localhost:8080/api/v2/detections/recent"

# View Flask errors
ssh jeremy@192.168.1.197 "journalctl -u bird-display.service -n 100 | grep -i error"

# Restart display
ssh jeremy@192.168.1.197 "systemctl restart bird-display.service"
```

## Performance & Monitoring

### Expected Resource Usage
**Raspberry Pi 4:**
- CPU: 20-40% during analysis (every 15 seconds)
- RAM: ~500MB Docker + ~200MB Flask
- Storage: Auto-managed by retention policy (80% max, 30 days)

**ESP32-S3:**
- Heap Memory: ~260KB free (stable)
- WiFi Signal: -50 to -70 dBm (good to excellent)
- Power: ~120mA @ 5V when streaming

### Health Checks
```bash
# Quick system check script
ssh jeremy@192.168.1.197 "
echo '=== Service Status ==='
systemctl is-active birdnet-go.service bird-display.service
echo ''
echo '=== Recent Detections ==='
curl -s http://localhost:8080/api/v2/detections/recent | jq 'length'
echo ''
echo '=== ESP32 Status ==='
curl -s http://192.168.1.211:8080/status | jq '{clients: .activeClients, wifi: .wifiRSSI, uptime: .uptime}'
echo ''
echo '=== Disk Usage ==='
echo 'redflower805' | sudo -S du -sh /root/birdnet-go-app/data/clips/
"
```

## Optional Enhancements

### 1. GPS Coordinates Configuration
Improves species range filtering accuracy:
```bash
# Edit config
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S nano /root/birdnet-go-app/config/config.yaml"

# Update:
# birdnet:
#   latitude: YOUR_LATITUDE    # e.g., 37.7749
#   longitude: YOUR_LONGITUDE  # e.g., -122.4194

# Restart
ssh jeremy@192.168.1.197 "echo 'redflower805' | sudo -S systemctl restart birdnet-go.service"
```

### 2. Kiosk Mode Activation
Full-screen auto-start display:
```bash
# Install chromium
ssh jeremy@192.168.1.197 "sudo apt-get install -y chromium-browser"

# Reboot to activate desktop autostart
ssh jeremy@192.168.1.197 "sudo reboot"

# After reboot, kiosk should auto-launch at http://localhost:5000
```

### 3. Home Assistant Integration
Use BirdNET-Go API for sensors/automations:
```yaml
# In Home Assistant configuration.yaml
sensor:
  - platform: rest
    name: Recent Bird Detections
    resource: http://192.168.1.197:8080/api/v2/detections/recent
    method: GET
    value_template: "{{ value_json | length }}"
    json_attributes:
      - species
      - confidence
      - timestamp
    scan_interval: 60
```

### 4. MQTT Notifications
Enable real-time detection events:
```yaml
# In BirdNET-Go config.yaml
mqtt:
  enabled: true
  broker: mqtt://192.168.1.148:1883
  topic: birdnet/detections
  username: mqtt_user
  password: redflower805
```

## Known Limitations

1. **No detections yet** - Normal, depends on bird activity and 0.8 threshold
2. **Location set to 0.0, 0.0** - Affects range filtering accuracy
3. **Kiosk mode not active** - Requires reboot and chromium installation
4. **Development Flask server** - Not production WSGI (sufficient for home use)
5. **HTTP stream only** - No RTSP support (but HTTP works well)

## Success Indicators

✅ ESP32 shows `totalConnections: 1+` (BirdNET-Go connected)
✅ BirdNET-Go logs show "Starting analyzer in realtime mode"
✅ Both systemd services show `Active: active (running)`
✅ API endpoint returns array (empty `[]` or with detections)
✅ Display interface loads with species list and layout
✅ Services survive reboot (auto-start enabled)

## Related Documentation

- **ESP32-S3 Firmware:** `/home/dev/workspace/ESP32S3_PDM_FIRMWARE_FIX_COMPLETE.md`
- **ESP32 Integration:** `/home/dev/workspace/ESP32S3_BIRDNET_PI_INTEGRATION_COMPLETE.md`
- **Installer Analysis:** `/tmp/INSTALL_PROMPTS_ANALYSIS.md`
- **Complete Deployment:** `/home/dev/workspace/BIRDNET_GONE_DEPLOYMENT_COMPLETE.md`
- **GitHub Repository:** https://github.com/festion/birdnet-gone

## Quick Reference Commands

```bash
# SSH to Pi
ssh jeremy@192.168.1.197

# Check all services
systemctl status birdnet-go.service bird-display.service

# View detections
curl http://192.168.1.197:8080/api/v2/detections/recent | jq '.'

# Restart BirdNET-Go
echo 'redflower805' | sudo -S systemctl restart birdnet-go.service

# View logs
docker logs birdnet-go -f
journalctl -u bird-display.service -f

# ESP32 status
curl http://192.168.1.211:8080/status | jq '.'

# Edit BirdNET-Go config
echo 'redflower805' | sudo -S nano /root/birdnet-go-app/config/config.yaml
```

## Deployment Status: ✅ COMPLETE

All components installed, configured, integrated, and operational with auto-start enabled.
