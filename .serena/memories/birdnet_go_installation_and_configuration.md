# BirdNET-Go Installation and Configuration

## System Overview
- **Device**: Raspberry Pi at 192.168.1.80
- **OS**: Raspberry Pi OS (Debian Bookworm)
- **Architecture**: ARM64 (aarch64)
- **Installation Method**: Official Docker installation (not custom build)
- **Access**: Root SSH key authentication enabled
- **Last Updated**: October 13, 2025

## Hardware Configuration

### USB Microphone (Active Audio Source)
- **Model**: Texas Instruments PCM2902 Audio Codec (ID 08bb:2902)
- **ALSA Device**: `plughw:2,0` (Card 2, Device 0)
- **Hardware Path**: `/dev/snd/pcmC2D0c`
- **Status**: ✅ Active and configured as primary audio source
- **Verification**: `lsusb | grep -i audio` shows USB PnP Sound Device
- **Docker Access**: Container has `/dev/snd` device access via `--device /dev/snd`

## Docker Configuration

### Container Details
- **Image**: `ghcr.io/tphakala/birdnet-go:nightly`
- **Container Name**: `birdnet-go`
- **Container ID**: 12c57f6974606681386cea7de37bf6aeb6fc0f394edc14956def5a22d2a9f06f
- **Restart Policy**: `unless-stopped`
- **Port Mapping**: `8080:8080`
- **Volume Mount**: `/etc/birdnet-go:/config`
- **Device Access**: `--device /dev/snd` for audio hardware
- **Last Recreated**: October 13, 2025 20:40 UTC

### Container Command
```bash
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -v /etc/birdnet-go:/config --device /dev/snd \
  ghcr.io/tphakala/birdnet-go:nightly
```

### Audio Source Registration
```
2025/10/13 20:40:08 INFO Registered audio source 
  component=registry 
  id=audio_card_a8229577 
  display_name=plughw:2,0 
  safe=plughw:2,0
```

## Audio Configuration

### Current Active Configuration
```yaml
audio:
  source: "plughw:2,0"  # USB microphone (Card 2, Device 0)
  ffmpegpath: /usr/bin/ffmpeg
  soxpath: /usr/bin/sox
  useaudiocore: false   # Using legacy audio system
soundlevel:
  enabled: true         # Monitor audio input levels
  interval: 10          # Check every 10 seconds
```

### Configuration History
- **2025-10-08**: Initially configured with HTTP stream from `http://192.168.1.204:8080/stream`
- **2025-10-13 20:24**: Temporarily updated to ESP32-S3 `http://192.168.1.211:8080/stream`
- **2025-10-13 20:39**: Reverted to USB microphone `plughw:2,0` (correct configuration)

### Backups Created
- `/etc/birdnet-go/config.yaml.backup-esp32-20251013-203936` - Before ESP32 reversion
- Previous backups available in `/etc/birdnet-go/`

## Location Settings (Critical for Species Accuracy)
```yaml
latitude: 33.052709   # North Texas - exact coordinates
longitude: -96.544809 # Wylie, Texas area
```

## Detection Parameters (Optimized for Sensitivity)
```yaml
sensitivity: 1.2      # Increased from 1.0 (range: 0.1-1.5)
threshold: 0.7        # Lowered from 0.8 (range: 0.0-1.0)
overlap: 1.5          # Default overlap between chunks
locale: en-us         # English US labels
```

## Performance Settings
```yaml
threads: 0            # Use all available CPU cores
processingtime: true  # Report processing time for monitoring
usexnnpack: true      # Enable XNNPACK acceleration
```

## Advanced Features
```yaml
dynamicthreshold:
  enabled: true       # Adaptive confidence thresholds
  trigger: 0.90       # Activate at 90% confidence
  min: 0.20          # Never go below 20%
  validhours: 24     # Consider 24 hours of data

privacyfilter:
  enabled: true       # Prevent human voice recording
  confidence: 0.05    # Detection threshold

dogbarkfilter:
  enabled: true       # Filter out dog barks
  confidence: 0.1     # Detection threshold
  remember: 5         # Remember for 5 minutes
```

## Audio Export Settings
```yaml
export:
  enabled: true       # Save audio clips of detections
  path: clips/        # Storage location
  type: wav          # Audio format
  bitrate: 96k       # Compression setting
  retention:
    policy: usage     # Delete based on disk usage
    maxusage: 80%    # Delete when 80% full
    minclips: 10     # Keep at least 10 clips per species
```

## Network and Web Access

### Web Interface
- **Direct Access**: http://192.168.1.80:8080
- **Caddy Proxy**: https://birdnet.internal.lakehouse.wtf
- **Status**: ✅ Web interface operational

