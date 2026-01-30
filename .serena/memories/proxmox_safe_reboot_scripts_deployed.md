# Proxmox Safe Reboot and Health Monitoring Scripts

**Date**: 2025-11-25
**Cluster**: homelab-cluster (3 nodes)

## Incident Summary

On Nov 25, 2025, cascading reboots caused cluster instability twice:
1. Morning incident (~08:09-08:17): Node 2 rebooted unexpectedly, followed by manual reboot of Node 1
2. Second incident (~08:16-08:50): Triggered by testing safe-reboot script without dry-run flag

## Scripts Deployed

### 1. Safe Reboot Script
**Location**: `/usr/local/bin/proxmox-safe-reboot.sh` (all nodes)
**Source**: `/home/dev/workspace/proxmox-safe-reboot.sh`

**Usage**:
```bash
# Check cluster health only (ALWAYS run this first)
proxmox-safe-reboot.sh --check

# Actually reboot (only after --check passes)
proxmox-safe-reboot.sh
```

**Checks performed**:
1. Cluster quorum (corosync-quorumtool)
2. All nodes online
3. Corosync health
4. No active HA migrations

**Key fix**: Uses `grep -E "Quorate:\s+Yes"` to handle variable whitespace in corosync output.

### 2. Health Monitoring Script
**Location**: `/usr/local/bin/check-cluster-health.sh` (all nodes)
**Source**: `/home/dev/workspace/check-cluster-health.sh`
**Cron**: `*/5 * * * *` (every 5 minutes)

**Monitors**:
- Cluster quorum
- Node availability (expects 3 nodes)
- Storage health
- CPU load (>80% threshold)
- Memory usage (>85% threshold)
- Recent HA migrations (>5/hour)

**Alert cooldown**: 30 minutes per alert type
**State file**: `/var/tmp/cluster-health-state`

## Cluster Nodes

| Node | IP | Role |
|------|-----|------|
| proxmox | 192.168.1.137 | Primary |
| proxmox2 | 192.168.1.125 | Secondary |
| proxmox3 | 192.168.1.126 | Secondary |

## Safe Reboot Procedure

1. **Pre-check**: `ssh root@NODE "proxmox-safe-reboot.sh --check"`
2. **Wait for all checks to pass**
3. **Reboot ONE node**: `ssh root@NODE "proxmox-safe-reboot.sh"`
4. **Wait for node to fully rejoin cluster** (verify with `pvesh get /cluster/status`)
5. **Repeat for next node**

**NEVER** reboot multiple nodes simultaneously in a 3-node cluster - this will cause quorum loss.

## Key Technical Details

- Quorum detection: `corosync-quorumtool -s | grep -E "Quorate:\s+Yes"`
- Node status: `pvesh get /cluster/resources --type node --noborder`
- HA migrations: `ha-manager status | grep -c "migration"`
- Alert deduplication uses key based on severity + message prefix

## Related Documentation

- Incident report: `/home/dev/workspace/docs/troubleshooting/PROXMOX_NOV25_CASCADE_REBOOT_INCIDENT.md`
