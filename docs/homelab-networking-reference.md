# Homelab Networking Reference

Comprehensive reference for the homelab network infrastructure, including DHCP, DNS, reverse proxy, and WiFi management.

---

## Network Overview

| Property | Value |
|----------|-------|
| **Subnet** | 192.168.1.0/24 |
| **Gateway** | 192.168.1.1 |
| **Domain** | lakehouse.wtf |
| **Internal Domain** | *.internal.lakehouse.wtf |
| **DHCP Pool** | 192.168.1.10 - 192.168.1.250 |
| **Lease Duration** | 86400 seconds (24 hours) |

### IP Address Allocation

| Range | Purpose |
|-------|---------|
| 192.168.1.1-99 | Network infrastructure, IoT devices |
| 192.168.1.100-149 | LXC containers (services) |
| 192.168.1.150-199 | Reserved / future expansion |
| 192.168.1.200-254 | Standalone hardware, DHCP pool |

### Network Architecture

```
Internet
    │
    ▼
Cloudflare (DNS + Tunnel)
    │ *.lakehouse.wtf
    ▼
┌─────────────────────────────────────┐
│ AdGuard DNS (Internal Override)     │
│ *.internal.lakehouse.wtf → Traefik  │
└─────────────────────────────────────┘
    │
    ▼
Traefik Reverse Proxy (192.168.1.110)
    │ TLS termination, routing
    ▼
Backend Services (LXC or Standalone)
```

---

## DHCP Infrastructure (Kea HA Pair)

### Servers

| Role | IP | LXC ID | Node | Service |
|------|-----|--------|------|---------|
| Primary | 192.168.1.133 | 133 | proxmox3 | `isc-kea-dhcp4-server` |
| Secondary | 192.168.1.134 | 134 | proxmox | `isc-kea-dhcp4-server` |

### Configuration

| Property | Value |
|----------|-------|
| Config Path | `/etc/kea/kea-dhcp4.conf` |
| Lease Database | `/var/lib/kea/kea-leases4.csv` |
| Control Socket | `/var/run/kea/kea4-ctrl-socket` |
| LFC Interval | 3600 seconds (1 hour) |
| Monitoring | Stork at http://192.168.1.234:8080 |

### Sync System

| Property | Value |
|----------|-------|
| Script | `/usr/local/bin/kea-config-sync` on kea-dhcp-1 |
| Logs | `/var/log/kea-sync/sync-YYYYMMDD.log` |
| Backups | `/var/backups/kea-sync/kea-dhcp4.conf.{host}.{timestamp}` |
| Cron | `/etc/cron.d/kea-config-sync` |
| Logrotate | `/etc/logrotate.d/kea-sync` |

### Key Points

- **Kea HA syncs leases but NOT configs** - reservations need manual sync or `kea-config-sync`
- **DHCP Option 138** (192.168.1.47) required for Omada CAPWAP AC discovery
- **Both servers must be updated** for HA failover to work correctly
- **this-server-name** must be unique per server (common misconfiguration cause)

### Reservation Format

```json
{
  "hw-address": "XX:XX:XX:XX:XX:XX",
  "ip-address": "192.168.1.XXX",
  "hostname": "service-name"
}
```

Location in config: `Dhcp4.subnet4[].reservations` array (find the 192.168.1.0/24 subnet)

### Commands

```bash
# SSH access (requires homelab key)
ssh -i ~/.ssh/homelab root@192.168.1.133
ssh -i ~/.ssh/homelab root@192.168.1.134

# Validate config syntax
ssh root@192.168.1.133 "kea-dhcp4 -t /etc/kea/kea-dhcp4.conf"

# View current reservations
ssh root@192.168.1.133 "jq '.Dhcp4.subnet4[0].reservations' /etc/kea/kea-dhcp4.conf"

# View active leases
ssh root@192.168.1.133 "cat /var/lib/kea/kea-leases4.csv | wc -l"

# Sync configs between servers
kea-config-sync           # Normal sync
kea-config-sync -n        # Dry-run
kea-config-sync -f        # Force sync even if identical
kea-config-sync -q        # Quiet mode (errors only)

# Reload service (BOTH servers after config changes!)
ssh root@192.168.1.133 "systemctl reload isc-kea-dhcp4-server"
ssh root@192.168.1.134 "systemctl reload isc-kea-dhcp4-server"

# Monitor DHCP requests live
journalctl -u isc-kea-dhcp4-server -f | grep -E "DHCP4_PACKET|LEASE"
```

---

## DNS Infrastructure (AdGuard HA Pair)

### Servers

