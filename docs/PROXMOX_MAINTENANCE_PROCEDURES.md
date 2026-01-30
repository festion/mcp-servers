# Proxmox HA Cluster Maintenance Procedures

## Overview

This document describes the proper procedures for performing maintenance on Proxmox HA cluster nodes to avoid unintended container migrations, timeouts, and instability.

## Problem Statement

When a Proxmox node reboots without proper preparation:
- HA-managed containers are forcibly frozen
- Services may not shutdown gracefully within the default 60s timeout
- Containers get migrated unnecessarily
- Services can get stuck in "starting" state
- Can take 5-10 minutes for full cluster recovery

## Critical Services Configuration

### CT 110 (Traefik with Keepalived)

**Issue**: Both Traefik and Keepalived have 90-second stop timeouts, but LXC default shutdown is only 60 seconds.

**Fix Applied**: Reduced service timeouts
- Traefik: 30 seconds
- Keepalived: 20 seconds

**Configuration files created**:
```
/etc/systemd/system/traefik.service.d/timeout.conf
/etc/systemd/system/keepalived.service.d/timeout.conf
```

## Pre-Maintenance Procedure

### Prerequisites
- Cluster must have quorum (at least 2 of 3 nodes online)
- All storage must be accessible
- No ongoing migrations or HA operations

### Automated Script

Location: `/home/dev/workspace/proxmox-pre-maintenance.sh`

**Usage**:
```bash
# Dry run (see what would happen)
./proxmox-pre-maintenance.sh <node-name> --dry-run

# Execute pre-maintenance
./proxmox-pre-maintenance.sh <node-name>
```

**What it does**:
1. Verifies cluster health and quorum
2. Identifies HA resources on the target node
3. Offers two options:
   - **Migrate** resources to other nodes (zero downtime)
   - **Disable** HA temporarily (brief downtime, faster)
4. Checks for non-HA VMs/containers
5. Verifies storage and service health

### Manual Pre-Maintenance Steps

If you prefer to do it manually:

#### Option A: Migrate HA Resources (Recommended)
```bash
# List HA resources on the node
pvesh get /cluster/ha/status/current | grep "node-name"

# Migrate each resource
ha-manager migrate ct:110
ha-manager migrate ct:134

# Wait for migrations to complete
watch -n 2 'pvesh get /cluster/ha/status/current'
```

#### Option B: Temporarily Disable HA
```bash
# Disable HA for specific resources
ha-manager set ct:110 --state disabled
ha-manager set ct:134 --state disabled

# Verify
pvesh get /cluster/ha/resources
```

## Performing Maintenance

Once pre-maintenance is complete:

```bash
# Reboot the node
ssh root@<node-name> reboot

# Or perform other maintenance tasks
ssh root@<node-name> "apt update && apt upgrade -y && reboot"
```

## Post-Maintenance Procedure

### Automated Script

Location: `/home/dev/workspace/proxmox-post-maintenance.sh`

**Usage**:
```bash
./proxmox-post-maintenance.sh <node-name>
```

**What it does**:
1. Verifies node is back online
2. Checks quorum status
3. Verifies critical services (pve-ha-lrm, pve-ha-crm, corosync, etc.)
4. Identifies any disabled HA resources
5. Offers to re-enable disabled resources
6. Verifies storage access
7. Shows current HA status

### Manual Post-Maintenance Steps

```bash
# Check node status
pvecm nodes

# Verify quorum
pvecm status

# Check HA status
pvesh get /cluster/ha/status/current

# Re-enable HA resources (if disabled)
ha-manager set ct:110 --state started
ha-manager set ct:134 --state started

# Verify all services running
pvesh get /cluster/ha/status/current
```

## Monitoring After Maintenance

Monitor the cluster for 15-30 minutes after maintenance:

```bash
# Watch cluster status
watch -n 2 'pvecm status'

# Watch HA resources
watch -n 2 'pvesh get /cluster/ha/status/current'

# Check for errors
journalctl -u pve-ha-lrm -u pve-ha-crm -f
```

## Troubleshooting

### Container Stuck in "Starting" State

**Symptoms**: HA status shows resource as "starting" for >5 minutes

**Resolution**:
```bash
# Check actual container status
pct status <vmid>

# If running, the HA manager will eventually sync (wait 5-10 min)

# If stuck, check logs
journalctl -u pve-ha-lrm | grep <vmid>

# Last resort: manually restart HA services
systemctl restart pve-ha-lrm pve-ha-crm
```

### Container Won't Shutdown

**Symptoms**: `lxc-stop` timeout errors during shutdown

**Resolution**:
1. Check service timeouts inside container are < 60s total
2. Reduce systemd service TimeoutStopSec values
3. Example for any service:
```bash
mkdir -p /etc/systemd/system/<service>.service.d
cat > /etc/systemd/system/<service>.service.d/timeout.conf << EOF
[Service]
TimeoutStopSec=30s
EOF
systemctl daemon-reload
```

### Loss of Quorum

**Symptoms**: Cluster shows "Quorate: No"

**Resolution**:
```bash
# If 2 of 3 nodes are online but quorum is lost
pvecm expected 2

# This is temporary - restore the third node ASAP
```

## HA Resources Reference

Current HA-managed resources in cluster:

| Resource | Description | Node Preference | Notes |
|----------|-------------|-----------------|-------|
| ct:100 | InfluxDB | proxmox2 | Database - handle carefully |
| ct:110 | Traefik Primary | proxmox | Has Keepalived - slow shutdown |
| ct:113 | PostgreSQL | proxmox2 | Currently disabled |
| ct:116 | AdGuard-2 | proxmox3 | DNS - critical |
| ct:121 | Traefik Secondary | proxmox2 | Has Keepalived - slow shutdown |
| ct:122 | Zigbee2MQTT | proxmox3 | IoT - handle carefully |
| ct:1250 | AdGuard Primary | proxmox3 | DNS - critical |
| ct:130 | MQTT Production | proxmox3 | IoT - critical |
| ct:131 | NetBox | proxmox2 | Currently disabled |
| ct:133 | Kea DHCP | proxmox3 | Network - critical |
| ct:134 | (Unknown) | proxmox | - |

## Best Practices

1. **Always run pre-maintenance procedure** before rebooting nodes
2. **Schedule maintenance** during low-traffic periods
3. **Never reboot multiple nodes simultaneously**
4. **Verify quorum** before and after maintenance
5. **Monitor for 30 minutes** after node returns
6. **Keep service shutdown times** well under 60 seconds
7. **Document all changes** to HA resource configurations
8. **Test failover** periodically to verify HA functionality

## Emergency Procedures

### Unplanned Node Reboot

If a node reboots unexpectedly:

1. **Don't panic** - HA will handle it, but slowly
2. **Verify quorum** from another node
3. **Monitor HA status** - containers will automatically failover
4. **Allow 5-10 minutes** for full recovery
5. **Check logs** after recovery to identify root cause

### Split-Brain Prevention

Currently no fencing is configured. Consider adding:
- IPMI-based fencing for hardware control
- Watchdog-based fencing
- Network-based fencing

## Change Log

- **2025-11-23**: Initial procedures created
- **2025-11-23**: Fixed CT 110/121 shutdown timeouts (Traefik/Keepalived)
- **2025-11-23**: Created automated pre/post maintenance scripts

## References

- [Proxmox HA Manager Documentation](https://pve.proxmox.com/wiki/High_Availability)
- [Proxmox Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)
- Scripts: `/home/dev/workspace/proxmox-pre-maintenance.sh`
- Scripts: `/home/dev/workspace/proxmox-post-maintenance.sh`
