# BirdNET-Go Installation and Configuration

## System Overview
- **Device**: Raspberry Pi at 192.168.1.80
- **OS**: Raspberry Pi OS (Debian Bookworm)
- **Architecture**: ARM64 (aarch64)
- **Installation Method**: Official Docker installation (not custom build)
- **Access**: Root SSH key authentication enabled

## Installation Process

### Initial Setup
- **Root user created** with password: `redflower805`
- **SSH key authentication** configured for root access
- **User groups**: root added to docker, audio, and adm groups

### Installation Method Used
**IMPORTANT**: Used official installation script (not custom builds):
```bash
curl -fsSL https://github.com/tphakala/birdnet-go/raw/main/install.sh -o install.sh
bash ./install.sh
```

Selected options:
1. Install using existing data and configuration
2. Use sound card (USB microphone)

### Dependencies Installed
- Docker.io and containerd
- alsa-utils, curl, bc, jq, apache2-utils
- netcat-openbsd
- All required system packages

## Hardware Configuration

### USB Microphone
- **Model**: Texas Instruments PCM2902 Audio Codec (ID 08bb:2902)
- **ALSA Device**: `hw:2,0` / `plughw:2,0`
- **Verification**: `lsusb | grep -i audio` shows USB PnP Sound Device
- **Docker Access**: Container has `/dev/snd` device access

## Docker Configuration

### Container Details
- **Image**: `ghcr.io/tphakala/birdnet-go:nightly`
- **Container Name**: `birdnet-go`
- **Restart Policy**: `unless-stopped`
- **Port Mapping**: `8080:8080`
- **Volume Mount**: `/etc/birdnet-go:/config`
- **Device Access**: `--device /dev/snd` for audio hardware

### Container Command
```bash
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -v /etc/birdnet-go:/config --device /dev/snd \
  ghcr.io/tphakala/birdnet-go:nightly
```

## Optimized Configuration Settings

### Location (Critical for Species Accuracy)
```yaml
latitude: 33.052709   # North Texas - exact coordinates provided
longitude: -96.544809 # Wylie, Texas area
```

### Detection Parameters (Optimized for Sensitivity)
```yaml
sensitivity: 1.2      # Increased from 1.0 (range: 0.1-1.5)
threshold: 0.7        # Lowered from 0.8 (range: 0.0-1.0)
overlap: 1.5          # Default overlap between chunks
locale: en-us         # English US labels
```

### Audio Configuration
```yaml
source: "plughw:2,0"  # Specific USB microphone
useaudiocore: false   # Using legacy audio system
soundlevel:
  enabled: true       # Monitor audio input levels
  interval: 10        # Check every 10 seconds
```

### Performance Settings
```yaml
threads: 0            # Use all available CPU cores
processingtime: true  # Report processing time for monitoring
usexnnpack: true      # Enable XNNPACK acceleration
```

### Advanced Features Enabled
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

### Audio Export Settings
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
- **Status**: Web interface working with proper CSS/styling

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

### Backup Configuration
- Original config backed up to `/config/config.yaml.backup`
- Configuration stored in `/etc/birdnet-go/config.yaml`

## Troubleshooting Notes

### Common Issues Resolved
1. **CSS/Styling Problems**: Resolved by using official Docker image instead of custom builds
2. **Audio Device Not Found**: Fixed by using `plughw:2,0` instead of `hw:2,0`
3. **Location-based Species**: Resolved by setting exact coordinates

### Service Management
```bash
# Check status
docker ps | grep birdnet-go
docker logs birdnet-go --tail 20

# Restart service
docker restart birdnet-go

# Update configuration
docker exec birdnet-go vi /config/config.yaml
docker restart birdnet-go

# Check audio devices
docker exec birdnet-go ls -la /dev/snd/
```

### Performance Verification
- USB microphone detected: ✅ "USB PnP Sound Device, USB Audio :2,0"
- Web interface accessible: ✅ HTTP 200 response
- Location services active: ✅ Range filter rebuilt successfully
- Audio monitoring: ✅ Sound level monitoring started

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

## Future Maintenance
1. **Regular updates**: Check for new Docker image versions
2. **Storage monitoring**: Monitor clip storage usage
3. **Performance tuning**: Adjust sensitivity/threshold based on results
4. **Species list maintenance**: Review and update include/exclude lists
5. **Integration options**: Consider MQTT, BirdWeather, or eBird integration

## Integration Ready
The system is configured and ready for integration with:
- Home Assistant (via MQTT if needed)
- BirdWeather (requires account setup)
- eBird (requires API key)
- External monitoring systems (Prometheus endpoint available)