| Role | IP | LXC ID | Node | Web UI |
|------|-----|--------|------|--------|
| Primary | 192.168.1.253 | 1250 | proxmox3 | http://192.168.1.253:3000 |
| Secondary (Origin) | 192.168.1.224 | 116 | proxmox2 | http://192.168.1.224:3000 |
| Sync Service | 192.168.1.225 | 118 | proxmox | - |

### Configuration

| Property | Value |
|----------|-------|
| Config Path | `/opt/AdGuardHome/AdGuardHome.yaml` |
| Service | `AdGuardHome` |

### DNS Rewrite Pattern

- Services proxied through Traefik: `service.internal.lakehouse.wtf` → `192.168.1.110`
- Standalone hardware bypassing Traefik: `service.internal.lakehouse.wtf` → `<hardware-ip>`

**Why per-service rewrites (not wildcard):**
- Allows pointing some services directly to standalone hardware
- More explicit control over what resolves internally
- Flexibility for non-HTTP services or services with their own TLS

### Rewrite YAML Format

```yaml
rewrites:
  - domain: service.internal.lakehouse.wtf
    answer: 192.168.1.110
```

### Management Script

**Location:** `/home/dev/workspace/operations/scripts/adguard-rewrite.sh`

```bash
# Add DNS rewrite (defaults to Traefik IP 192.168.1.110)
./adguard-rewrite.sh add myapp.internal.lakehouse.wtf
./adguard-rewrite.sh add myapp.internal.lakehouse.wtf 192.168.1.100

# Delete rewrite
./adguard-rewrite.sh delete myapp.internal.lakehouse.wtf 192.168.1.110

# List all rewrites
./adguard-rewrite.sh list

# Test resolution on both servers
./adguard-rewrite.sh test myapp.internal.lakehouse.wtf

# Trigger immediate sync to primary
./adguard-rewrite.sh sync
```

### Manual Commands

```bash
# View current rewrites
ssh root@192.168.1.253 "grep -A 200 'rewrites:' /opt/AdGuardHome/AdGuardHome.yaml | head -100"

# Test DNS resolution
dig +short service.internal.lakehouse.wtf @192.168.1.253
dig +short service.internal.lakehouse.wtf @192.168.1.224

# Restart after manual changes (both servers!)
ssh root@192.168.1.253 "systemctl restart AdGuardHome"
ssh root@192.168.1.224 "systemctl restart AdGuardHome"
```

### API Commands

```bash
# Disable DHCP (keep DNS active)
curl -s -X POST http://127.0.0.1:80/control/dhcp/set_config \
  -H "Content-Type: application/json" \
  -d '{"enabled":false,"interface_name":"eth0"}'

# Add rewrite via API
curl -s -X POST http://192.168.1.224/control/rewrite/add \
  -u "root:PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"domain":"service.internal.lakehouse.wtf","answer":"192.168.1.110"}'
```

---

## Reverse Proxy (Traefik)

### Server

| Property | Value |
|----------|-------|
| LXC ID | 110 |
| IP | 192.168.1.110 |
| Node | proxmox |
| Version | 3.0.0 |
| Dashboard | https://traefik.internal.lakehouse.wtf |

### Configuration Files

| File | Purpose |
|------|---------|
| `/etc/traefik/traefik.yml` | Static config (entrypoints, providers) |
| `/etc/traefik/dynamic/routers.yml` | HTTP routers (Host rules) |
| `/etc/traefik/dynamic/services.yml` | Backend services (URLs) |
| `/etc/traefik/dynamic/middlewares.yml` | Middleware chains |
| `/var/log/traefik/traefik.log` | Logs |

### TLS Configuration

- Uses Cloudflare wildcard certificate via `certResolver: cloudflare`
- TLS termination happens at Traefik
- Backend connections are HTTP (internal network)

### Router Template

```yaml
http:
  routers:
    service-name-router:
      rule: "Host(`service-name.internal.lakehouse.wtf`)"
      entryPoints:
        - websecure
      service: service-name-service
      tls:
        certResolver: cloudflare
```

### Service Template

```yaml
http:
  services:
    service-name-service:
      loadBalancer:
        servers:
          - url: "http://192.168.1.XXX:PORT"
        healthCheck:
          path: /health
          interval: 30s
          timeout: 5s
```

### Common Health Check Paths

| Application | Health Path | Expected Response |
|-------------|-------------|-------------------|
| Generic | `/health` | 200 OK |
| Django | `/api/health` | 200 OK |
| Node.js | `/healthz` | 200 OK |
| Grafana | `/api/health` | 200 OK |
| Generic web | `/` | 200/302 |

### Commands

