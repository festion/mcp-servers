# DNS Migration to VIP - Step-by-Step Instructions

## Current Status
✅ VIP (192.168.1.101) is accessible and serving traffic correctly
✅ Traefik HA fully operational
✅ Ready to begin DNS migration

---

## Phase 1: Traefik Dashboard (Start Here)

### Step 1: Access AdGuard Home
1. Open browser to: https://adguard.internal.lakehouse.wtf
2. Login with your credentials

### Step 2: Navigate to DNS Rewrites
1. Click on **Filters** in the left sidebar
2. Click on **DNS rewrites** tab

### Step 3: Find Current Traefik Record
Look for entry:
- **Domain**: traefik.internal.lakehouse.wtf
- **Answer**: 192.168.1.110

### Step 4: Update to VIP
**Option A: Edit existing record**
1. Click edit/pencil icon next to traefik.internal.lakehouse.wtf
2. Change Answer from `192.168.1.110` to `192.168.1.101`
3. Click Save

**Option B: Delete and recreate**
1. Delete the existing traefik.internal.lakehouse.wtf record
2. Click "Add DNS rewrite"
3. Domain: `traefik.internal.lakehouse.wtf`
4. Answer: `192.168.1.101`
5. Click Save

### Step 5: Verify Change
From terminal, run:
```bash
# Clear DNS cache first
sudo systemd-resolve --flush-caches

# Check new DNS resolution
nslookup traefik.internal.lakehouse.wtf
# Should show: Address: 192.168.1.101

# Test access
curl -sk https://traefik.internal.lakehouse.wtf/dashboard/
# Should return Traefik dashboard HTML
```

### Step 6: Monitor for 5 Minutes
- Check Traefik logs for errors
- Access dashboard in browser
- Verify SSL certificate is valid

**If everything works, proceed to Phase 2**

---

## Phase 2: Non-Critical Services

Update these DNS records in AdGuard:
| Domain | Old IP | New IP |
|--------|--------|--------|
| memos.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| hoarder.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| gitops.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| pairdrop.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |

**Verification**:
```bash
# Test each service
for service in memos hoarder gitops pairdrop; do
  echo "Testing $service..."
  curl -sk -I https://$service.internal.lakehouse.wtf | head -1
done
```

---

## Phase 3: Monitoring Services

Update these DNS records:
| Domain | Old IP | New IP |
|--------|--------|--------|
| grafana.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| uptime-kuma.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| influxdb.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |

**Monitor for 30 minutes** - ensure metrics continue flowing

---

## Phase 4: Home Automation

Update these DNS records:
| Domain | Old IP | New IP |
|--------|--------|--------|
| esphome.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| zigbee2mqtt.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| zwave-js-ui.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |

**Monitor for 1 hour** - verify automations still work

---

## Phase 5: Infrastructure (High Risk - Be Careful!)

Update these DNS records:
| Domain | Old IP | New IP |
|--------|--------|--------|
| proxmox.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| proxmox2.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| proxmox3.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| adguard.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| adguard-2.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| kea-1.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| kea-2.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |

**Important**: After updating adguard.internal.lakehouse.wtf, you'll be accessing AdGuard via the VIP!

---

## Phase 6: Remaining Services

Update these DNS records:
| Domain | Old IP | New IP |
|--------|--------|--------|
| myspeed.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| omada.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| pulse.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| watchyourlan.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| wiki.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| netbox.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| stork.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |
| truenas.internal.lakehouse.wtf | 192.168.1.110 | 192.168.1.101 |

---

## Quick Verification Script

Save this as `/tmp/verify-dns-migration.sh`:

```bash
#!/bin/bash
# Verify all services point to VIP

VIP="192.168.1.101"
SERVICES=(
  "traefik" "memos" "hoarder" "gitops" "pairdrop"
  "grafana" "uptime-kuma" "influxdb"
  "esphome" "zigbee2mqtt" "zwave-js-ui"
  "proxmox" "proxmox2" "proxmox3"
  "adguard" "adguard-2" "kea-1" "kea-2"
  "myspeed" "omada" "pulse" "watchyourlan"
  "wiki" "netbox" "stork" "truenas"
)

echo "=== DNS Migration Verification ==="
echo "Target VIP: $VIP"
echo ""

migrated=0
not_migrated=0

for service in "${SERVICES[@]}"; do
  resolved=$(nslookup $service.internal.lakehouse.wtf 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
  if [ "$resolved" == "$VIP" ]; then
    echo "✅ $service.internal.lakehouse.wtf → $resolved"
    ((migrated++))
  else
    echo "❌ $service.internal.lakehouse.wtf → $resolved (expected $VIP)"
    ((not_migrated++))
  fi
done

echo ""
echo "Summary: $migrated migrated, $not_migrated remaining"
```

Run with:
```bash
chmod +x /tmp/verify-dns-migration.sh
/tmp/verify-dns-migration.sh
```

---

## Rollback Procedure

If any issues occur:

1. **In AdGuard**: Change the DNS record back to 192.168.1.110
2. **Clear DNS caches**: 
   ```bash
   sudo systemd-resolve --flush-caches
   ```
3. **Test**: Access service via old IP directly
4. **Report issue**: Note what went wrong for troubleshooting

---

## When You're Done

After all phases complete successfully:

1. ✅ Run the verification script
2. ✅ Monitor for 24 hours
3. ✅ Update documentation with new VIP
4. ✅ Consider testing a failover to verify HA

---

**Ready to start?** Begin with Phase 1 (Traefik dashboard only)
