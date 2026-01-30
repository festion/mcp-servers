# AdGuard DNS Rewrite Configuration - COMPLETE

**Date**: 2025-11-07
**Objective**: Add DNS rewrite for stork.internal.lakehouse.wtf to resolve to Traefik (192.168.1.110)

## Issue
`stork.internal.lakehouse.wtf` was resolving to Cloudflare IPs (104.21.16.254, 172.67.217.193) instead of the internal Traefik server, preventing Uptime Kuma from monitoring the service.

## Solution Implemented

### 1. Added DNS Rewrite to Both AdGuard Servers

**Primary AdGuard (192.168.1.253):**
```bash
# Backup configuration
cp /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/AdGuardHome.yaml.backup-20251107

# Add rewrite rule
sed -i '/rewrites:/a\    - domain: stork.internal.lakehouse.wtf\n      answer: 192.168.1.110\n      enabled: true' /opt/AdGuardHome/AdGuardHome.yaml

# Restart service
systemctl restart AdGuardHome
```

**Secondary AdGuard (192.168.1.224):**
```bash
# Backup configuration
cp /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/AdGuardHome.yaml.backup-20251107

# Add rewrite rule
sed -i '/rewrites:/a\    - domain: stork.internal.lakehouse.wtf\n      answer: 192.168.1.110\n      enabled: true' /opt/AdGuardHome/AdGuardHome.yaml

# Restart service
systemctl restart AdGuardHome
```

### 2. Rewrite Configuration

```yaml
rewrites:
  - domain: stork.internal.lakehouse.wtf
    answer: 192.168.1.110
    enabled: true
```

## Verification Results

### DNS Resolution Test
```bash
# Default resolver (uses 192.168.1.253 primary)
$ dig +short stork.internal.lakehouse.wtf
192.168.1.110

# Primary AdGuard (192.168.1.253)
$ dig +short @192.168.1.253 stork.internal.lakehouse.wtf
192.168.1.110

# Secondary AdGuard (192.168.1.224)
$ dig +short @192.168.1.224 stork.internal.lakehouse.wtf
192.168.1.110
```

✅ **All DNS servers return correct IP**

### HTTPS Access Test
```bash
$ curl -I https://stork.internal.lakehouse.wtf
HTTP/2 200
content-type: text/html; charset=utf-8
strict-transport-security: max-age=31536000; includeSubDomains; preload
```

✅ **Stork accessible via HTTPS through Traefik**

## Service Status

| Component | IP Address | Status |
|-----------|------------|--------|
| Stork Server | 192.168.1.234:8080 | ✅ UP |
| Traefik Proxy | 192.168.1.110:443 | ✅ UP |
| AdGuard Primary | 192.168.1.253 | ✅ UP (rewrite active) |
| AdGuard Secondary | 192.168.1.224 | ✅ UP (rewrite active) |
| Traefik stork-service | Backend health | ✅ UP |
| HTTPS Access | https://stork.internal.lakehouse.wtf | ✅ 200 OK |

## Files Modified

### Primary AdGuard (192.168.1.253)
- `/opt/AdGuardHome/AdGuardHome.yaml` (updated)
- `/opt/AdGuardHome/AdGuardHome.yaml.backup-*` (backup created)

### Secondary AdGuard (192.168.1.224)
- `/opt/AdGuardHome/AdGuardHome.yaml` (updated)
- `/opt/AdGuardHome/AdGuardHome.yaml.backup-*` (backup created)

## Impact

### Before
- `stork.internal.lakehouse.wtf` → Cloudflare IPs (external)
- Uptime Kuma: ❌ Cannot monitor Stork
- Users: ❌ Cannot access Stork via internal hostname

### After
- `stork.internal.lakehouse.wtf` → 192.168.1.110 (Traefik)
- Uptime Kuma: ✅ Can monitor Stork
- Users: ✅ Can access Stork via internal hostname
- Traffic: ✅ Stays on internal network

## Best Practices Applied

1. ✅ **Configuration Backups**: Created timestamped backups before changes
2. ✅ **High Availability**: Updated both primary and secondary DNS servers
3. ✅ **Service Restart**: Properly restarted services to apply changes
4. ✅ **Verification**: Tested DNS resolution and HTTPS access
5. ✅ **Documentation**: Recorded all changes and commands used

## Related Services

The following services also use DNS rewrites to point to Traefik:
- kea-1.internal.lakehouse.wtf → 192.168.1.110
- kea-2.internal.lakehouse.wtf → 192.168.1.110

## Troubleshooting

If Stork becomes inaccessible:

### Check DNS Resolution
```bash
dig +short stork.internal.lakehouse.wtf
# Expected: 192.168.1.110
```

### Check AdGuard Rewrite
```bash
ssh root@192.168.1.253 "grep -A 3 'stork.internal' /opt/AdGuardHome/AdGuardHome.yaml"
ssh root@192.168.1.224 "grep -A 3 'stork.internal' /opt/AdGuardHome/AdGuardHome.yaml"
```

### Check Traefik Backend
```bash
ssh root@192.168.1.110 "curl -s https://traefik.internal.lakehouse.wtf/api/http/services" | jq '.[] | select(.name | contains("stork"))'
```

### Test Direct Backend Access
```bash
curl -I http://192.168.1.234:8080
```

## Success Criteria Met

✅ DNS rewrite added to both AdGuard servers
✅ DNS resolution returns correct internal IP (192.168.1.110)
✅ HTTPS access works through Traefik
✅ Traefik backend health check shows UP
✅ Configuration backups created
✅ Services restarted successfully
✅ Full verification completed

## Completion Status

**Status**: ✅ **COMPLETE**

All DNS rewrites configured, tested, and verified. Stork is now accessible via internal hostname through Traefik reverse proxy.
