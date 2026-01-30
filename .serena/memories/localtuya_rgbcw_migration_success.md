# LocalTuya RGBCW Light Migration - POC Success

## Status: POC SUCCESSFUL ✅

**Date**: 2025-11-07
**Home Assistant Version**: 2025.11.0
**Hass OS VM**: 114 at 192.168.1.155

---

## Problem Summary

### Root Cause
All 11 RGBCW kitchen/living room lights became unavailable after HA 2025.11.0 upgrade:
- **Integration**: Tuya Local v2025.10.1
- **Incompatibility**: Tuya Local not compatible with HA 2025.11.0
- **Attempted Fix**: Updated Tuya Local from 2025.9.0 to 2025.10.1 (failed)

### Impact
- 11 kitchen/living room RGBCW lights unavailable
- Light groups unavailable
- Automations affecting these lights broken

---

## Solution: Migrate to LocalTuya

### LocalTuya Integration
- **Version**: v5.2.3
- **Compatibility**: Works with HA 2025.11.0
- **Type**: Custom integration, UI-configured
- **Status**: Already installed, ready to use

---

## POC Device: Kitchen Light 6

### Device Details
- **Original Entity**: `light.rgbcw_lightbulb6` (Tuya Local - UNAVAILABLE)
- **New Entity**: `light.kitchen_light_6_poc` (LocalTuya - WORKING)
- **IP Address**: `192.168.1.14`
- **Device ID**: `eb814fbee030987879vxpt`
- **Local Key**: `&b#RiD(MuI`55SHT`
- **Protocol**: `3.3`

### DPS Configuration (Successful)
All RGBCW lights use these same DPS mappings:

| Parameter | DP ID | Type | Range/Notes |
|-----------|-------|------|-------------|
| **Switch** | 20 | Boolean | On/off control |
| **Brightness** | 22 | Integer | 10-1000 |
| **Color Temperature** | 23 | Integer | 0-1000 (mireds: 153-370) |
| **Color** | 24 | String/JSON | RGBHSV hex value |
| **Color Mode** | 21 | String | white/colour/scene/music |

### POC Test Results ✅
All controls verified working:
- ✅ Turn on/off
- ✅ Brightness control (tested at 50% = 128/255)
- ✅ Color temperature control (tested at 2702K warm white)
- ✅ Supports color modes: color_temp
- ✅ Kelvin range: 2702K - 6535K
- ✅ No DecodeErrors or connection issues

---

## Critical Issue Resolved: Integration Conflict

### Problem
Initial LocalTuya configuration showed DecodeError:
```
ERROR: custom_components.localtuya.pytuya.DecodeError: Not enough data to unpack header
File: /config/custom_components/localtuya/pytuya/__init__.py, line 304
```

### Root Cause
Both Tuya Local AND LocalTuya trying to connect to same device (192.168.1.14) simultaneously, causing protocol conflicts.

### Solution
**Disabled all Tuya Local devices** before proceeding with LocalTuya migration:
- Settings → Devices & Services → Tuya Local
- Disabled all 11 RGBCW lightbulb device entries
- This freed the devices for LocalTuya to connect without conflict

---

## Migration Status

### Completed
- ✅ **1 light**: Kitchen Light 6 (192.168.1.14)

### Ready to Migrate (Network Reachable)
- 🔄 **RGBCW Lightbulb2** - 192.168.1.24 (Living Room)
- 🔄 **RGBCW Lightbulb9** - 192.168.1.10 (Kitchen)
- 🔄 **RGBCW Lightbulb4** - 192.168.1.18 (Living Room, protocol: auto)
- 🔄 **RGBCW Lightbulb5** - 192.168.1.19 (Living Room, protocol: auto)

### Not Network Reachable (Need to Power On)
- ⏸️ **RGBCW Lightbulb1** - 192.168.1.13 (Living Room)
- ⏸️ **RGBCW Lightbulb3** - 192.168.1.11 (Living Room)
- ⏸️ **RGBCW Lightbulb7** - 192.168.1.16 (Kitchen)
- ⏸️ **RGBCW Lightbulb8** - 192.168.1.15 (Kitchen)
- ⏸️ **RGBCW Lightbulb10** - 192.168.1.35 (Kitchen)
- ⏸️ **RGBCW Lightbulb11** - 192.168.1.17 (Kitchen)

---

## Migration Guide Location

Complete migration guide for remaining lights:
- `/tmp/localtuya_migration_remaining_lights.md`

Original POC configuration guides:
- `/tmp/localtuya_manual_dps_config.md`
- `/home/dev/workspace/home-assistant-config/docs/troubleshooting/localtuya_poc_configuration.md`

---

## Next Steps

### Immediate
1. Migrate remaining 4 reachable lights (Lightbulbs 2, 9, 4, 5)
2. Use same DPS configuration as POC device
3. Test each light after adding

### After Reachable Lights Migrated
1. Power on remaining 6 lights
2. Migrate to LocalTuya using same DPS config
3. Update `lights.yaml` with new entity IDs
4. Test all light groups and automations
5. Delete/remove old Tuya Local integration entries

---

## Technical Notes

### LocalTuya Entity Naming
- Entity IDs are based on friendly names entered during configuration
- POC used friendly name "Kitchen Light 6 (POC)" → `light.kitchen_light_6_poc`
- Recommend using consistent naming for migration

### Protocol Version
- Most devices use protocol `3.3`
- Lightbulbs 4 and 5 use protocol `auto`
- If device fails with 3.3, try `auto`

### DPS Manual Configuration
- LocalTuya auto-detection may fail with "no datapoints found"
- This is expected - click Submit anyway
- Manually configure DPS mappings as documented above

### Key Success Factor
**CRITICAL**: Disable/delete Tuya Local device entries BEFORE adding to LocalTuya to avoid protocol conflicts and DecodeErrors.

---

## Documentation References

### Source Files
- Device definition: `custom_components/tuya_local/devices/rgbcw_lightbulb.yaml`
- Light groups: `lights.yaml` (lines 76-126)
- LocalTuya integration: `custom_components/localtuya/`

### Configuration Storage
- LocalTuya config: `.storage/core.config_entries` (UI-managed)
- Tuya Local config: `.storage/core.config_entries` (now disabled)

---

## Lessons Learned

1. **Integration Conflicts**: Multiple integrations cannot access same Tuya device simultaneously
2. **Protocol Auto-Detection**: May fail, manual DPS configuration is reliable
3. **Network Verification**: Always verify device reachability before configuration attempts
4. **Protocol Version**: Some devices work better with "auto" than fixed version
5. **Migration Approach**: POC with single device first, then mass migration after validation

---

## Success Criteria Met ✅

- ✅ POC light shows as available (not unavailable)
- ✅ Can toggle light on/off
- ✅ Can control brightness
- ✅ Can adjust color temperature
- ✅ No DecodeErrors or connection issues
- ✅ Stable connection after HA restart

**POC VALIDATED - Ready for mass migration!**
