# AdGuard DNS Update Procedures

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DNS Infrastructure                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────────────────┐         ┌──────────────────────┐             │
│   │  AdGuard Secondary   │         │   AdGuard Primary    │             │
│   │  192.168.1.224       │────────>│   192.168.1.253      │             │
│   │  (ORIGIN - Edit Here)│  sync   │   (REPLICA)          │             │
│   │  Port: 80 (web)      │         │   Port: 80 (web)     │             │
│   │  Port: 53 (DNS)      │         │   Port: 53 (DNS)     │             │
│   └──────────────────────┘         └──────────────────────┘             │
│              │                                                           │
│              │ config                                                    │
│              ▼                                                           │
│   ┌──────────────────────┐                                              │
│   │  AdGuard-Sync        │                                              │
│   │  192.168.1.225       │                                              │
│   │  Cron: */5 * * * *   │                                              │
│   │  Port: 8080 (API)    │                                              │
│   └──────────────────────┘                                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Points

| Component | IP Address | Role | Notes |
|-----------|------------|------|-------|
| AdGuard Secondary | 192.168.1.224 | **Origin (Source of Truth)** | Make ALL changes here |
| AdGuard Primary | 192.168.1.253 | Replica | Auto-synced from origin |
| AdGuard-Sync | 192.168.1.225 | Sync Service | Syncs every 5 minutes |

### Synced Features

- General settings
- Query log configuration
- Statistics configuration
- Client settings
- Blocked services
- Filter lists
- DNS server configuration
- DNS access lists
- **DNS rewrites**
- DHCP: **Not synced** (disabled)

---

## Standard Update Procedure

### Step 1: Make Changes on Origin (Secondary)

**Always make changes on 192.168.1.224 first.** Changes sync automatically to 192.168.1.253.

#### Option A: Web UI (Recommended for Simple Changes)

1. Navigate to `http://adguard-2.internal.lakehouse.wtf` or `http://192.168.1.224`
2. Make your changes (rewrites, filters, settings)
3. Save changes
4. Wait for sync (up to 5 minutes) or trigger manual sync

#### Option B: API (Recommended for Automation)

```bash
# Add a DNS rewrite
curl -X POST "http://192.168.1.224/control/rewrite/add" \
  -u "root:redflower805" \
  -H "Content-Type: application/json" \
  -d '{"domain":"example.internal.lakehouse.wtf","answer":"192.168.1.110"}'

# Delete a DNS rewrite
curl -X POST "http://192.168.1.224/control/rewrite/delete" \
  -u "root:redflower805" \
  -H "Content-Type: application/json" \
  -d '{"domain":"example.internal.lakehouse.wtf","answer":"192.168.1.110"}'

# List all rewrites
curl -s "http://192.168.1.224/control/rewrite/list" \
  -u "root:redflower805" | jq
```

#### Option C: Direct YAML Edit (Use with Caution)

```bash
# SSH to origin
ssh root@192.168.1.224

# Backup current config
cp /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/AdGuardHome.yaml.bak.$(date +%Y%m%d-%H%M%S)

# Edit config
nano /opt/AdGuardHome/AdGuardHome.yaml

# VALIDATE before restarting (CRITICAL!)
/opt/AdGuardHome/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --check-config

# Only restart if validation passes
systemctl restart AdGuardHome

# Verify service is running
systemctl status AdGuardHome
```

### Step 2: Validate Changes

```bash
# Test DNS resolution on origin (secondary)
dig @192.168.1.224 your-new-domain.internal.lakehouse.wtf +short

# Verify AdGuard is running
ssh root@192.168.1.224 "systemctl status AdGuardHome --no-pager"
```

### Step 3: Wait for Sync or Trigger Manual Sync

```bash
# Check sync service status
ssh root@192.168.1.225 "systemctl status adguardhome-sync --no-pager"

# View sync logs
ssh root@192.168.1.225 "journalctl -u adguardhome-sync -n 20 --no-pager"

# Trigger immediate sync (restart sync service)
ssh root@192.168.1.225 "systemctl restart adguardhome-sync"
```

