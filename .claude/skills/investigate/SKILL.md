---
name: investigate
description: Deep-dive investigation into a specific system or anomaly. Use when something looks off or you want detailed diagnostics. Pass target as argument, e.g., /investigate proxmox2
---

# Environment Investigation

Deep-dive into a specific system. The ARGUMENTS string contains the target to investigate.

## Reference

Read `.claude/skills/env-intel/datasources.yaml` for all endpoints, IPs, and thresholds.
Read MEMORY.md and relevant learnings files for known issues with the target system.

## Target Routing

Parse the ARGUMENTS to determine the target. Route to the appropriate diagnostic section below.

### Proxmox Node: `proxmox`, `proxmox2`, `proxmox3`

1. **Node details:** `mcp__proxmox-mcp__get_node_status` for the specific node
2. **Container breakdown:** `mcp__proxmox-mcp__list_containers` filtered to that node — show per-CT CPU/RAM
3. **Resource monitoring:** `mcp__proxmox-mcp__monitor_resource_usage` for the node
4. **ZFS status:** SSH to node: `zpool status && zpool list && arc_summary 2>/dev/null | head -30`
5. **Recent logs:** SSH: `journalctl --since '24 hours ago' -p err --no-pager | tail -50`
6. **Cron status:** SSH: `systemctl status cron` (known to die silently — see MEMORY.md gotcha #1)
7. **HA services:** SSH: `ha-manager status 2>/dev/null`
8. **Disk I/O:** SSH: `iostat -x 1 3 2>/dev/null || echo "iostat not available"`

Analyze: Compare load to CPU core count. Check if any CT is consuming disproportionate resources. Look for ZFS ARC pressure. Check if cron is running.

### TrueNAS: `truenas`, `nas`, `storage`

1. **System info:** `mcp__truenas__get_system_info`
2. **Pool details:** `mcp__truenas__list_pools` then `mcp__truenas__get_pool_status` for each pool
3. **Dataset usage:** `mcp__truenas__list_datasets` — sort by usage, flag large datasets
4. **SMB shares:** `mcp__truenas__list_smb_shares`

Analyze: Check pool health, capacity trends, any degraded vdevs, scrub status.

### Backups: `backups`, `pbs`, `backup`

1. **Recent backup tasks:** SSH to proxmox: `pvesh get /nodes/proxmox/tasks --typefilter vzdump --limit 50 --output-format json`
2. **PBS status:** SSH to PBS (192.168.1.171): `proxmox-backup-manager datastore list 2>/dev/null`
3. **Storage usage:** `mcp__proxmox-mcp__get_storage_status`

Analyze: Check for failed backups, duration anomalies, storage growth rate.

### Home Assistant: `ha`, `home-assistant`, `homeassistant`

1. **Get token** from Infisical (see briefing skill for command)
2. **All states:** Query `/api/states` — categorize unavailable entities by domain
3. **Error log:** Query `/api/error/all` or `/api/error_log`
4. **Service status:** Check if HA API responds, response time
5. **Automation failures:** Query for failed automations in last 24h

Analyze: Group unavailable entities by integration. Check if a single integration is down vs. scattered failures.

### BirdNET: `birdnet`, `birdnet-go`, `birds`

1. **Recent detections:** `curl http://192.168.1.197:8080/api/v2/detections?limit=200`
2. **Service status:** SSH to BirdNET Pi: `systemctl status birdnet-go-native.service`
3. **Disk usage:** SSH: `df -h /home/jeremy/`
4. **Audio source:** SSH: `arecord -l 2>/dev/null` to verify USB mic connected
5. **MQTT connectivity:** SSH: `mosquitto_pub -h 192.168.1.149 -t test -m test 2>&1`

Analyze: Check detection rate, audio source health, disk space, MQTT broker reachability.

### Loki: `loki`, `logs`

1. **Health:** `curl -s http://192.168.1.170:3100/ready`
2. **Ingestion rate:** `curl -s 'http://192.168.1.170:3100/loki/api/v1/query?query=sum(rate({job=~".%2B"}[1h]))'`
3. **Active jobs:** `curl -s 'http://192.168.1.170:3100/loki/api/v1/labels' | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin),indent=2))"`
4. **Disk usage:** SSH to proxmox2: `pct exec 151 -- df -h /var/lib/loki`

Analyze: Check for missing log sources (compare active jobs to expected list of ~41), ingestion anomalies.

### Container by Name or ID: `<container-name>` or `<CTID>`

1. **Find the CT:** `mcp__proxmox-mcp__list_containers` — match by name or VMID
2. **CT config:** SSH to node: `pct config CTID`
3. **CT status:** `mcp__proxmox-mcp__list_containers` filtered
4. **Recent logs:** SSH to node: `pct exec CTID -- journalctl --since '24 hours ago' -p err --no-pager 2>/dev/null | tail -30`
5. **Service status:** SSH: `pct exec CTID -- systemctl list-units --state=failed 2>/dev/null`
6. **Resource usage:** SSH: `pct exec CTID -- free -m && pct exec CTID -- df -h /`

Analyze: Check for failed services, resource exhaustion, error logs.

## Output Format

```
## Investigation: {target}

### Summary
One paragraph: Is it healthy? What stands out?

### Diagnostics
Detailed findings organized by category.

### Known Issues
Cross-reference with learnings/MEMORY.md — any known gotchas for this system?

### Recommendations
Specific actions if any issues found. Reference remediation procedures from learnings.
```
