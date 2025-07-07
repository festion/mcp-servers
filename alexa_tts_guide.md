# Alexa TTS Service Guide - Working Methods

## Overview
Tested and verified methods for Alexa TTS announcements in Home Assistant production system.

**Test Date:** July 7, 2025  
**Home Assistant Version:** 2025.7.1  
**Integration Health:** 100.0%

## Available Alexa Devices

| Device | Entity ID | Volume | Status |
|--------|-----------|---------|---------|
| Jeremy's Echo Show 8 2nd Gen | `media_player.jeremy_s_echo_show_8_2nd_gen` | 40% | ✅ Working |
| Master Echo Dot | `media_player.master_echo_dot` | 40% | ✅ Working |
| Office Echo Dot | `media_player.office_echo_dot` | 10% | ✅ Working |

## Working TTS Methods

### ✅ Method 1: Notify Service (RECOMMENDED)
**Service:** `notify.alexa_media_[device_name]`  
**Status:** ✅ Tested and verified working

```yaml
service: notify.alexa_media_jeremy_s_echo_show_8_2nd_gen
data:
  message: "Your announcement message here"
  data:
    type: announce
```

**Example for each device:**
```yaml
# Jeremy's Echo Show 8
service: notify.alexa_media_jeremy_s_echo_show_8_2nd_gen
data:
  message: "Home Assistant system audit test"
  data:
    type: announce

# Master Echo Dot  
service: notify.alexa_media_master_echo_dot
data:
  message: "System audit complete"
  data:
    type: announce

# Office Echo Dot
service: notify.alexa_media_office_echo_dot
data:
  message: "Office announcement"
  data:
    type: announce
```

## Failed Methods (Do Not Use)

### ❌ Method 1: Direct TTS Service
**Service:** `tts.speak`  
**Status:** ❌ Returns 400 Bad Request

```yaml
# DO NOT USE - FAILS
service: tts.speak
data:
  entity_id: media_player.jeremy_s_echo_show_8_2nd_gen
  message: "Test message"
```

### ❌ Method 2: Alexa Media Play Media
**Service:** `alexa_media.play_media`  
**Status:** ❌ Returns 400 Bad Request

```yaml
# DO NOT USE - FAILS  
service: alexa_media.play_media
data:
  entity_id: media_player.jeremy_s_echo_show_8_2nd_gen
  media_content_type: custom
  media_content_id: "Test message"
```

## Best Practices

1. **Always use the notify service method** with `type: announce`
2. **Test volume levels** before production announcements
3. **Use device-specific notify services** for targeted announcements
4. **Monitor Alexa integration health** via `sensor.alexa_integration_health`

## Common Use Cases

### Appliance Notifications
```yaml
service: notify.alexa_media_master_echo_dot
data:
  message: "The washing machine cycle has completed"
  data:
    type: announce
```

### System Alerts
```yaml
service: notify.alexa_media_jeremy_s_echo_show_8_2nd_gen
data:
  message: "Home Assistant system health alert detected"
  data:
    type: announce
```

### Multi-Device Announcements
```yaml
# Send to multiple devices
service: notify.alexa_media_jeremy_s_echo_show_8_2nd_gen
data:
  message: "Announcement for all devices"
  data:
    type: announce
---
service: notify.alexa_media_master_echo_dot
data:
  message: "Announcement for all devices"
  data:
    type: announce
```

## Troubleshooting

### Integration Health Check
- Monitor: `sensor.alexa_integration_health` (should be 100%)
- Automation: `automation.health_monitor_alexa_integration_health_drop`

### Device Status Verification
Check media player states:
- `media_player.jeremy_s_echo_show_8_2nd_gen`
- `media_player.master_echo_dot`  
- `media_player.office_echo_dot`

### Common Issues
1. **400 Bad Request:** Use notify service instead of direct TTS
2. **No announcement:** Check device volume levels and network connectivity
3. **Integration offline:** Restart Alexa Media Player integration

## Production Implementation Notes

- **Tested:** July 7, 2025 during system audit
- **Reliability:** High - notify service method consistently works
- **Performance:** Immediate response, no delays observed
- **Error Handling:** Built-in retry mechanisms in automation recommended

---
**Last Updated:** July 7, 2025  
**Author:** Home Assistant System Audit  
**Status:** Production Ready