# Omada Network Infrastructure - DHCP Reservations

**Date:** 2025-11-12 20:55 UTC
**Status:** ✅ All devices configured with DHCP reservations
**Total Reservations:** 54 (synchronized across both Kea servers)

---

## Overview

All Omada network infrastructure devices now have static DHCP reservations to ensure stable IP addresses for management, monitoring, and reliable operation.

---

## Omada Infrastructure Devices

| Device Type | Hostname | IP Address | MAC Address | Status |
|-------------|----------|------------|-------------|--------|
| **Controller** | omada-controller | 192.168.1.47 | bc:24:11:db:4f:cd | ✅ Online |
| **Access Point** | upstairs-ap-eap773 | 192.168.1.22 | a8:29:48:c0:01:60 | ✅ Adopted |
| **Switch** | sw-main-sg3218xp | 192.168.1.210 | ec:75:0c:a5:c1:9d | ✅ Online |
| **Access Point** | downstairs-ap-eap773 | 192.168.1.242 | 20:36:26:dd:7e:e0 | ✅ Online |

---

## Device Details

### Omada Controller
- **Model:** Software Controller (Debian)
- **IP:** 192.168.1.47
- **MAC:** bc:24:11:db:4f:cd
- **Hostname:** omada-controller
- **Purpose:** Centralized management for all Omada devices
- **Ports:** 8043 (HTTPS), 8088 (HTTP), 8843 (Guest Portal)
- **Access:** https://omada.internal.lakehouse.wtf

### UpstairsAP (EAP773)
- **Model:** TP-Link EAP773(US) v1.0
- **Firmware:** 1.0.14
- **IP:** 192.168.1.22
- **MAC:** a8:29:48:c0:01:60
- **Hostname:** upstairs-ap-eap773
- **Status:** ADOPTED (auto=true)

### DownstairsAP (EAP773)
- **Model:** TP-Link EAP773(US) v1.0
- **Firmware:** 1.0.14
- **IP:** 192.168.1.242
- **MAC:** 20:36:26:dd:7e:e0
- **Hostname:** downstairs-ap-eap773
- **Status:** CONNECTED

### SW-Main (SG3218XP)
- **Model:** TP-Link SG3218XP-M2 v1.0
- **Firmware:** 1.0.11
- **IP:** 192.168.1.210
- **MAC:** ec:75:0c:a5:c1:9d
- **Hostname:** sw-main-sg3218xp
- **Status:** CONNECTED

---

## Why DHCP Reservations for Infrastructure

### Benefits

1. **Reliable Controller Communication**
   - APs maintain stable connection to controller
   - No disruption from IP changes
   - Faster reconnection after reboot

2. **Simplified Monitoring**
   - Consistent IPs for logging and alerts
   - Easier troubleshooting
   - Network maps remain accurate

3. **Management Efficiency**
   - Document "Kitchen AP = 192.168.1.X"
   - QoS and firewall rules remain valid
   - Remote access always works

4. **Prevent Conflicts**
   - Infrastructure devices stay online 24/7
   - DHCP lease expiration won't cause issues
   - Avoids rare but annoying IP reassignment

### What Should Have Reservations

✅ **Always Reserve:**
- Network controllers (Omada, Unifi, etc.)
- Access Points
- Switches (managed)
- Servers (physical and virtual)
- Network storage (NAS)
- Security cameras
- IoT devices needing port forwarding
- Printers
- Smart home hubs

❌ **Dynamic DHCP OK:**
- Guest devices (phones, tablets, laptops)
- Temporary devices
- IoT sensors (if no port forwarding needed)

---

## Implementation Timeline

### Initial Issue Discovery
- **Problem:** UpstairsAP stuck in "ADOPTING" state
- **Cause:** IP changed from reserved 192.168.1.73 to dynamic 192.168.1.22
- **Impact:** AP couldn't complete adoption process

### Resolution Steps

**1. Identified Devices** ✅
```bash
# Found via ARP table and Omada Controller
192.168.1.210 - ec:75:0c:a5:c1:9d - SW-Main-SG3218XP
192.168.1.242 - 20:36:26:dd:7e:e0 - DownstairsAP
192.168.1.22  - a8:29:48:c0:01:60 - UpstairsAP
192.168.1.47  - bc:24:11:db:4f:cd - Omada Controller
```