```bash
# Reload config (no restart needed for dynamic files)
ssh root@192.168.1.110 "systemctl reload traefik"

# Check config validity
ssh root@192.168.1.110 "traefik healthcheck"

# View logs
ssh root@192.168.1.110 "tail -f /var/log/traefik/traefik.log"

# List all routers via API
curl -sk https://traefik.internal.lakehouse.wtf/api/http/routers | jq '.[].name'

# List all services via API
curl -sk https://traefik.internal.lakehouse.wtf/api/http/services | jq '.[].name'

# Check specific service health
curl -sk https://traefik.internal.lakehouse.wtf/api/http/services | \
  jq '.[] | select(.name | contains("SERVICE_NAME"))'
```

### Troubleshooting

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| **404 Not Found** | Router rule doesn't match | Check Host() rule exactly |
| **502 Bad Gateway** | `curl -I http://$IP:$PORT` fails | Service not running or wrong port |
| **503 Service Unavailable** | Health check failing | Verify health path |
| **SSL Error** | Certificate issue | Check certResolver and domain |
| **DNS returns Cloudflare IP** | `dig +short` shows 104.x.x.x | AdGuard rewrite missing |

---

## WiFi/Network Hardware (Omada)

### Controller

| Property | Value |
|----------|-------|
| LXC ID | 111 |
| IP | 192.168.1.47 |
| Node | proxmox3 |
| Software Version | v6.0.0.24 |
| DHCP Option 138 | 192.168.1.47 (CAPWAP AC) |

### File Locations

| Purpose | Path |
|---------|------|
| Firmware | `/home/dev/workspace/Omada_firmware/` |
| Backups | `/home/dev/workspace/backups/omada/` |
| Config Restore | `/home/dev/workspace/omada_config_restore.cfg` |

### Known Access Points

- EAP773 (DHCP reserved)

### CAPWAP Discovery

DHCP Option 138 (192.168.1.47) is critical for Omada access points to discover the controller. This option is configured in Kea DHCP.

---

## Proxmox HA Cluster

### Nodes

| Node | IP | Node ID | CPU | RAM | Local Storage |
|------|-----|---------|-----|-----|---------------|
| proxmox (primary) | 192.168.1.137 | 1 | 4 cores | 32 GB | 94 GB (local-lvm) |
| proxmox2 | 192.168.1.125 | 2 | 8 cores | 32 GB | 816 GB (local-lvm) |
| proxmox3 | 192.168.1.126 | 3 | 8 cores | 32 GB | 816 GB (local-lvm) |

### Shared Storage

| Storage | Type | Capacity | Server |
|---------|------|----------|--------|
| TrueNas_NVMe | NFS | 899 GB | 192.168.1.98 |
| Truenas_jbod | NFS | 1.17 TB | 192.168.1.98 |
| pbs-main | PBS | 1.01 TB | 192.168.1.171 |

### Cluster Commands

```bash
# Check cluster status
ssh root@192.168.1.137 "pvecm status"

# Check node resources
for node in 192.168.1.137 192.168.1.125 192.168.1.126; do
  echo "=== $node ==="
  ssh root@$node "pct list | wc -l && free -h | grep Mem"
done

# List containers on a node
ssh root@192.168.1.137 "pct list"

# Get container config
ssh root@192.168.1.137 "pct config <CTID>"
```

---

## Core Infrastructure IPs

### Network Services

| Service | Primary IP | Secondary IP | Purpose |
|---------|------------|--------------|---------|
| Kea DHCP | 192.168.1.133 | 192.168.1.134 | IP management |
| AdGuard DNS | 192.168.1.253 | 192.168.1.224 | DNS with ad blocking |
| AdGuard Sync | 192.168.1.225 | - | Config sync |
| Traefik | 192.168.1.110 | - | Reverse proxy |
| Omada Controller | 192.168.1.47 | - | WiFi management |

### Storage

| Service | IP | Purpose |
|---------|-----|---------|
| TrueNAS | 192.168.1.98 | NFS storage |
| Proxmox Backup Server | 192.168.1.171 | Backups |

### Monitoring & Dashboards

| Service | IP | LXC ID | Port |
|---------|-----|--------|------|
| Grafana | 192.168.1.151 | 101 | 3000 |
| InfluxDB | 192.168.1.74 | 100 | 8086 |
| Uptime Kuma | 192.168.1.132 | 132 | 3001 |
| Homepage | 192.168.1.45 | 150 | 3000 |
| Stork (DHCP monitoring) | 192.168.1.234 | 135 | 8080 |

### Application Services

| Service | IP | LXC ID | Port |
|---------|-----|--------|------|
| Memos | 192.168.1.144 | 115 | 9030 |
| Hoarder | 192.168.1.102 | 117 | 3000 |
| Tandoor | 192.168.1.108 | 108 | 8002 |
| Wiki.js | 192.168.1.135 | 112 | 3000 |
| Vikunja | 192.168.1.143 | 1260 | - |
| Vaultwarden | 192.168.1.230 | 140 | - |
| ESPHome | 192.168.1.169 | 109 | 6052 |
| Zigbee2MQTT | 192.168.1.228 | 122 | 8080 |
| MQTT (prod) | 192.168.1.148 | 130 | 1883 |
| MQTT (prod-2) | 192.168.1.149 | 126 | 1883 |

