# Environment Intelligence Skill Suite — Design

**Date:** 2026-02-20
**Status:** Approved
**Location:** `/home/dev/workspace/.claude/skills/env-intel/`

## Overview

A suite of four Claude Code skills that provide intelligent environment monitoring, analysis, and reporting for the homelab infrastructure. Unlike static scripts or cron jobs, these skills leverage Claude's reasoning to correlate events, identify anomalies, and prioritize action items.

**Core principle:** The value is in Claude's interpretation, not raw data. A scheduled script can dump metrics — these skills synthesize meaning.

## Architecture

### Skill Family

| Skill | Invocation | Purpose |
|-------|-----------|---------|
| `briefing` | `/briefing` | Morning summary: health, events, alerts, action items |
| `investigate` | `/investigate <target>` | Deep-dive into a system or anomaly |
| `changelog` | `/changelog [timeframe]` | What changed: configs, packages, alerts, containers |
| `trends` | `/trends [system]` | Capacity projections, recurring issues, degradation |

### File Structure

```
/home/dev/workspace/.claude/skills/env-intel/
├── datasources.yaml      # Shared data source configuration
├── briefing.md            # /briefing skill definition
├── investigate.md         # /investigate skill definition
├── changelog.md           # /changelog skill definition
└── trends.md              # /trends skill definition
```

### Shared Data Sources (`datasources.yaml`)

Central config defining all infrastructure endpoints, MCP tool mappings, credential references, and monitoring thresholds. Each skill reads this at invocation time.

```yaml
compute:
  proxmox:
    tool_prefix: mcp__proxmox-mcp
    nodes:
      - name: proxmox
        ip: 192.168.1.137
        cpu: "Intel N100 (4c)"
        role: "HA master"
      - name: proxmox2
        ip: 192.168.1.125
        cpu: "i7-6700 (8c)"
      - name: proxmox3
        ip: 192.168.1.126
        cpu: "i7-6700 (8c)"
    ssh_user: root

storage:
  truenas:
    tool_prefix: mcp__truenas
    ip: 192.168.1.98
  pbs:
    ip: 192.168.1.171
    port: 8007
    ssh_user: root

services:
  home_assistant:
    ip: 192.168.1.155
    port: 8123
    api_path: /api/
    token_ref: "infisical:homelab-gitops/prod/HA_LONG_LIVED_TOKEN"
  birdnet:
    ip: 192.168.1.197
    port: 8080
    api_path: /api/v2/
    ssh_user: jeremy
  loki:
    ip: 192.168.1.170
    port: 3100

monitoring:
  proxmox_agent:
    ct: 152
    node: proxmox2
    ip: 192.168.1.169
    port: 8000
    api_path: /api/
    env_file: /opt/proxmox-agent/.env

code:
  github:
    tool_prefix: mcp__github
    owner: festion
    repos:
      - mcp-servers
      - homelab-gitops
      - home-assistant-config
      - proxmox-agent
      - birdnet-gone
      - pi-status-dashboard
      - operations

thresholds:
  storage_warning_pct: 80
  storage_critical_pct: 90
  load_warning_multiplier: 2.0  # times CPU count
  backup_max_age_hours: 36
  unavailable_entities_warning: 5
```

## Skill Designs

### 1. `/briefing` — Morning Environment Briefing

**Trigger:** User invokes `/briefing` at start of day.

**Data gathering** (parallel where possible):

| Category | Source | Tool/Method | Key Metrics |
|----------|--------|-------------|-------------|
| Compute | Proxmox | MCP `get_system_info`, `list_virtual_machines`, `list_containers`, `monitor_resource_usage` | Node status, CT health, CPU/RAM/load |
| Storage | TrueNAS | MCP `list_pools`, `list_datasets` | Pool health, usage %, degraded vdevs |
| Backups | PBS | SSH `proxmox-backup-client list` or Proxmox MCP | Last backup times, any failures |
| Alerts | proxmox-agent | HTTP API (Basic auth from .env) | Unacknowledged alerts, severity counts |
| HA | Home Assistant | HTTP API (Bearer token) | Uptime, unavailable entities |
| BirdNET | BirdNET-Go | HTTP API | Detection count (24h), notable species |
| Logs | Loki | HTTP API (LogQL) | Error rate, volume anomalies |
| Code | GitHub | MCP `list_issues` (Dependabot) | Open security alerts, failed CI |

**Intelligence layer:**
- Correlate events across sources (high load + backup timing = expected)
- Compare metrics to thresholds from datasources.yaml
- Flag deviations from normal patterns
- Prioritize action items by severity and urgency
- Omit sections where everything is normal (just "✅" in health table)