**2. Added Reservations** ✅
```bash
# Removed old incorrect reservation (UpstairsAP was at .73)
# Added correct reservations for all 4 devices
# Applied to both Kea servers (192.168.1.133 and 192.168.1.134)
```

**3. Restarted Kea Servers** ✅
```bash
systemctl restart isc-kea-dhcp4-server
# Both servers: ✅ Active and running
```

**4. Verified Adoption** ✅
```bash
# UpstairsAP automatically renewed DHCP lease
# Got IP 192.168.1.22 as reserved
# Completed adoption: "adopt[auto=true] ok"
```

---

## Configuration Files

### Kea DHCP Servers

**Primary:** 192.168.1.133
**Secondary:** 192.168.1.134
**Config:** `/etc/kea/kea-dhcp4.conf`

**Backups Created:**
- Server 1: `/etc/kea/kea-dhcp4.conf.backup-20251112-205047`
- Server 2: `/etc/kea/kea-dhcp4.conf.backup-20251112-205048`

### Reservation Format
```json
{
  "hw-address": "bc:24:11:db:4f:cd",
  "ip-address": "192.168.1.47",
  "hostname": "omada-controller"
}
```

---

## Verification Commands

### Check All Omada Devices Online
```bash
for ip in 192.168.1.47 192.168.1.22 192.168.1.210 192.168.1.242; do
  ping -c 1 $ip > /dev/null 2>&1 && echo "✅ $ip online" || echo "❌ $ip offline"
done
```

### Verify DHCP Reservations
```bash
# On Kea server
python3 -c "import json; config = json.load(open('/etc/kea/kea-dhcp4.conf')); \
  omada = [r for r in config['Dhcp4']['subnet4'][0]['reservations'] \
  if any(x in r['hostname'].lower() for x in ['omada', 'eap', 'ap', 'sw-main'])]; \
  [print(f\"{r['ip-address']:15} | {r['hw-address']:17} | {r['hostname']}\") for r in sorted(omada, key=lambda x: x['ip-address'])]"
```

### Check MAC Addresses
```bash
# Ping first to populate ARP table
ping -c 1 192.168.1.22
# View ARP entry
ip neigh show 192.168.1.22
```

### Monitor Omada Controller Logs
```bash
# On Omada Controller
tail -f /opt/tplink/EAPController/logs/server.log | grep -i adopt
```

---

## Troubleshooting

### AP Stuck in "ADOPTING"

**Symptoms:**
- AP shows "ADOPTING" status indefinitely
- Device online but not adopted

**Common Causes:**
1. IP address changed from expected address
2. Firewall blocking controller communication
3. AP firmware incompatible with controller

**Resolution:**
1. Check AP has correct IP via DHCP reservation
2. Restart AP to force DHCP renewal
3. Verify controller can reach AP IP
4. Check Omada Controller logs for adoption errors

### Device Not Getting Reserved IP

**Symptoms:**
- Device gets different IP than reservation
- Reservation shows in config but not applied

**Common Causes:**
1. MAC address mismatch in reservation
2. Kea service not restarted after config change
3. Existing DHCP lease not expired

**Resolution:**
```bash
# 1. Verify MAC address
ip neigh show <device-ip>

# 2. Check reservation in config
grep -A 2 "<mac-address>" /etc/kea/kea-dhcp4.conf

# 3. Restart Kea
systemctl restart isc-kea-dhcp4-server

# 4. Force device to renew DHCP (reboot device)
```

### Reservation Conflicts

**Symptoms:**
- Same MAC has multiple reservations
- Same IP assigned to multiple MACs
- Devices getting wrong IPs

**Resolution:**
```bash
# Find duplicate MACs
cat /etc/kea/kea-dhcp4.conf | jq '.Dhcp4.subnet4[0].reservations | group_by(.["hw-address"]) | map(select(length > 1))'

# Find duplicate IPs
cat /etc/kea/kea-dhcp4.conf | jq '.Dhcp4.subnet4[0].reservations | group_by(.["ip-address"]) | map(select(length > 1))'

# Remove duplicates and restart Kea
```