### Infrastructure

| Service | IP | LXC ID | Purpose |
|---------|-----|--------|---------|
| Cloudflared | 192.168.1.100 | 102 | Cloudflare tunnel |
| Infisical | 192.168.1.29 | 107 | Secrets management |
| PostgreSQL | 192.168.1.123 | 113 | Database |
| GitHub Runner | 192.168.1.182 | 2000 | CI/CD |
| Dev Environment | 192.168.1.239 | 128 | Development |

---

## Network Audit

### Automated Audit Script

| Property | Value |
|----------|-------|
| Script | `/home/dev/workspace/operations/scripts/proxmox-network-audit.sh` |
| Schedule | Weekly via cron |
| Output | WikiJS at `/infrastructure/proxmox/network-audit` |
| Report | `/home/dev/workspace/operations/docs/proxmox/network-audit.md` |

### What It Checks

- DHCP vs static IP configuration per container
- MAC address to DHCP reservation matching
- IP address mismatches between config and actual
- Missing DHCP reservations

### Running Manually

```bash
# Dry run (shows report without uploading)
./proxmox-network-audit.sh --dry-run

# Full run (generates report and uploads to WikiJS)
./proxmox-network-audit.sh
```

---

## Common Gotchas & Lessons Learned

### DHCP Issues

1. **Kea HA only syncs leases, NOT configs**
   - Reservations must be manually synced between servers
   - Use `kea-config-sync` script for automated sync

2. **this-server-name mismatch**
   - Each Kea server needs unique identifier in HA config
   - Misconfiguration causes service to fail binding to wrong IP

3. **Devices getting different IPs**
   - Usually caused by config drift between Kea servers
   - Primary's reservation wins during sync

### DNS Issues

4. **DNS returns Cloudflare IP instead of internal**
   - AdGuard rewrite missing
   - Must add to BOTH AdGuard servers

5. **Changes go to secondary first**
   - Origin server is 192.168.1.224 (secondary)
   - Changes sync to primary automatically via adguard-sync

### Container Network

6. **Best practice: use ip=dhcp with Kea reservation**
   - Centralized IP management
   - Easier IP changes without modifying container config
   - Better audit trail in DHCP logs

7. **LXC snapshots may not work on all storage**
   - Use vzdump backups instead
   - `vzdump <CTID> --storage pbs-main --mode snapshot`

### WiFi/Omada

8. **DHCP Option 138 is critical**
   - Required for Omada AP CAPWAP discovery
   - Must point to controller IP (192.168.1.47)

### General

9. **Cron service can die silently**
   - If scheduled tasks aren't running, check `systemctl status cron`

10. **Traefik dynamic config doesn't need restart**
    - Only `systemctl reload traefik` needed for router/service changes
    - Static config changes require full restart

---

## Quick Reference Commands

### Check Service Health

```bash
# DHCP - view recent leases
ssh root@192.168.1.133 "journalctl -u isc-kea-dhcp4-server -n 20 --no-pager"

# DNS - test resolution
dig +short service.internal.lakehouse.wtf @192.168.1.253

# Traefik - check route exists
curl -sk https://traefik.internal.lakehouse.wtf/api/http/routers | jq '.[].name' | grep service

# Full chain test
curl -skI https://service.internal.lakehouse.wtf
```

### Add New Service (Quick)

```bash
SERVICE="my-service"
IP="192.168.1.XXX"
MAC="XX:XX:XX:XX:XX:XX"
PORT="8080"

# 1. Add DHCP reservation (both servers)
# 2. Add DNS rewrite
./operations/scripts/adguard-rewrite.sh add ${SERVICE}.internal.lakehouse.wtf

# 3. Add Traefik router/service (edit files on 192.168.1.110)
# 4. Reload Traefik
ssh root@192.168.1.110 "systemctl reload traefik"

# 5. Verify
curl -skI https://${SERVICE}.internal.lakehouse.wtf
```

### Backup Before Changes

```bash
# Backup Kea config
ssh root@192.168.1.133 "cp /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.backup-$(date +%Y%m%d)"

# Backup AdGuard config
ssh root@192.168.1.253 "cp /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/AdGuardHome.yaml.backup-$(date +%Y%m%d)"

# Backup container
ssh root@192.168.1.137 "vzdump <CTID> --notes-template 'Pre-change backup' --storage pbs-main --mode snapshot --compress zstd"
```

---

*Last updated: 2026-02-05*
*Source: Extracted from workspace memory files and configuration*
