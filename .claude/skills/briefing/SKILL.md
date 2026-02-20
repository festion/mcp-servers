---
name: briefing
description: Morning environment briefing. Summarizes overnight health, events, alerts, and action items across all homelab infrastructure. Use at start of day.
---

# Environment Briefing

Generate a comprehensive morning briefing of the homelab environment. The value is in YOUR interpretation — correlate events, flag anomalies, prioritize action items. Don't just dump data.

## Reference

Read `.claude/skills/env-intel/datasources.yaml` for all endpoints, IPs, and thresholds.

## Data Gathering

Gather data from ALL sources below. Use parallel tool calls where possible.

### 1. Compute — Proxmox Cluster

Use the Proxmox MCP tools:

- `mcp__proxmox-mcp__get_system_info` — cluster version, node count, quorum
- `mcp__proxmox-mcp__list_containers` — all CTs with status (look for stopped CTs that should be running)
- `mcp__proxmox-mcp__list_virtual_machines` — all VMs with status
- `mcp__proxmox-mcp__monitor_resource_usage` — CPU, RAM, load per node

Flag: Any node down, any CT stopped with `onboot: 1`, load > threshold.

### 2. Storage — TrueNAS

Use the TrueNAS MCP tools:

- `mcp__truenas__list_pools` — pool health, usage %
- `mcp__truenas__get_system_info` — system uptime, version

Flag: Any pool degraded, usage > 80%, any SMART warnings.

### 3. Backups — PBS

SSH to proxmox (192.168.1.137) as root and run:
```bash
ssh root@192.168.1.137 "pvesh get /nodes/proxmox/tasks --typefilter vzdump --limit 20 --output-format json 2>/dev/null"
```

Parse the task list for backup jobs in the last 36 hours. Check for failures (status != "OK").

### 4. Alerts — Proxmox Agent Dashboard

Get credentials first:
```bash
ssh root@192.168.1.137 "pct exec 152 -- cat /opt/proxmox-agent/.env" 2>/dev/null
```

Extract DASHBOARD_USER and DASHBOARD_PASSWORD, then query:
```bash
ssh root@192.168.1.137 "pct exec 152 -- curl -s -u USER:PASS http://localhost:8000/api/alerts?acknowledged=false" 2>/dev/null
```

Flag: Any unacknowledged alerts, especially critical/high severity.

### 5. Home Assistant

Get the HA token:
```bash
cd /home/dev/workspace && infisical secrets get HA_LONG_LIVED_TOKEN --env=prod --plain 2>/dev/null
```

Query the HA API:
```bash
curl -s -H "Authorization: Bearer TOKEN" http://192.168.1.155:8123/api/states | python3 -c "
import json, sys
states = json.load(sys.stdin)
unavailable = [s['entity_id'] for s in states if s['state'] in ('unavailable', 'unknown')]
print(json.dumps({'total': len(states), 'unavailable_count': len(unavailable), 'unavailable': unavailable[:20]}))"
```

Flag: Entity count > threshold, any critical entities unavailable.

### 6. BirdNET-Go

```bash
curl -s "http://192.168.1.197:8080/api/v2/detections?limit=100" 2>/dev/null
```

Report: Detection count in last 24h, species diversity, any notable detections (rare species, high confidence).

### 7. GitHub — Dependabot & CI

Use GitHub MCP tools for each repo in the config:

- `mcp__github__list_issues` with `labels: ["dependencies"]` for Dependabot alerts
- Check for recent failed CI runs (optional — skip if rate-limited)

Flag: Any open security alerts.

## Output Format

Present as a clean markdown briefing:

```
## Environment Briefing — {today's date}

### Health: {emoji} {status}
| System | Status | Notes |
|--------|--------|-------|
| ... one row per system ... |

### Overnight Events
- **HH:MM** Notable events with context (skip if nothing notable)

### Action Items
- [ ] Items requiring human attention, ordered by priority

### Quick Stats
- Key numbers: detections, load averages, alert counts, etc.
```

## Intelligence Rules

1. **Correlate:** If backup ran at 01:00 and load spiked at 01:00 — that's expected, don't flag it
2. **Threshold:** Use thresholds from datasources.yaml to determine warning/critical
3. **Known issues:** Check MEMORY.md and learnings files for known patterns (Sunday 3AM = Ultimate Updater)
4. **Omit noise:** If a system is fully healthy, just show a checkmark in the health table — no need for details
5. **Prioritize:** Action items ordered: critical > high > medium > informational
6. **Be concise:** This is a morning scan. Details go in `/investigate`.
7. **Timezone:** All systems run CST/CDT (America/Chicago). Display times in local time. Format: "11:13 AM" not "17:13 UTC".