---

## Maintenance

### Adding New Device Reservation

```bash
# 1. Get device MAC address
ping -c 1 <device-ip>
ip neigh show <device-ip>

# 2. Add reservation to both Kea servers
ssh root@192.168.1.133 "python3 << 'EOF'
import json, shutil
from datetime import datetime

# Backup
shutil.copy('/etc/kea/kea-dhcp4.conf',
            f'/etc/kea/kea-dhcp4.conf.backup-{datetime.now().strftime(\"%Y%m%d-%H%M%S\")}')

# Add reservation
with open('/etc/kea/kea-dhcp4.conf', 'r') as f:
    config = json.load(f)

config['Dhcp4']['subnet4'][0]['reservations'].append({
    'hw-address': 'aa:bb:cc:dd:ee:ff',
    'ip-address': '192.168.1.XXX',
    'hostname': 'device-name'
})

with open('/etc/kea/kea-dhcp4.conf', 'w') as f:
    json.dump(config, f, indent=2)

print('✅ Reservation added')
EOF
"

# 3. Repeat for second server (192.168.1.134)

# 4. Restart both Kea servers
ssh root@192.168.1.133 "systemctl restart isc-kea-dhcp4-server"
ssh root@192.168.1.134 "systemctl restart isc-kea-dhcp4-server"

# 5. Restart device or wait for DHCP renewal
```

### Removing Device Reservation

```bash
# 1. Remove from both Kea servers
ssh root@192.168.1.133 "python3 << 'EOF'
import json, shutil
from datetime import datetime

# Backup
shutil.copy('/etc/kea/kea-dhcp4.conf',
            f'/etc/kea/kea-dhcp4.conf.backup-{datetime.now().strftime(\"%Y%m%d-%H%M%S\")}')

# Remove reservation
with open('/etc/kea/kea-dhcp4.conf', 'r') as f:
    config = json.load(f)

reservations = config['Dhcp4']['subnet4'][0]['reservations']
reservations[:] = [r for r in reservations if r['hw-address'] != 'aa:bb:cc:dd:ee:ff']

with open('/etc/kea/kea-dhcp4.conf', 'w') as f:
    json.dump(config, f, indent=2)

print('✅ Reservation removed')
EOF
"

# 2. Restart Kea servers
```

### Updating Reservation IP

```bash
# Remove old and add new (same process as above)
# Or modify in place:
ssh root@192.168.1.133 "python3 << 'EOF'
import json, shutil
from datetime import datetime

shutil.copy('/etc/kea/kea-dhcp4.conf',
            f'/etc/kea/kea-dhcp4.conf.backup-{datetime.now().strftime(\"%Y%m%d-%H%M%S\")}')

with open('/etc/kea/kea-dhcp4.conf', 'r') as f:
    config = json.load(f)

for r in config['Dhcp4']['subnet4'][0]['reservations']:
    if r['hw-address'] == 'aa:bb:cc:dd:ee:ff':
        r['ip-address'] = '192.168.1.NEW'
        print(f'✅ Updated {r[\"hostname\"]} to {r[\"ip-address\"]}')

with open('/etc/kea/kea-dhcp4.conf', 'w') as f:
    json.dump(config, f, indent=2)
EOF
"
```

---

## Related Documentation

- **Omada Controller IPv6 Fix:** `docs/network/OMADA_CONTROLLER_IPV6_BINDING_FIX.md`
- **Traefik Omada Health Check Fix:** `docs/network/TRAEFIK_OMADA_HEALTHCHECK_FIX.md`
- **Kea DHCP Validation:** `docs/network/KEA_DHCP_VALIDATION_REPORT.md`
- **Kea IP Conflict Resolution:** `docs/network/KEA_IP_CONFLICT_RESOLVED.md`

---

## Summary

✅ **All Omada infrastructure devices configured**
✅ **DHCP reservations active on both Kea servers**
✅ **All devices online and adopted**
✅ **Total reservations: 54**
✅ **Network stable and ready for production**

**Next Steps:** None required - all infrastructure devices properly configured.

---

**Last Updated:** 2025-11-12 20:55 UTC
**Status:** ✅ Fully Configured
