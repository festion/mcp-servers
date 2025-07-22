# ESPHome Device Connectivity Diagnostic and Fix
# Date: June 5, 2025
# Purpose: Address BLE Proxy connectivity issues

## ISSUE ANALYSIS
From error logs: "Can't connect to ESPHome API for bleproxy_with_lux @ 192.168.1.202"

## DISCOVERED CONFIGURATION
Two BLE proxy devices detected:
1. **master_bleproxy_with_lux** - WORKING (WiFi signal -56 dBm, active light sensor)
2. **bleproxy_with_lux** - FAILED (unavailable, 192.168.1.202 unreachable)

## ROOT CAUSE
Duplicate/old ESPHome device configuration causing connection attempts to non-existent device at 192.168.1.202

## RECOMMENDED ACTIONS

### Immediate Fix
1. Check ESPHome integration for duplicate device entries
2. Remove failed device configuration for "bleproxy_with_lux" at 192.168.1.202
3. Verify master device connectivity remains stable

### Network Diagnostics
```bash
# Check if device at 192.168.1.202 exists
ping 192.168.1.202

# Check ESPHome API port
telnet 192.168.1.202 6053

# Verify working device
ping [master_bleproxy_IP]
```

### ESPHome Integration Cleanup
1. Configuration > Integrations > ESPHome
2. Locate "bleproxy_with_lux" device
3. Remove or reconfigure with correct IP
4. Verify "master_bleproxy_with_lux" remains functional

## IMPACT ASSESSMENT
- **Working device**: master_bleproxy_with_lux (functional)
- **Failed device**: bleproxy_with_lux at 192.168.1.202 (should be removed)
- **Bluetooth proxy**: Still functional through working device
- **Error reduction**: Will eliminate recurring connection error messages

## NEXT STEPS
1. Remove failed ESPHome device configuration
2. Verify working BLE proxy continues functioning
3. Monitor logs for elimination of connection errors
4. Document working device configuration for reference

## SUCCESS CRITERIA
- No more "Can't connect to ESPHome API" errors in logs
- Bluetooth proxy functionality maintained through working device
- Cleaner error log without connection spam