**Output format:**

```markdown
## Environment Briefing — {date}

### Health: {overall_emoji} {overall_status}
| System | Status | Notes |
|--------|--------|-------|
| Proxmox Cluster | ✅ Healthy | 3/3 nodes, quorum OK |
| TrueNAS | ✅ Online | 78% used |
| PBS Backups | ✅ Complete | N/N succeeded |
| Home Assistant | ⚠️ Degraded | 3 unavailable entities |

### Overnight Events
- **HH:MM** Event description with context
- ...

### Action Items
- [ ] Priority items requiring human attention
- ...

### Quick Stats
- BirdNET: N detections (M species) in last 24h
- Proxmox load: X / Y / Z (avg across nodes)
- N open Dependabot alerts
```

### 2. `/investigate <target>` — On-Demand Deep Dive

**Trigger:** `/investigate proxmox2`, `/investigate truenas`, `/investigate backups`, `/investigate ha`, `/investigate birdnet`, `/investigate loki`, `/investigate <container-name>`

**Behavior by target:**

| Target | Diagnostics |
|--------|-------------|
| `proxmox`, `proxmox2`, `proxmox3` | Per-CT resource breakdown, recent logs (Loki), ZFS status, cron status, HA failover history |
| `truenas` | Pool details, SMART status, replication status, recent scrub results, dataset usage breakdown |
| `backups` | Full backup history, duration comparison, any failures with error details, storage usage trends |
| `ha` | Entity audit (unavailable, unknown), automation failure logs, integration status, recent restarts |
| `birdnet` | Detection rates, audio source status, MQTT connectivity, disk usage, service uptime |
| `loki` | Ingestion rates by job, storage usage, query performance, missing log sources |
| `<container>` | CT config, resource usage, recent logs, service status, network connectivity |

**Intelligence layer:**
- Check learnings files for known issues with the target
- Compare current state to healthy baselines
- Provide root cause hypothesis for anomalies
- Suggest specific remediation steps
- Reference relevant runbooks or past incidents

### 3. `/changelog [timeframe]` — Change Audit

**Trigger:** `/changelog` (default 24h), `/changelog 48h`, `/changelog week`

**Data gathered:**

| Category | Source | Method |
|----------|--------|--------|
| Code changes | GitHub | MCP `list_commits` across all repos |
| Package updates | Proxmox nodes | SSH `apt log` / `dpkg.log` |
| CT config changes | Proxmox | `pct config` diff against last known |
| New/removed CTs | Proxmox | MCP container list comparison |
| Alert history | proxmox-agent | Dashboard API alert timeline |
| HA changes | home-assistant-config | Git log |
| TrueNAS changes | TrueNAS | Dataset/share creation logs |

**Output:** Chronological timeline grouped by category. Each change includes Claude's assessment of risk/impact (routine, notable, or requires attention).

### 4. `/trends [system]` — Trend Analysis

**Trigger:** `/trends` (all), `/trends storage`, `/trends backups`, `/trends alerts`, `/trends compute`

**Analysis:**

| System | Metrics | Projection |
|--------|---------|------------|
| Storage | TrueNAS pool usage, PBS datastore usage | Days until threshold breach |
| Backups | Duration trends, size growth | Capacity planning |
| Alerts | Frequency patterns, recurring types | Systemic issues |
| Compute | CPU/RAM utilization trends | Capacity headroom |

**Intelligence layer:**
- Calculate growth rates from available data points
- Project time-to-threshold
- Identify recurring patterns (e.g., "load spikes every Sunday at 3 AM" = expected from Ultimate Updater)
- Recommend actions for trending issues

## Implementation Priority

1. **Phase 1:** `datasources.yaml` + `/briefing` (highest immediate value)
2. **Phase 2:** `/investigate` (most frequently used after briefing)
3. **Phase 3:** `/changelog` (change tracking)
4. **Phase 4:** `/trends` (requires historical data accumulation)

## Design Decisions

- **Why Claude Code skills, not cron?** The value is Claude's interpretation and reasoning. A cron job produces static text. Claude can correlate, prioritize, and adapt the output to what actually matters that day.
- **Why shared YAML config?** DRY. Adding a new data source (e.g., a new monitoring tool) updates all skills at once. Also serves as documentation of the infrastructure topology.
- **Why terminal output only?** Minimal complexity. The user starts their day in Claude Code — no context switching needed. Historical reports can be added later if desired.
- **Why workspace-level, not inside proxmox-agent?** The skills need access to ALL MCP tools (Proxmox, TrueNAS, GitHub, filesystem). Proxmox-agent is focused on automated remediation. These skills are for human-facing intelligence synthesis.
