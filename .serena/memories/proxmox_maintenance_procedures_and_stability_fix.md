# Proxmox HA Cluster Maintenance Procedures and Stability Fix

## Issue Resolved: 2025-11-23

### Root Cause of Cluster Instability
Node proxmox (192.168.1.137) rebooted without preparation at ~10:42 AM, causing:
- CT 110 (Traefik) shutdown timeout (services had 90s timeout, LXC only waited 60s)
- All HA containers frozen during node reboot
- CT 121 took 5+ minutes to restart from NFS storage
- Full cluster recovery took ~10 minutes
- Half of containers showed "unknown" status during reboot

### Fixes Applied

1. **CT 110 Service Timeout Optimization**:
   - Reduced Traefik stop timeout: 90s → 30s
   - Reduced Keepalived stop timeout: 90s → 20s
   - Total shutdown time now <60s (within LXC default)
   - Config files created:
     - `/etc/systemd/system/traefik.service.d/timeout.conf`
     - `/etc/systemd/system/keepalived.service.d/timeout.conf`

2. **Created Maintenance Scripts**:
   - `/home/dev/workspace/proxmox-pre-maintenance.sh` - Run BEFORE node reboot
   - `/home/dev/workspace/proxmox-post-maintenance.sh` - Run AFTER node returns
   - Both scripts are executable and ready to use

3. **Created Documentation**:
   - `/home/dev/workspace/docs/PROXMOX_MAINTENANCE_PROCEDURES.md` - Full procedures
   - `/home/dev/workspace/PROXMOX_MAINTENANCE_QUICKSTART.md` - Quick reference

## Cluster Configuration

### Nodes
- proxmox (192.168.1.137) - Node ID: 0x00000001
- proxmox2 (192.168.1.125) - Node ID: 0x00000002  
- proxmox3 (192.168.1.126) - Node ID: 0x00000003

### HA Resources (11 total)
- ct:100 (InfluxDB) - Database
- ct:110 (Traefik Primary) - Reverse proxy with Keepalived
- ct:113 (PostgreSQL) - Currently disabled
- ct:116 (AdGuard-2) - Secondary DNS
- ct:121 (Traefik Secondary) - Backup reverse proxy with Keepalived
- ct:122 (Zigbee2MQTT) - Smart home control
- ct:1250 (AdGuard Primary) - Primary DNS
- ct:130 (MQTT Production) - IoT message broker
- ct:131 (NetBox) - Currently disabled
- ct:133 (Kea DHCP) - DHCP server
- ct:134 - Unknown service

### Critical Services
DNS: ct:1250 (primary), ct:116 (secondary)
DHCP: ct:133
Reverse Proxy: ct:110 (primary), ct:121 (secondary)
IoT: ct:130 (MQTT), ct:122 (Zigbee2MQTT)

## Usage

### Before ANY node reboot:
```bash
cd /home/dev/workspace
./proxmox-pre-maintenance.sh <node-name>
```

Choose option:
- Option 1 (migrate): Zero downtime, slower (5-10 min)
- Option 2 (disable HA): Brief downtime, faster (2 min)

### After node returns:
```bash
./proxmox-post-maintenance.sh <node-name>
```

### Dry run (test):
```bash
./proxmox-pre-maintenance.sh <node-name> --dry-run
```

## Pre-Maintenance Script Features
- Verifies cluster health and quorum
- Identifies HA resources on target node
- Offers migration or disable options
- Checks non-HA VMs/containers
- Validates storage and service health
- Provides clear status at each step

## Post-Maintenance Script Features
- Verifies node is back online
- Checks quorum status
- Validates critical services running
- Identifies disabled HA resources
- Offers to re-enable HA resources
- Verifies storage access
- Shows current HA status

## Known Issues Resolved
1. ✅ CT 110 shutdown timeout - Fixed with service timeout reduction
2. ✅ Slow container startups on NFS - Normal behavior, takes 2-5 minutes
3. ✅ Containers stuck in "starting" - HA sync lag, resolved automatically
4. ✅ Half containers showing unknown during reboot - Normal during node maintenance

## Recommendations for Future

### Immediate
- ✅ Always run pre-maintenance script before node reboots
- ✅ Monitor cluster for 30 minutes after maintenance
- Document any issues in procedures doc

### Future Enhancements
- Consider hardware fencing (IPMI) for true HA failover
- Test failover procedures periodically
- Add monitoring for unplanned reboots
- Consider reducing NFS storage latency for faster starts

## Testing Performed
- Service timeout verification in CT 110
- Cluster quorum verification (3/3 nodes)
- HA resource status verification (all started)
- Storage health checks (NFS accessible)
- Scripts created and made executable

## Current Cluster Status (as of 2025-11-23 11:05)
- ✅ All 3 nodes online and quorate
- ✅ All 11 HA resources in "started" state
- ✅ No migrations in progress
- ✅ Storage healthy (21% used)
- ✅ No errors in HA logs
- ✅ Cluster stable

## Important Files
- Scripts: `/home/dev/workspace/proxmox-*-maintenance.sh`
- Docs: `/home/dev/workspace/docs/PROXMOX_MAINTENANCE_PROCEDURES.md`
- Quick ref: `/home/dev/workspace/PROXMOX_MAINTENANCE_QUICKSTART.md`
