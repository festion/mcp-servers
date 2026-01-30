# IP Conflict Incident - Resolved
**Date:** 2025-11-23
**Incident:** TrueNAS (192.168.1.98) IP conflict with PitBoss Grill

## Summary
This morning, the TrueNAS server at 192.168.1.98 experienced an IP address conflict with the PitBoss Grill (MAC: 30:83:98:76:95:e8). This caused cascading failures in the Proxmox cluster due to shared storage unavailability, requiring emergency reboots and HA service disabling to restore services.

## Root Cause
**Critical infrastructure devices lacked DHCP reservations**, allowing dynamic IP assignment that could conflict with statically configured systems:

- TrueNAS (192.168.1.98) - **NO RESERVATION**
- Proxmox Node 1 (192.168.1.137) - **NO RESERVATION**
- Proxmox Node 2 (192.168.1.125) - **NO RESERVATION**
- Home Assistant (192.168.1.155) - **NO RESERVATION**
- Kea DHCP Server (192.168.1.133) - **NO RESERVATION**
- PitBoss Grill - **NO RESERVATION**

The PitBoss Grill requested DHCP and was assigned 192.168.1.98, conflicting with TrueNAS's static IP.

## Resolution Actions Taken

### 1. Cluster Health Verification ✓
- All 3 Proxmox nodes online and healthy (health score: 100)
- Cluster quorum: 3/3 nodes
- No threshold violations detected
- All critical services running

### 2. DHCP Reservations Added ✓
Added static DHCP reservations for all critical infrastructure:

| IP Address      | MAC Address       | Hostname         | Purpose |
|-----------------|-------------------|------------------|---------|
| 192.168.1.98    | e0:51:d8:18:9d:32 | truenas          | TrueNAS Storage Server |
| 192.168.1.137   | 80:3f:5d:fc:ef:74 | proxmox          | Proxmox Node 1 |
| 192.168.1.125   | f4:4d:ad:05:57:88 | proxmox2         | Proxmox Node 2 |
| 192.168.1.155   | 02:02:88:54:af:79 | haos             | Home Assistant OS |
| 192.168.1.133   | bc:24:11:5d:5b:58 | kea-dhcp-1       | Kea DHCP Server |
| 192.168.1.99    | 30:83:98:76:95:e8 | pitboss-grill    | PitBoss Grill |

### 3. Configuration Backup ✓
- Kea configuration backed up to `/etc/kea/kea-dhcp4.conf.backup-YYYYMMDD-HHMMSS`
- New configuration validated and deployed
- Kea DHCP service restarted successfully

## Prevention Measures

### Immediate
1. ✅ All critical infrastructure now has DHCP reservations
2. ✅ PitBoss Grill assigned dedicated IP (192.168.1.99)
3. ✅ Configuration backed up before changes

### Ongoing Recommendations
1. **Regular DHCP Audit**: Monthly review of DHCP reservations vs. actual network devices
2. **Network Documentation**: Maintain up-to-date IP allocation spreadsheet
3. **Monitoring**: Consider implementing network monitoring for:
   - Duplicate IP detection
   - Critical infrastructure availability checks
   - DHCP pool exhaustion warnings

### Best Practices Going Forward
1. **All infrastructure devices should have DHCP reservations**
2. **Never rely on static IP configuration without DHCP reservation**
3. **Document MAC addresses for all permanent network devices**
4. **Keep DHCP pool range separate from infrastructure IPs**

## Current Status
- ✅ Cluster healthy and stable
- ✅ All containers and VMs running
- ✅ DHCP reservations active
- ✅ No IP conflicts detected
- ✅ Shared storage accessible from all nodes

## Files Modified
- `/etc/kea/kea-dhcp4.conf` on kea-dhcp-1 (192.168.1.133)

## Notes for Future Reference
- The incident highlighted the importance of DHCP reservations for ALL permanent infrastructure
- PitBoss Grill was not expected to request DHCP, but devices can change behavior after firmware updates
- Proxmox HA must be carefully managed during storage outages
- Always backup DHCP configuration before major changes

## Additional Infrastructure to Consider Adding Reservations
Consider adding reservations for:
- Omada Controller (192.168.1.47) - Already has reservation ✓
- Network switches
- Access points (already reserved ✓)
- Any other IoT devices that should maintain consistent IPs
