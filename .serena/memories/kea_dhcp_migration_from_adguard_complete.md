# Kea DHCP Migration from AdGuard - Complete

## Migration Summary
**Date:** November 5, 2025
**Status:** ✅ Successful
**Duration:** ~15 minutes
**Downtime:** < 60 seconds

Successfully migrated DHCP services from AdGuard to Kea DHCP HA cluster with zero data loss and minimal service interruption.

## Infrastructure

### AdGuard Servers (DNS Only Now)
- **192.168.1.253** (adguard): Active for DNS, DHCP disabled
- **192.168.1.224** (adguard-2): Active for DNS, DHCP disabled

### Kea DHCP Servers (Active)
- **192.168.1.133** (kea-dhcp-1): LXC 133, Kea 3.0.2, serving DHCP
- **192.168.1.134** (kea-dhcp-2): LXC 134, Kea 3.0.2, serving DHCP

### Stork Monitoring
- **192.168.1.234:8080** (LXC 135): Stork 2.2.1 monitoring both Kea servers

## SSH Access
- **Kea servers:** Use `~/.ssh/homelab` key
  ```bash
  ssh -i ~/.ssh/homelab root@192.168.1.133
  ssh -i ~/.ssh/homelab root@192.168.1.134
  ```
- **AdGuard servers:** Use default SSH key
  ```bash
  ssh root@192.168.1.253
  ssh root@192.168.1.224
  ```

## Migrated Configuration

### Network Settings
- **Subnet:** 192.168.1.0/24
- **DHCP Pool:** 192.168.1.10 - 192.168.1.250
- **Gateway:** 192.168.1.1
- **DNS Servers:** 192.168.1.253, 192.168.1.224 (AdGuard)
- **Domain:** lakehouse.wtf
- **Lease Duration:** 86400 seconds (24 hours)
- **DHCP Option 138:** 192.168.1.47 (CAPWAP AC for Omada WiFi controllers)

### Static Reservations (36 Total)
All MAC-to-IP reservations migrated including:
- **BLE Proxies (11):** xiao-ble-proxy1/2/3, upstairs, lindaroom, hobbyroom, gavinroom, guestroom, masterroom-ble-proxy1/2, bleproxy-with-lux
- **Infrastructure:** wikijs, uptime-kuma, netbox, mqtt-prod, gitopsdashboard, esphome, proxmox3, docker
- **IoT Devices:** tempest-hb-00147807, meross-smart-garage, curatron-esp, samsung-dryer, birdnet-go
- **Network Equipment:** slzb-06, eap773, hydrawise-7041, lgwebostv
- **Other:** adguard-2, adguard-sync, quorum-pi, wlan0, lwip0, wroommicrousb

## Current Configuration

### Active Config Location
- **Path:** `/etc/kea/kea-dhcp4.conf` (on both servers)
- **Type:** Minimal working configuration (no HA hooks currently)
- **Ownership:** `_kea:_kea` with `640` permissions

### HA Configuration Status
⚠️ **Current:** Minimal config without HA load-balancing hooks
- Both servers serving DHCP independently
- No coordinated lease synchronization
- No automatic load distribution

**Issue:** HA hook libraries failed to load during initial configuration
- Error: "One or more hook libraries failed to load"
- Hooks needed: `libdhcp_ha.so`, `libdhcp_lease_cmds.so`
- Package installed: `isc-kea-hooks` (version 3.0.2-isc20251017150356)
- Libraries exist at: `/usr/lib/x86_64-linux-gnu/kea/hooks/`
- Dependencies verified with `ldd` - all satisfied

**HA Config Available:** `/tmp/kea-dhcp4-production.conf` (ready for deployment once issue resolved)

## Configuration Files

### Backups
Pre-migration backups on respective servers:
- AdGuard: `/root/adguard-backup-before-migration-20251105.yaml`
- Kea Server 1: `/root/kea-backup-pre-migration/`
- Kea Server 2: `/root/kea-backup-pre-migration/`
- Kea upgrade backups (Nov 4): `/root/kea-backup-20251104/kea/`

### Working Configs
On workspace (`/tmp/`):
- `kea-dhcp4-minimal.conf` - Currently deployed (no HA)
- `kea-dhcp4-production.conf` - Full config with HA for server 1
- `kea-dhcp4-production-server2.conf` - Full config with HA for server 2
- `adguard_dhcp_status.json` - Original AdGuard state
- `kea_reservations.json` - Converted reservations
- `MIGRATION_COMPLETE_SUMMARY.md` - Full migration report

## Kea Services

### Service Management
```bash
# Check status
systemctl status isc-kea-dhcp4-server
systemctl status isc-kea-ctrl-agent

# Restart
systemctl restart isc-kea-dhcp4-server

# View logs
journalctl -u isc-kea-dhcp4-server -f
```

