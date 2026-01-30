# DNS Migration to VIP - Ready to Begin

## Current Status

✅ **Traefik HA**: Fully operational
- Primary: LXC 110 @ 192.168.1.110
- Secondary: LXC 121 @ 192.168.1.103
- **VIP: 192.168.1.101** ← Target for DNS migration

✅ **VIP Verified**: Accessible and serving all services correctly

## Services Currently Using Traefik (192.168.1.110)

These services should be migrated to VIP (192.168.1.101):

**Behind Traefik @ 192.168.1.110:**
- traefik.internal.lakehouse.wtf
- pairdrop.internal.lakehouse.wtf
- esphome.internal.lakehouse.wtf
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

**Note**: Some services are using different routing:
- grafana, hoarder, gitops → 192.168.1.154 (different host/proxy?)
- memos, uptime-kuma, influxdb, zigbee2mqtt → Cloudflare IPs (tunneled)
- truenas → 192.168.1.98 (direct access, not via Traefik)

## Quick Start

### Option 1: Start Now (Recommended - Traefik Dashboard Only)

1. **Open AdGuard Home**: https://adguard.internal.lakehouse.wtf
2. **Go to**: Filters → DNS rewrites
3. **Find and update**: 
   - Domain: `traefik.internal.lakehouse.wtf`
   - Change IP: `192.168.1.110` → `192.168.1.101`
4. **Save** and wait 30 seconds for DNS to propagate
5. **Test**:
   ```bash
   nslookup traefik.internal.lakehouse.wtf
   # Should show: 192.168.1.101
   ```
6. **Verify**: Open https://traefik.internal.lakehouse.wtf/dashboard/ in browser

If successful, proceed with remaining services.

### Option 2: Migrate All at Once (Faster but Higher Risk)

Update all services listed above from 192.168.1.110 → 192.168.1.101 in AdGuard.

**Pros**: Done quickly (5-10 minutes)
**Cons**: If there's an issue, affects all services at once

### Option 3: Phased Approach (Safest)

Follow the detailed plan in `/home/dev/workspace/docs/traefik/DNS_MIGRATION_INSTRUCTIONS.md`

## Verification Script

Run this anytime to check migration progress:
```bash
/home/dev/workspace/verify-dns-migration.sh
```

## Documentation

All migration docs saved to:
- `/home/dev/workspace/docs/traefik/DNS_MIGRATION_INSTRUCTIONS.md` - Step-by-step guide
- `/home/dev/workspace/docs/traefik/DNS_MIGRATION_PLAN.md` - Full migration plan
- `/home/dev/workspace/verify-dns-migration.sh` - Verification script

## Important Notes

1. **DNS Cache**: After each change, you may need to flush DNS cache:
   ```bash
   sudo systemd-resolve --flush-caches
   ```

2. **Rollback**: If anything breaks, just change the DNS record back to 192.168.1.110

3. **VIP Always Works**: Even before DNS migration, you can access services directly via:
   ```bash
   curl -sk -H "Host: service.internal.lakehouse.wtf" https://192.168.1.101/
   ```

4. **Old IP Still Works**: After DNS migration, 192.168.1.110 will still work for direct access (but won't have HA)

## What Happens After Migration?

✅ All traffic goes through VIP (192.168.1.101)
✅ Automatic failover if primary Traefik fails
✅ Zero-downtime maintenance possible
✅ All services benefit from HA setup

## Current State

**Migrated**: 0/18 services
**Remaining**: 18 services

Run `/home/dev/workspace/verify-dns-migration.sh` after each batch to track progress!

---

**Ready to start?** The system is stable and ready for DNS migration.

Choose your approach above and begin! I recommend starting with just the traefik dashboard (Option 1) to verify everything works before migrating other services.
