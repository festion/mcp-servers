---
name: briefing
description: Morning environment briefing. Summarizes overnight health, events, alerts, and action items across all homelab infrastructure. Use at start of day.
---

# Environment Briefing

You're a thoughtful colleague catching the user up over coffee on what happened overnight. Their attention is finite — earn it. **Different mornings warrant different shapes.** A 3-line "all quiet" briefing on a quiet day is more valuable than a 15-line health table the eye skims past.

## Reference

- Endpoints, IPs, thresholds: `.claude/skills/env-intel/datasources.yaml`
- Continuity log: `~/.local/state/briefing/briefings.jsonl` — one JSON line per past briefing, used so today's run knows what yesterday's said.

## Step 1 — Read recent context

```bash
mkdir -p ~/.local/state/briefing && tail -n 14 ~/.local/state/briefing/briefings.jsonl 2>/dev/null
```

Use the log to:
- Reference yesterday's open items by name ("the CT 123 backup hang you flagged yesterday")
- Avoid re-saying what the user already heard recently
- Notice items that have been "open" for many days without progress
- Compute deltas (HA entity count, alert count, etc.) instead of citing absolutes

## Step 2 — Gather data (parallel)

Issue these concurrently in one tool batch.

### Compute (Proxmox)
- `mcp__proxmox-mcp__get_system_info` — version, quorum, nodes online
- `mcp__proxmox-mcp__list_containers` — flag stopped CTs with `onboot: 1`
- `mcp__proxmox-mcp__list_virtual_machines`
- `mcp__proxmox-mcp__monitor_resource_usage` — exposes `threshold_violations` directly

### Storage (TrueNAS)
- `mcp__truenas__list_pools`
- `mcp__truenas__get_system_info`

### Backups — ALL three nodes
The earlier skill missed the 2026-04-26 proxmox2 backup failure because it only queried the `proxmox` node. Always check all three:
```bash
for n in proxmox proxmox2 proxmox3; do
  ssh root@192.168.1.137 "pvesh get /nodes/$n/tasks --typefilter vzdump --limit 30 --output-format json"
done
```
Anything `status != "OK"` in the last 36h is a finding. Include the UPID.

### PBS-side journal
PBS errors (prune, GC, datastore lock contention, client connection drops) don't appear in node-side vzdump task lists:
```bash
ssh root@192.168.1.137 "pct exec 120 -- journalctl -u proxmox-backup-proxy --since '24 hours ago' --no-pager 2>/dev/null | grep -E 'TASK ERROR|TASK WARNINGS|connection error' | head -30"
```

### Proxmox-agent unacked alerts
```bash
PASS=$(ssh root@192.168.1.137 "pct exec 152 -- grep DASHBOARD_PASSWORD /opt/proxmox-agent/.env" | cut -d= -f2)
ssh root@192.168.1.137 "pct exec 152 -- curl -s -u admin:'$PASS' 'http://localhost:8000/api/alerts?acknowledged=false'"
```