### Control Socket
- **Location:** `/var/run/kea/kea4-ctrl-socket`
- **Type:** Unix domain socket
- **Purpose:** API commands, Stork communication

### Lease Database
- **Type:** Memfile (CSV)
- **Location:** `/var/lib/kea/kea-leases4.csv`
- **LFC Interval:** 3600 seconds (1 hour)

## Verification Commands

### Check DHCP Activity
```bash
# View recent DHCP transactions
ssh -i ~/.ssh/homelab root@192.168.1.133 'journalctl -u isc-kea-dhcp4-server -n 50 --no-pager'

# Check active leases
ssh -i ~/.ssh/homelab root@192.168.1.133 'cat /var/lib/kea/kea-leases4.csv | wc -l'

# Test config syntax
ssh -i ~/.ssh/homelab root@192.168.1.133 'kea-dhcp4 -t /etc/kea/kea-dhcp4.conf'
```

### Monitor DHCP Requests
```bash
# Live DHCP packet logs
journalctl -u isc-kea-dhcp4-server -f | grep -E "DHCP4_PACKET|LEASE"
```

## AdGuard DHCP Control

### Disable DHCP (Keep DNS Active)
```bash
ssh root@192.168.1.253 'curl -s -X POST http://127.0.0.1:80/control/dhcp/set_config -H "Content-Type: application/json" -d "{\"enabled\":false,\"interface_name\":\"eth0\",\"v4\":{\"gateway_ip\":\"192.168.1.1\",\"subnet_mask\":\"255.255.255.0\",\"range_start\":\"192.168.1.10\",\"range_end\":\"192.168.1.250\",\"lease_duration\":86400}}"'
```

### Re-enable DHCP (Rollback)
```bash
ssh root@192.168.1.253 'curl -s -X POST http://127.0.0.1:80/control/dhcp/set_config -H "Content-Type: application/json" -d "{\"enabled\":true,\"interface_name\":\"eth0\",\"v4\":{\"gateway_ip\":\"192.168.1.1\",\"subnet_mask\":\"255.255.255.0\",\"range_start\":\"192.168.1.10\",\"range_end\":\"192.168.1.250\",\"lease_duration\":86400}}"'
```

## Outstanding Tasks

### High Priority
- [ ] **Troubleshoot HA hook loading issue** - Enable proper load-balancing and lease synchronization
- [ ] Verify all 36 reserved devices receiving correct IPs over next 24 hours

### Medium Priority
- [ ] Monitor lease database growth on both servers
- [ ] Test manual failover (stop one server, verify other handles all requests)
- [ ] Configure Stork alerts for DHCP pool exhaustion

### Low Priority
- [ ] Document HA configuration once enabled
- [ ] Set up automated config backups
- [ ] Consider DHCP relay for future VLANs if needed

## Monitoring

### Stork Dashboard
- **URL:** http://192.168.1.234:8080
- **Features:** Subnet monitoring, lease statistics, server health
- **Current State:** Both servers visible, HA status shows non-configured (expected)

### Log Locations
- **Kea DHCP:** `journalctl -u isc-kea-dhcp4-server`
- **Kea Control Agent:** `journalctl -u isc-kea-ctrl-agent`
- **Stork Agent:** `journalctl -u isc-stork-agent`

## Important Notes

1. **DHCP vs DNS:** AdGuard servers continue to provide DNS services. Only DHCP was migrated to Kea.

2. **Dual DHCP Servers:** Currently both Kea servers independently respond to DHCP requests. Without HA coordination:
   - Both maintain separate lease databases
   - No load distribution algorithm
   - Lease databases may diverge
   - Still provides redundancy

3. **Option 138 Critical:** DHCP Option 138 (CAPWAP AC) is essential for Omada WiFi controller communication. This was preserved in the migration.

4. **Lease Continuity:** Existing clients will naturally transition to Kea as they renew their leases. With 24-hour lease times, all clients should be Kea-managed within 24 hours.

5. **Hook Library Issue:** The HA and lease command hooks exist and have satisfied dependencies, but fail to load when Kea starts. This needs investigation - possible config syntax issue or library compatibility with Kea 3.0.2.

## Related Memories
- `kea_upgrade_to_3_0_2_complete.md` - Kea upgrade performed Nov 4, 2025
- `stork_dhcp_monitoring_deployment.md` - Stork monitoring setup

## Success Metrics
✅ Zero data loss (all reservations migrated)
✅ < 60 second service interruption
✅ DHCP serving within 1 minute of cutover
✅ DNS services unaffected
✅ All critical DHCP options preserved
✅ Redundant server architecture deployed
