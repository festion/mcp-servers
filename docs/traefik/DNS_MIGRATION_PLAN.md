# DNS Migration to VIP - Implementation Plan

## Target VIP: 192.168.1.101

## Current State
- Old Traefik IP: 192.168.1.110
- All services currently point to old IP
- DNS System: AdGuard Home (likely at adguard.internal.lakehouse.wtf)

## Migration Strategy: Phased Rollout

### Phase 1: Traefik Dashboard Only (Test Phase)
**Duration**: 5-10 minutes
**Risk**: Low - only affects dashboard access

Services to migrate:
- traefik.internal.lakehouse.wtf → 192.168.1.101

**Success Criteria**:
- Dashboard accessible at traefik.internal.lakehouse.wtf
- No errors in Traefik logs
- VIP responding correctly

---

### Phase 2: Non-Critical Services
**Duration**: 15 minutes monitoring
**Risk**: Low - personal/non-essential services

Services to migrate:
- memos.internal.lakehouse.wtf → 192.168.1.101
- hoarder.internal.lakehouse.wtf → 192.168.1.101
- gitops.internal.lakehouse.wtf → 192.168.1.101
- pairdrop.internal.lakehouse.wtf → 192.168.1.101

**Success Criteria**:
- All services accessible
- No connection errors
- SSL certificates working

---

### Phase 3: Monitoring & Observability
**Duration**: 30 minutes monitoring
**Risk**: Medium - affects visibility

Services to migrate:
- grafana.internal.lakehouse.wtf → 192.168.1.101
- uptime-kuma.internal.lakehouse.wtf → 192.168.1.101
- influxdb.internal.lakehouse.wtf → 192.168.1.101

**Success Criteria**:
- Dashboards accessible
- Metrics still flowing
- No data collection gaps

---

### Phase 4: Home Automation
**Duration**: 1 hour monitoring
**Risk**: Medium-High - affects smart home

Services to migrate:
- esphome.internal.lakehouse.wtf → 192.168.1.101
- zigbee2mqtt.internal.lakehouse.wtf → 192.168.1.101
- zwave-js-ui.internal.lakehouse.wtf → 192.168.1.101

**Success Criteria**:
- All devices responding
- No automation breakage
- Home Assistant integrations working

---

### Phase 5: Infrastructure Services
**Duration**: 2 hours monitoring
**Risk**: High - core infrastructure

Services to migrate:
- proxmox.internal.lakehouse.wtf → 192.168.1.101
- proxmox2.internal.lakehouse.wtf → 192.168.1.101
- proxmox3.internal.lakehouse.wtf → 192.168.1.101
- adguard.internal.lakehouse.wtf → 192.168.1.101
- adguard-2.internal.lakehouse.wtf → 192.168.1.101
- kea-1.internal.lakehouse.wtf → 192.168.1.101
- kea-2.internal.lakehouse.wtf → 192.168.1.101

**Success Criteria**:
- All infrastructure accessible
- DNS resolution working
- DHCP services operational

---

### Phase 6: Remaining Services
**Duration**: 1 hour monitoring
**Risk**: Low-Medium - various services

Services to migrate:
- myspeed.internal.lakehouse.wtf → 192.168.1.101
- omada.internal.lakehouse.wtf → 192.168.1.101
- pulse.internal.lakehouse.wtf → 192.168.1.101
- watchyourlan.internal.lakehouse.wtf → 192.168.1.101
- wiki.internal.lakehouse.wtf → 192.168.1.101
- netbox.internal.lakehouse.wtf → 192.168.1.101
- stork.internal.lakehouse.wtf → 192.168.1.101
- truenas.internal.lakehouse.wtf → 192.168.1.101

**Success Criteria**:
- All services operational
- No user complaints
- Everything accessible via VIP

---

## Rollback Plan

If issues occur during any phase:

1. **Immediate Rollback**:
   ```bash
   # Update DNS back to old IP
   # In AdGuard: Change record from 192.168.1.101 → 192.168.1.110
   ```

2. **Test Direct Access**:
   ```bash
   # Services should still work via old IP
   curl -k https://192.168.1.110
   ```

3. **DNS Cache Clearing**:
   ```bash
   # On client machines
   sudo systemd-resolve --flush-caches  # Linux
   # or
   ipconfig /flushdns  # Windows
   ```

---

## Pre-Migration Checklist

- ✅ Traefik HA fully operational
- ✅ VIP responding (192.168.1.101)
- ✅ Both Traefik instances healthy
- ✅ Automatic failover tested
- ✅ Config sync working
- ⏳ DNS management access ready
- ⏳ Backup of current DNS records
- ⏳ Monitoring ready (logs, dashboards)

---

## DNS Management Methods

### Method 1: AdGuard Home Web UI
1. Navigate to https://adguard.internal.lakehouse.wtf
2. Login with credentials
3. Go to Filters → DNS rewrites
4. Update A records: 192.168.1.110 → 192.168.1.101

### Method 2: AdGuard Home API (if configured)
```bash
# Get current rewrites
curl -s "http://adguard-ip/control/rewrite/list" -H "Authorization: Basic <token>"

# Add new rewrite
curl -X POST "http://adguard-ip/control/rewrite/add" \
  -H "Authorization: Basic <token>" \
  -d '{"domain":"traefik.internal.lakehouse.wtf","answer":"192.168.1.101"}'
```

### Method 3: Local /etc/hosts (fallback)
```bash
# For testing before DNS migration
echo "192.168.1.101 traefik.internal.lakehouse.wtf" | sudo tee -a /etc/hosts
```

---

## Verification Commands

```bash
# DNS resolution check
nslookup traefik.internal.lakehouse.wtf

# HTTP accessibility check
curl -k -I https://traefik.internal.lakehouse.wtf

# Certificate check
openssl s_client -connect 192.168.1.101:443 -servername traefik.internal.lakehouse.wtf < /dev/null 2>/dev/null | grep subject

# Full service test
curl -sk https://192.168.1.101 -H "Host: traefik.internal.lakehouse.wtf"
```

---

## Post-Migration Tasks

After all phases complete:

1. **Monitor for 24 hours** - Watch for any delayed issues
2. **Update documentation** - Record new IP in docs
3. **Remove old IP from routing** - Clean up Traefik config if needed
4. **Schedule regular failover tests** - Monthly validation

---

**Plan Created**: 2025-11-09  
**Ready to Execute**: Yes  
**Estimated Total Time**: 4-6 hours (spread across phases)
