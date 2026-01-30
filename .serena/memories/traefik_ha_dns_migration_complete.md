# Traefik HA DNS Migration Complete - 2025-11-09

## Summary

Successfully completed DNS migration from old Traefik IP (192.168.1.110) to VIP (192.168.1.101) for all services. Fixed critical AdGuard DNS performance issue that was causing connection failures.

## Migration Results

**Total Services Migrated:** 25/26 to VIP 192.168.1.101

**Services on VIP:**
- traefik.internal.lakehouse.wtf
- memos.internal.lakehouse.wtf
- hoarder.internal.lakehouse.wtf
- gitops.internal.lakehouse.wtf
- pairdrop.internal.lakehouse.wtf
- grafana.internal.lakehouse.wtf
- uptime-kuma.internal.lakehouse.wtf
- influxdb.internal.lakehouse.wtf
- esphome.internal.lakehouse.wtf
- zigbee2mqtt.internal.lakehouse.wtf
- zwave-js-ui.internal.lakehouse.wtf
- proxmox.internal.lakehouse.wtf
- proxmox2.internal.lakehouse.wtf
- proxmox3.internal.lakehouse.wtf
- adguard.internal.lakehouse.wtf
- adguard-2.internal.lakehouse.wtf
- kea-1.internal.lakehouse.wtf
- kea-2.internal.lakehouse.wtf
- myspeed.internal.lakehouse.wtf
- omada.internal.lakehouse.wtf
- pulse.internal.lakehouse.wtf
- watchyourlan.internal.lakehouse.wtf
- wiki.internal.lakehouse.wtf
- netbox.internal.lakehouse.wtf
- stork.internal.lakehouse.wtf

**Excluded (correct):**
- truenas.internal.lakehouse.wtf → 192.168.1.98 (direct access, not via Traefik)

## Traefik HA Configuration

**Primary Traefik:**
- Container: LXC 110
- IP: 192.168.1.110
- Priority: 200 (becomes 80 when unhealthy)
- Config sync: lsyncd to secondary

**Secondary Traefik:**
- Container: LXC 121
- IP: 192.168.1.103
- Priority: 100
- Auto-reload: inotify watcher for config changes

**VIP:** 192.168.1.101
- Managed by keepalived VRRP
- Automatic failover when primary fails
- Health check script monitors Traefik service

## Critical Issue Fixed: AdGuard DNS Performance

### Problem
AdGuard DNS was causing connection failures and timeouts when set as primary DNS. Users lost connection and had to fall back to external DNS (8.8.8.8).

### Root Cause
```yaml
# /opt/AdGuardHome/AdGuardHome.yaml
dns:
  upstreams_cache_enabled: false  # ← This was the problem
  upstreams_cache_size: 0         # ← No cache for upstream queries
```

Every external DNS query (google.com, claude.ai, API calls, etc.) required a fresh DoH (DNS-over-HTTPS) query to upstream servers (Cloudflare, AdGuard, Quad9). These queries took 1-3 seconds on cold cache, causing:
- API call timeouts
- Slow page loads
- Connection failures
- Poor user experience

### Solution Applied

Updated both AdGuard servers:
```yaml
dns:
  upstreams_cache_enabled: true   # ← Enabled upstream caching
  upstreams_cache_size: 1048576   # ← 1MB cache for upstream responses
```

**Applied to:**
- Primary AdGuard: 192.168.1.253 (LXC container)
- Secondary AdGuard: 192.168.1.224 (LXC container)

### Current DNS Configuration

**Recommended /etc/resolv.conf:**
```
# --- BEGIN PVE ---
search internal.lakehouse.wtf
nameserver 192.168.1.253  # Primary AdGuard (with VIP entries + upstream caching)
nameserver 192.168.1.224  # Secondary AdGuard (with VIP entries + upstream caching)
nameserver 8.8.8.8        # External fallback (Google DNS)
# --- END PVE ---
```

**Why 8.8.8.8 fallback is needed:**
- Provides resilience if both internal AdGuard servers fail
- System remains accessible even during AdGuard maintenance
- No single point of failure

## AdGuard Configuration Synchronization

Both AdGuard servers now have identical DNS rewrite entries pointing all 25 services to VIP 192.168.1.101.

**Config file:** `/opt/AdGuardHome/AdGuardHome.yaml`

**Backup before migration:**
- `/opt/AdGuardHome/AdGuardHome.yaml.backup-20251109-111529`

**Important Notes:**
- AdGuard rewrites its config file when making changes via API
- Always stop AdGuard before manually editing config
- Restart AdGuard after config changes
- Both servers must be kept in sync manually (no automatic sync configured)

## Verification

**Verification script:** `/home/dev/workspace/verify-dns-migration.sh`

Run this script to verify migration status:
```bash
/home/dev/workspace/verify-dns-migration.sh
```

Expected output: 25 migrated, 1 remaining (truenas)

## Benefits of Completed Migration

✅ All traffic to 25 services now goes through VIP (192.168.1.101)
✅ Automatic failover if primary Traefik fails (4-second failover window)
✅ Zero-downtime maintenance possible
✅ All infrastructure services benefit from HA setup
✅ DNS performance restored with upstream caching enabled
✅ Resilient DNS with internal + external fallback

## Next Steps

1. **Monitor AdGuard performance** for 24-48 hours to ensure upstream caching resolves the issues
2. **Set up monitoring** for VIP and keepalived services (Uptime Kuma)
3. **Schedule regular failover tests** (monthly) to verify HA continues working
4. **Consider AdGuard config sync** between primary and secondary (currently manual)

## Related Documentation

- Traefik HA Implementation: `/home/dev/workspace/docs/traefik/TRAEFIK_HA_IMPLEMENTATION_STATUS.md`
- DNS Migration Plan: `/home/dev/workspace/docs/traefik/DNS_MIGRATION_PLAN.md`
- Proxmox HA Investigation: `/home/dev/workspace/docs/PROXMOX_HA_REBOOT_INVESTIGATION.md`

## Status: COMPLETE ✅
