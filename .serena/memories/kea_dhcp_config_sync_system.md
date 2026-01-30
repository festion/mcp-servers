# Kea DHCP Configuration Sync System

## Problem Solved
Devices were getting different IPs depending on which Kea server responded to their DHCP request. This was caused by:
1. Kea HA only syncs **leases**, NOT **configuration files**
2. Host reservations are stored in config files, not the lease database
3. When configs drifted, the secondary server had no reservations and assigned random pool IPs

## Solution Deployed (2025-12-17)

### Sync Script
- **Location**: `/usr/local/bin/kea-config-sync` on kea-dhcp-1 (192.168.1.133)
- **Language**: Python 3

### Features
- Auto-detects local vs remote execution
- Duplicate MAC resolution: Primary's IP wins
- Duplicate IP resolution: Primary's reservation wins  
- JSON validation before applying changes
- Atomic updates (write to .new, then mv)
- Automatic rollback on failure
- Comprehensive logging

### Paths
| Purpose | Path |
|---------|------|
| Script | `/usr/local/bin/kea-config-sync` |
| Logs | `/var/log/kea-sync/sync-YYYYMMDD.log` |
| Backups | `/var/backups/kea-sync/kea-dhcp4.conf.{host}.{timestamp}` |
| Cron | `/etc/cron.d/kea-config-sync` |
| Logrotate | `/etc/logrotate.d/kea-sync` |

### Usage
```bash
kea-config-sync           # Normal sync
kea-config-sync -n        # Dry-run
kea-config-sync -f        # Force sync even if identical
kea-config-sync -q        # Quiet mode (errors only)
```

### Cron Schedule
- Every minute: Quick check, only syncs if configs differ
- Every 15 minutes: Guaranteed sync with logging

### SSH Setup
- Primary (192.168.1.133) has SSH key to access secondary (192.168.1.134)
- Key location: `/root/.ssh/id_rsa` on kea-dhcp-1

## Kea HA Configuration
- Mode: Load-balancing
- Primary: kea-dhcp-1 (192.168.1.133)
- Secondary: kea-dhcp-2 (192.168.1.134)
- Config path: `/etc/kea/kea-dhcp4.conf`
- Service name: `isc-kea-dhcp4-server`

## Related Issues Fixed Same Session
- PBS storage config pointed to wrong IP (192.168.1.31 → 192.168.1.171)
- Added DHCP reservation for PBS container (bc:24:11:23:16:5e → 192.168.1.171)
- Updated prusa-mini reservation (192.168.1.114 → 192.168.1.83)