### Step 4: Verify on Primary

```bash
# Test DNS resolution on primary
dig @192.168.1.253 your-new-domain.internal.lakehouse.wtf +short

# Verify AdGuard is running
ssh root@192.168.1.253 "systemctl status AdGuardHome --no-pager"
```

---

## Emergency Procedures

### Rollback from Backup

```bash
# On the affected server (origin or replica)
ssh root@192.168.1.224  # or 192.168.1.253

# List available backups
ls -la /opt/AdGuardHome/AdGuardHome.yaml.bak*

# Restore from backup
cp /opt/AdGuardHome/AdGuardHome.yaml.bak.YYYYMMDD-HHMMSS /opt/AdGuardHome/AdGuardHome.yaml

# Validate and restart
/opt/AdGuardHome/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --check-config
systemctl restart AdGuardHome
```

### Pause Sync During Troubleshooting

```bash
# Stop sync to prevent overwriting changes during troubleshooting
ssh root@192.168.1.225 "systemctl stop adguardhome-sync"

# Resume sync when done
ssh root@192.168.1.225 "systemctl start adguardhome-sync"
```

### Fix Corrupted YAML

```bash
# Validate config to find errors
/opt/AdGuardHome/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --check-config 2>&1

# Common issues:
# - Duplicate keys: Remove duplicate lines
# - Misplaced entries: Ensure proper YAML indentation
# - Missing required fields: Check AdGuard Home documentation
```

---

## Common Tasks

### Add Internal DNS Rewrite (Traefik Service)

All internal services route through Traefik at 192.168.1.110.

```bash
# Using API (recommended)
curl -X POST "http://192.168.1.224/control/rewrite/add" \
  -u "root:redflower805" \
  -H "Content-Type: application/json" \
  -d '{"domain":"newservice.internal.lakehouse.wtf","answer":"192.168.1.110"}'

# Verify
dig @192.168.1.224 newservice.internal.lakehouse.wtf +short
# Expected: 192.168.1.110
```

### Add ESPHome Device DNS (.local)

```bash
curl -X POST "http://192.168.1.224/control/rewrite/add" \
  -u "root:redflower805" \
  -H "Content-Type: application/json" \
  -d '{"domain":"my-esp-device.local","answer":"192.168.1.XXX"}'
```

### Add Allowlist Entry

```bash
# Via Web UI: Filters -> Custom filtering rules
# Add: @@||domain.com^$important

# Or via API (add to user_rules)
# Note: Modifying user_rules via API requires updating the full list
```

### Check Sync Status

```bash
# View recent sync activity
ssh root@192.168.1.225 "journalctl -u adguardhome-sync -n 50 --no-pager | grep -E '(sync|error|warn)'"

# Check if sync is running
ssh root@192.168.1.225 "systemctl status adguardhome-sync"
```

---

## Testing Workflow (Recommended for Major Changes)

For significant changes (filter updates, upstream DNS changes, etc.):

### 1. Pause Sync

```bash
ssh root@192.168.1.225 "systemctl stop adguardhome-sync"
```

### 2. Point Test Client to Secondary Only

Configure a test device to use only 192.168.1.224 as its DNS server.

### 3. Make Changes on Secondary

Apply your changes via Web UI or API on 192.168.1.224.

### 4. Test Thoroughly

```bash
# From test client or workstation
dig @192.168.1.224 google.com +short          # External resolution
dig @192.168.1.224 homeassistant.internal.lakehouse.wtf +short  # Internal rewrite
nslookup blocked-domain.com 192.168.1.224     # Filter testing
```

### 5. Resume Sync

```bash
ssh root@192.168.1.225 "systemctl start adguardhome-sync"
```

### 6. Verify Primary

```bash
dig @192.168.1.253 your-test-domain.internal.lakehouse.wtf +short
```

---

## Configuration Reference

### AdGuard-Sync Configuration