### Grafana — overnight alerts (resolved or firing)
The active-alerts endpoint hides alerts that fired-then-resolved. Use the annotations API. Auth is basic-auth via the existing homepage creds (no dedicated `GRAFANA_API_TOKEN` exists in Infisical yet — see task #804 follow-up):
```bash
USER=$(infisical-get HOMEPAGE_VAR_GRAFANA_USER 2>/dev/null)
PASS=$(infisical-get HOMEPAGE_VAR_GRAFANA_PASS 2>/dev/null)
SINCE=$(($(date +%s) - 86400))000
curl -s -u "$USER:$PASS" \
  "http://192.168.1.151:3000/api/annotations?type=alert&from=$SINCE" \
  | python3 -c "
import json, sys, datetime
data = json.load(sys.stdin)
for a in data:
    if a.get('newState') == 'Alerting':
        ts = datetime.datetime.fromtimestamp(a.get('time',0)/1000).strftime('%Y-%m-%d %H:%M')
        print(f\"{ts}  {a.get('alertName','?')}  {a.get('text','')[:80]}\")"
```

### Home Assistant
```bash
TOKEN=$(infisical-get HA_LONG_LIVED_TOKEN 2>/dev/null)
curl -s -H "Authorization: Bearer $TOKEN" http://192.168.1.155:8123/api/states | python3 -c "
import json, sys
states = json.load(sys.stdin)
unavailable = [s['entity_id'] for s in states if s['state'] in ('unavailable','unknown')]
print(json.dumps({'total': len(states), 'unavailable_count': len(unavailable), 'sample': unavailable[:10]}))"
```

### BirdNET-Go
Pi 5 at `192.168.10.246` (Pi 4 at `192.168.1.197` was decommissioned 2026-04-24):
```bash
curl -s "http://192.168.10.246:8080/api/v2/detections?limit=200"
```

### Email
- **Gmail** via `mcp__claude_ai_Gmail__search_threads`: `in:inbox is:unread` and `in:inbox is:starred`.
- **Outlook** via Graph API direct (never `mcp__ms365__` tools — they're broken):
  ```bash
  TOKFILE=~/.ms365-mcp/tokens.json; [ -f "$TOKFILE" ] || TOKFILE=/tmp/ms365_tokens2.json
  RT=$(python3 -c "import json; print(json.load(open('$TOKFILE'))['refresh_token'])")
  TOK=$(curl -s -X POST "https://login.microsoftonline.com/common/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=084a3e9f-a9f4-43f7-89f9-d229cf97853e&grant_type=refresh_token&refresh_token=$RT&scope=Mail.Read offline_access" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
  curl -s -H "Authorization: Bearer $TOK" "https://graph.microsoft.com/v1.0/me/mailFolders/inbox" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('unread:', d.get('unreadItemCount'))"
  curl -s -H "Authorization: Bearer $TOK" \
    "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages?\$filter=isRead%20eq%20false&\$select=subject,from,receivedDateTime&\$top=20&\$orderby=receivedDateTime%20desc"
  ```

## Step 3 — Decide what to actually say

Look at gathered data + the continuity log and **pick the shape that fits this morning**. Examples — not exhaustive, invent if the data calls for something else:

- **Quiet morning** — nothing changed, prior open items still open, no events. 2–3 sentences. Reference what's still open. End.
- **Delta-only** — only mention what moved since yesterday's snapshot. Skip steady-state systems entirely.
- **Single-thread deep-dive** — one finding genuinely stands out (new failure, unusual pattern, regression). Go deep on it; one-line everything else.
- **Follow-up** — yesterday you flagged X. Has it resolved? Stalled? Crossed an "open N days, time to act" threshold?
- **Synthesis** — connect a pattern across systems (e.g. HA orphans growing + Z2M restart + IoT-VLAN device drops → likely the same root cause).
- **Heads-up** — external context (calendar, severe-weather forecast, utility email) interacts with infra state.
- **Standard sweep** — only when many days have passed without mentioning a system; touch each in one line so silent rot can't hide.

**Don't render the same shape two days in a row** unless the data genuinely demands it. The continuity log tells you which shape you used last time.

What to optimize for:
- **Things the user wouldn't notice without you.** Identical-to-yesterday metrics aren't interesting; their *unchanged-ness* sometimes is.
- **Continuity over comprehensiveness.** A 3-line briefing with thread-of-thought beats a 15-line table.
- **Honest uncertainty.** "I can't tell whether HA's 560-unavailable count is genuine or whether something is caching" is a useful sentence.
- **Variable length and register.** Match the morning. Sometimes terse; sometimes a paragraph; sometimes a single observation worth thinking about.

What to avoid:
- The 3-column health table by default. Render it only when ≥3 rows shifted; otherwise prose.
- Restating MEMORY.md / known-fact context as if it were news.
- Listing every healthy system "✅". If it's healthy, don't perform the check on the page.
- Padding with "Quick Stats" the user already lives in.

## Step 4 — Safety net (non-negotiable)

After writing the briefing, sanity-check that the prose mentioned (or implicitly covered) every objective anomaly. If any of these were skipped, append a single "**⚠ Also:**" line at the end. Variability ≠ permission to drop real signal.

| Check | Trigger |
|---|---|
| `threshold_violations` non-empty | Step 2 compute |
| Pool not `ONLINE` | Step 2 storage |
| `vzdump` `status != OK` in last 36h on any node | Step 2 backups |
| PBS journal line matches `TASK ERROR` / `connection error` (24h) | Step 2 PBS journal |
| Grafana annotation `newState=Alerting` (24h) | Step 2 Grafana |
| Unacked alert `severity=critical` | Step 2 proxmox-agent |
| HA entity-count delta > 5% vs continuity-log baseline | Step 1 + Step 2 HA |
| Any node `online: 0` | Step 2 compute |
| Critical-sender unread email (bank, utility, landlord) | Step 2 email |

## Step 5 — Append to continuity log

After delivering the briefing, append one JSON line so tomorrow's run has context. Fill in actual values:

```bash
mkdir -p ~/.local/state/briefing
cat <<'EOF' >> ~/.local/state/briefing/briefings.jsonl
{"date":"YYYY-MM-DD","time":"HH:MM","shape":"quiet|delta|deep-dive|follow-up|synthesis|heads-up|sweep|other","summary":"one-sentence recap of what you said","key_facts":{"ha_unavailable":N,"alerts_unacked":N,"backup_failures_36h":[],"birdnet_24h":N},"open_items":["..."],"mood":"green|yellow|red"}
EOF
```

The schema can evolve; keep `date`, `shape`, `summary`, `key_facts.ha_unavailable`, `key_facts.alerts_unacked`, and `open_items` stable — those are what tomorrow's Step 1 reads.
