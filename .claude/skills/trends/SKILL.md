---
name: trends
description: Analyze trends in storage, backups, alerts, and compute over time. Provides capacity projections and identifies recurring patterns. Usage /trends or /trends storage or /trends backups
---

# Environment Trend Analysis

Analyze trends and project capacity. ARGUMENTS contains the optional system focus (default: all systems).

## Reference

Read `.claude/skills/env-intel/datasources.yaml` for endpoints and thresholds.

## System Routing

- No argument or "all" → analyze all systems
- "storage" → TrueNAS + PBS storage trends
- "backups" → backup duration and size trends
- "alerts" → alert frequency and patterns
- "compute" → CPU, RAM, load trends

## Data Gathering

### Storage Trends

1. **TrueNAS pools:** `mcp__truenas__list_pools` — current usage
2. **TrueNAS datasets:** `mcp__truenas__list_datasets` — per-dataset sizes
3. **PBS datastore:** SSH to proxmox: `pvesh get /storage --output-format json` — check PBS storage usage
4. **Proxmox local storage:** `mcp__proxmox-mcp__get_storage_status` for each node

For projections: If historical data is not available from a single query, note the current values and suggest the user run `/trends storage` periodically to build a baseline. With multiple data points over time, calculate growth rates.

### Backup Trends

1. **Recent backup tasks:** SSH to proxmox: `pvesh get /nodes/proxmox/tasks --typefilter vzdump --limit 100 --output-format json`
2. Parse: Extract start time, end time (duration), and data size per backup
3. Calculate: Average duration, duration trend (getting longer?), total backup size trend

### Alert Trends

1. **Full alert history:** Query proxmox-agent dashboard API (get auth, then fetch all alerts)
2. Categorize: By severity, by type, by time of day
3. Identify: Recurring patterns (same alert type at same time = systemic), frequency changes

### Compute Trends

1. **Current resource usage:** `mcp__proxmox-mcp__monitor_resource_usage` for all nodes
2. **Historical context:** Note that real-time monitoring gives a snapshot. For trends, compare current values against known baselines from MEMORY.md (e.g., "load was 1.0-2.2 on proxmox after thundering herd fix")
3. **Per-CT resource usage:** `mcp__proxmox-mcp__list_containers` with resource details

## Output Format

```
## Trend Analysis — {date}

### Storage
| Location | Current | Capacity | Projection |
|----------|---------|----------|------------|
| TrueNAS main pool | 78% | 10 TB | ~45 days to 90% (if growth continues) |
| PBS datastore | ... | ... | ... |
| proxmox local-lvm | ... | ... | ... |

### Backups
- Average backup duration: Xm (last 7d)
- Total backup size: X GB
- Trend: {stable/growing/shrinking}

### Alerts
- Total alerts (7d): N
- By severity: critical: X, high: Y, medium: Z
- Recurring patterns: {description}

### Compute
| Node | CPU Avg | RAM % | Load | Headroom |
|------|---------|-------|------|----------|
| proxmox | X% | Y% | Z | {plenty/moderate/tight} |

### Recommendations
- Prioritized list of capacity or reliability actions
```

## Intelligence Rules

1. **Don't fabricate trends:** If you only have a single data point, say so. "Current usage is 78% — run `/trends storage` weekly to track growth rate."
2. **Known patterns:** Sunday 3 AM load spikes = Ultimate Updater (expected). Daily 01:00 = backup window (expected). Don't flag these as anomalies.
3. **Actionable projections:** "Pool hits 90% in ~45 days" is useful. "CPU was 12% today" without context is not.
4. **Compare to thresholds:** Use thresholds from datasources.yaml.