Location: `root@192.168.1.225:/root/adguardhome-sync.yaml`

```yaml
origin:
  url: http://192.168.1.224:80
  username: root
  password: <redacted>
  apiPath: /control

replica:
  url: http://192.168.1.253:80
  username: root
  password: <redacted>
  apiPath: /control

cron: '*/5 * * * *'  # Every 5 minutes
runOnStart: true

features:
  generalSettings: true
  queryLogConfig: true
  statsConfig: true
  clientSettings: true
  services: true
  filters: true
  dns:
    serverConfig: true
    accessLists: true
    rewrites: true
  dhcp:
    serverConfig: false
    staticLeases: false
```

### AdGuard Home Config Locations

| Server | Config Path |
|--------|-------------|
| Primary (192.168.1.253) | `/opt/AdGuardHome/AdGuardHome.yaml` |
| Secondary (192.168.1.224) | `/opt/AdGuardHome/AdGuardHome.yaml` |

### Management URLs

| Service | URL |
|---------|-----|
| AdGuard Primary | http://adguard.internal.lakehouse.wtf |
| AdGuard Secondary | http://adguard-2.internal.lakehouse.wtf |
| AdGuard-Sync API | http://192.168.1.225:8080 |

---

## Troubleshooting

### AdGuard Won't Start

```bash
# Check for config errors
/opt/AdGuardHome/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --check-config

# Check logs
journalctl -u AdGuardHome -n 50 --no-pager

# Common fixes:
# - YAML syntax errors: validate with --check-config
# - Port conflicts: check if port 53 or 80 is in use
# - Permission issues: ensure proper ownership
```

### Sync Not Working

```bash
# Check sync service
ssh root@192.168.1.225 "systemctl status adguardhome-sync"

# Check connectivity to both AdGuard instances
ssh root@192.168.1.225 "curl -s -o /dev/null -w '%{http_code}' http://192.168.1.224/control/status"
ssh root@192.168.1.225 "curl -s -o /dev/null -w '%{http_code}' http://192.168.1.253/control/status"

# Check sync logs for errors
ssh root@192.168.1.225 "journalctl -u adguardhome-sync -n 100 --no-pager | grep -i error"
```

### DNS Resolution Failing

```bash
# Test upstream resolution
dig @1.1.1.1 google.com +short

# Test AdGuard resolution
dig @192.168.1.253 google.com +short
dig @192.168.1.224 google.com +short

# Check if AdGuard is listening
ss -tlnp | grep ':53'

# Check AdGuard status
systemctl status AdGuardHome
```

---

## Incident Reference

### 2026-01-08: YAML Corruption Incident

**Cause:** DNS rewrite entry was incorrectly appended after `schema_version` instead of in the `rewrites:` section, causing YAML parse errors.

**Symptoms:**
- AdGuard service in restart loop (exit code 1)
- DNS resolution failing (connection refused on port 53)
- Restart counter rapidly incrementing

**Resolution:**
1. Identified malformed YAML via `--check-config`
2. Removed corrupted entries
3. Re-added rewrite in correct location via proper YAML structure
4. Validated config before restart

**Prevention:**
- Always use Web UI or API for changes (they validate input)
- Always run `--check-config` before restarting after YAML edits
- Keep backups before manual edits

---

## Quick Reference Card

```
# Make changes on ORIGIN (secondary): 192.168.1.224

# Validate YAML config
/opt/AdGuardHome/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --check-config

# Add rewrite via API
curl -X POST "http://192.168.1.224/control/rewrite/add" \
  -u "root:redflower805" -H "Content-Type: application/json" \
  -d '{"domain":"NAME.internal.lakehouse.wtf","answer":"192.168.1.110"}'

# Test DNS
dig @192.168.1.224 NAME.internal.lakehouse.wtf +short

# Trigger sync
ssh root@192.168.1.225 "systemctl restart adguardhome-sync"

# Verify on primary
dig @192.168.1.253 NAME.internal.lakehouse.wtf +short
```
