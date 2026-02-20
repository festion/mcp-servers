---
name: changelog
description: Audit what changed in the environment over a time window. Shows code commits, package updates, container changes, alerts. Default 24h. Usage /changelog or /changelog 48h or /changelog week
---

# Environment Changelog

Show what changed in the environment over a time window. ARGUMENTS contains the timeframe (default: "24h"). Parse it to determine the lookback period.

## Reference

Read `.claude/skills/env-intel/datasources.yaml` for repos, nodes, and endpoints.

## Timeframe Parsing

- No argument or "24h" → last 24 hours
- "48h" → last 48 hours
- "week" or "7d" → last 7 days
- Any other number+h/d → that duration

Calculate the `--since` date for git and the start timestamp for API queries.

## Data Gathering

### 1. Code Changes — GitHub

For each repo in `datasources.yaml`:

```bash
mcp__github__list_commits owner=festion repo=REPO_NAME
```

Filter commits within the timeframe. Show: date, author, message, files changed count.

### 2. Package Updates — Proxmox Nodes

For each node, SSH and check dpkg log:

```bash
ssh root@NODE_IP "grep -E 'install|upgrade|remove' /var/log/dpkg.log 2>/dev/null | tail -30"
```

And apt history:

```bash
ssh root@NODE_IP "grep -A2 'Start-Date:' /var/log/apt/history.log 2>/dev/null | tail -30"
```

### 3. Container Changes — Proxmox

Use `mcp__proxmox-mcp__list_containers` and `mcp__proxmox-mcp__list_virtual_machines`.

Compare against the known container list in MEMORY.md — flag any new or missing CTs.

### 4. Alert History — Proxmox Agent

Get dashboard API credentials (see briefing skill), then:

```bash
ssh root@192.168.1.137 "pct exec 152 -- curl -s -u USER:PASS 'http://localhost:8000/api/alerts?limit=100'" 2>/dev/null
```

Filter alerts within timeframe.

### 5. TrueNAS Changes

```bash
mcp__truenas__list_datasets
```

Note any new datasets or shares. Check TrueNAS audit log if available via SSH.

### 6. Home Assistant Changes

Check the home-assistant-config repo commits (covered by GitHub section above). Also check for any HA restarts in the period via Loki:

```bash
curl -sG 'http://192.168.1.170:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="home-assistant"} |= "started"' \
  --data-urlencode "start=$(date -d 'TIMEFRAME ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode 'limit=20'
```

## Output Format

```
## Environment Changelog — {timeframe}

### Code Changes
| Repo | Commits | Summary |
|------|---------|---------|
| ... | N | Brief description of changes |

Details:
- **repo** `abc1234` — commit message (author, date)

### Infrastructure Changes
- Package updates on nodes (if any)
- Container additions/removals (if any)
- TrueNAS dataset changes (if any)

### Alert Timeline
- **HH:MM** Alert description (severity)

### Service Events
- HA restarts, BirdNET restarts, etc.
```

## Intelligence Rules

1. **Risk assessment:** For each change, note if it's routine (Dependabot bump), notable (config change), or requires attention (failed deployment)
2. **Correlation:** If a service restarted and alerts fired around the same time, connect them
3. **Omit empty sections:** If no package updates happened, skip that section entirely