### Caddy Configuration
Already configured in `/etc/caddy/Caddyfile`:
```
@birdnet host birdnet.internal.lakehouse.wtf
handle @birdnet {
    reverse_proxy 192.168.1.80:8080
}
```

## Monitoring and Maintenance

### System Monitoring
```yaml
monitoring:
  enabled: true
  checkinterval: 60
  cpu: { enabled: true, warning: 85.0, critical: 95.0 }
  memory: { enabled: true, warning: 85.0, critical: 95.0 }
  disk: { enabled: true, warning: 85.0, critical: 95.0 }
```

### Log Configuration
```yaml
log:
  enabled: true
  path: birdnet.log
  rotation: daily
  maxsize: 1048576
  rotationday: "Sunday"
```

## Service Management

### Check Status
```bash
ssh root@192.168.1.80
docker ps | grep birdnet-go
docker logs birdnet-go --tail 20
```

### Restart Service
```bash
ssh root@192.168.1.80
docker restart birdnet-go
```

### Update Configuration
```bash
ssh root@192.168.1.80
vi /etc/birdnet-go/config.yaml
docker restart birdnet-go
```

### Check Audio Devices
```bash
ssh root@192.168.1.80
docker exec birdnet-go ls -la /dev/snd/
lsusb | grep -i audio
```

### Recreate Container (if needed)
```bash
ssh root@192.168.1.80
docker stop birdnet-go
docker rm birdnet-go
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -v /etc/birdnet-go:/config --device /dev/snd \
  ghcr.io/tphakala/birdnet-go:nightly
```

## Related Systems

### ESP32-S3 Microphone (Separate System)
- **IP**: 192.168.1.211
- **Purpose**: Wireless microphone for **BirdNET-Pi** (not BirdNET-Go)
- **Target**: Raspberry Pi at 192.168.1.197
- **Status**: ✅ Configured for BirdNET-Pi, not connected to BirdNET-Go

### BirdNET-Pi (Separate System)
- **Host**: 192.168.1.197
- **Audio Source**: ESP32-S3 HTTP stream (`http://192.168.1.211:8080/stream`)
- **User**: jeremy
- **Purpose**: Primary bird detection system using wireless microphone
- **Status**: ✅ Active and recording

## System Roles

**BirdNET-Go (This System):**
- Uses USB microphone (`plughw:2,0`)
- Monitors location: 192.168.1.80
- Purpose: Secondary/backup bird detection
- Web: http://192.168.1.80:8080

**BirdNET-Pi (Separate System):**
- Uses ESP32-S3 wireless microphone
- Monitors location: 192.168.1.197
- Purpose: Primary bird detection
- Web: http://192.168.1.197:8081

## Troubleshooting Notes

### Audio Device Warnings (Normal)
During container startup, you may see:
```
⚠️ Audio device validation failed: configured audio device 'plughw:2,0' not found
```
This warning can be ignored if the audio source registers successfully:
```
INFO Registered audio source ... display_name=plughw:2,0 safe=plughw:2,0
```

### Common Issues
1. **CSS/Styling Problems**: Resolved by using official Docker image
2. **Audio Device Not Found**: Fixed by using `plughw:2,0` instead of `hw:2,0`
3. **Location-based Species**: Resolved by setting exact coordinates
4. **Container Missing /dev/snd**: Fixed by recreating container with `--device /dev/snd`

### Performance Verification
- USB microphone detected: ✅ "USB PnP Sound Device, USB Audio :2,0"
- Audio source registered: ✅ `plughw:2,0`
- Web interface accessible: ✅ HTTP 200 response
- Container has device access: ✅ `/dev/snd/pcmC2D0c` present
- Sound level monitoring: ✅ Active

## Security Settings
- Basic auth: Disabled
- OAuth: Disabled  
- AutoTLS: Disabled (using Caddy for SSL)
- Privacy filter: Enabled
- CSRF protection: Active

## Expected Performance
With optimized settings:
- **Higher detection rate** due to lowered threshold (0.7)
- **Better sensitivity** with increased sensitivity (1.2)
- **Accurate species filtering** using exact North Texas coordinates
- **Quality audio input** from dedicated USB microphone
- **Real-time monitoring** of processing performance

## Integration Options
The system is configured and ready for integration with:
- Home Assistant (via MQTT if needed)
- BirdWeather (requires account setup)
- eBird (requires API key)
- External monitoring systems (Prometheus endpoint available)

## Notes
- This system uses USB microphone for local bird detection
- ESP32-S3 wireless microphone is used by BirdNET-Pi (separate system)
- Both systems operate independently and serve different monitoring locations
