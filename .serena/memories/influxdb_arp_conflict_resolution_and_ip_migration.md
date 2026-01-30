# InfluxDB ARP Conflict Resolution and IP Migration

## Issue Summary
Uptime Kuma was intermittently marking InfluxDB as down when it was actually running. The root cause was ARP cache poisoning due to IP address conflicts with multiple devices claiming the same IP addresses.

## Root Cause
1. **Initial Problem (192.168.1.56)**: 
   - InfluxDB LXC 100 configured for 192.168.1.56
   - Rogue MAC `ac:41:6a:47:2f:2a` (device at 192.168.1.60) was also claiming .56
   - This caused ARP cache conflicts preventing reliable connectivity

2. **Second Conflict (192.168.1.58)**:
   - Attempted to move InfluxDB to .58
   - Gateway device "gateway9f796a" (MAC: `00:d0:2d:9f:79:6a`) already had DHCP lease for .58
   - Gateway continued claiming .58 even after lease expired

3. **Final Solution (192.168.1.74)**:
   - Moved to truly free IP 192.168.1.74
   - Removed stale DHCP reservation that was preventing usage

## Current Configuration

### InfluxDB LXC 100
- **Location**: Proxmox2 (192.168.1.125)
- **IP Address**: 192.168.1.74
- **MAC Address**: bc:24:11:16:c6:92
- **Config File**: `/etc/pve/nodes/proxmox2/lxc/100.conf`
```
net0: name=eth0,bridge=vmbr0,gw=192.168.1.1,hwaddr=BC:24:11:16:C6:92,ip=192.168.1.74/24,type=veth
tags: 192.168.1.74;community-script;database
```

### Proxmox Metrics Configuration
- **File**: `/etc/pve/status.cfg` (on all nodes)
```
influxdb: InfluxDB
    port 8086
    server 192.168.1.74
    bucket Proxmox
    influxdbproto http
    organization lakehouse
    timeout 5
```

### Uptime Kuma Monitor
- **Container**: LXC 132 at 192.168.1.132
- **Database**: `/opt/uptime-kuma/data/kuma.db`
- **Monitor URL**: `http://192.168.1.74:8086/ping`
- Updated via SQL:
```sql
UPDATE monitor SET url = REPLACE(url, '192.168.1.58', '192.168.1.74') WHERE url LIKE '%192.168.1.58%';
```

### DHCP Reservation (Kea)
- **Server**: 192.168.1.133 (kea-dhcp-1)
- **Config**: `/etc/kea/kea-dhcp4.conf`
- **Reservation**:
```json
{
  "hw-address": "bc:24:11:16:c6:92",
  "ip-address": "192.168.1.74",
  "hostname": "influxdb"
}
```
- **Service**: `isc-kea-dhcp4-server`
- **Important**: Reservation must be in `reservations` section, NOT in `pools` section

### DNS Configuration
- **DNS Server**: AdGuard-2 at 192.168.1.224
- **Config**: `/opt/AdGuardHome/AdGuardHome.yaml`
- **Rewrite**: `influxdb.internal.lakehouse.wtf` → `192.168.1.110` (Traefik)
- This allows Grafana to use DNS name instead of IP
- Traefik handles routing to InfluxDB

### Gratuitous ARP
- **Script**: `/usr/local/bin/send-grat-arp.sh` (inside LXC 100)
```bash
#!/bin/bash
/usr/bin/arping -c 3 -A -I eth0 192.168.1.74 >/dev/null 2>&1
```
- **Service**: `/etc/systemd/system/grat-arp.service` - Runs on boot
- **Timer**: `/etc/systemd/system/grat-arp.timer` - Runs every 1 minute
- **Purpose**: Continuously announces correct MAC→IP mapping to prevent ARP poisoning

## Grafana Configuration
- **Container**: LXC 101 at 192.168.1.101
- **Database**: `/var/lib/grafana/grafana.db`
- **Data Source**: Uses DNS name `influxdb.internal.lakehouse.wtf`
- No IP update needed - works through Traefik reverse proxy

## Devices Involved in Conflicts

### Gateway Devices (Likely Zigbee/IoT gateways)
- `gateway9f796a` - MAC: `00:d0:2d:9f:79:6a` at 192.168.1.58 (old conflict)
- `gateway9f7ca1` - MAC: `00:d0:2d:9f:7c:a1` at 192.168.1.53
- `gateway9f7cb7` - MAC: `00:d0:2d:9f:7c:b7` at 192.168.1.59
- These devices had DHCP leases but continued using IPs after expiration

### Access Point
- `eap773-a8-29-48-c0-01-60` - MAC: `a8:29:48:c0:01:60`
- Had stale DHCP reservation for 192.168.1.74
- Actually uses static IP 192.168.1.234
- Stale reservation was removed to allow InfluxDB to use .74

## Troubleshooting Commands

### Check InfluxDB Health
```bash
curl -s http://192.168.1.74:8086/health
# Expected: {"status":"pass","message":"ready for queries and writes"}

curl -s http://192.168.1.74:8086/ping
# Expected: HTTP 204 No Content
```

### Check ARP Cache
```bash
# On Proxmox nodes
ip neigh show 192.168.1.74
# Should show MAC: bc:24:11:16:c6:92

# Flush ARP cache if needed
ip -s -s neigh flush 192.168.1.74
```

### Verify DNS Resolution
```bash
dig @192.168.1.224 influxdb.internal.lakehouse.wtf +short
# Should return: 192.168.1.110 (Traefik)
```

### Check DHCP Reservations
```bash
# On Kea server
grep -A 3 'bc:24:11:16:c6:92' /etc/kea/kea-dhcp4.conf
```

### Check Grafana Data Source
```bash
ssh root@192.168.1.101 "sqlite3 /var/lib/grafana/grafana.db \"SELECT name, url FROM data_source;\""
# Should show: influxdb.internal.lakehouse.wtf
```

### Restart Services
```bash
# InfluxDB (via LXC restart)
ssh root@192.168.1.125 "pct restart 100"

# Kea DHCP
ssh root@192.168.1.133 "systemctl restart isc-kea-dhcp4-server"

# AdGuard Home
ssh root@192.168.1.224 "systemctl restart AdGuardHome"
```

## Lessons Learned

1. **Always check for existing IP assignments** before changing an IP address
   - Check DHCP leases: `/opt/AdGuardHome/data/leases.json`
   - Check ARP cache: `ip neigh show`
   - Verify no device is responding on target IP

2. **ARP conflicts can cause intermittent issues** that are hard to diagnose
   - Symptoms: Service works locally but not remotely
   - ICMP works but TCP connections fail
   - Issues appear and disappear randomly

3. **Gratuitous ARP is essential** in environments with multiple devices
   - Helps prevent ARP poisoning
   - Should run periodically, not just on boot
   - Use systemd timer for reliability

4. **DHCP reservation location matters** in Kea configuration
   - Must be in `reservations` array within subnet
   - NOT in `pools` array
   - JSON validation is strict

5. **DNS rewriting for internal services** should point to reverse proxy
   - Allows SSL termination at proxy
   - Single point for routing rules
   - Easier certificate management

## Network Architecture

```
Client (Grafana/Uptime Kuma)
    ↓
DNS Query: influxdb.internal.lakehouse.wtf
    ↓
AdGuard-2 (192.168.1.224)
    ↓
Returns: 192.168.1.110 (Traefik)
    ↓
Traefik Reverse Proxy
    ↓
Routes to: 192.168.1.74:8086 (InfluxDB)
```

## Related Services

- **Proxmox Cluster**: 3 nodes (192.168.1.137, 192.168.1.125, 192.168.1.126)
- **InfluxDB**: LXC 100, HA-managed, stores Proxmox metrics
- **Grafana**: LXC 101, visualizes InfluxDB data
- **Uptime Kuma**: LXC 132, monitors service availability
- **Traefik**: 192.168.1.110, reverse proxy for all services
- **Kea DHCP**: 192.168.1.133 (primary), 192.168.1.134 (HA standby)
- **AdGuard-2**: 192.168.1.224, DNS server with custom rewrites

## Prevention Measures

1. **DHCP Reservations**: All static services have reservations in Kea
2. **Gratuitous ARP**: Critical services announce their IP regularly
3. **DNS Rewrites**: Internal services use DNS names, not IPs
4. **Documentation**: IP assignments tracked in multiple places
5. **Monitoring**: Uptime Kuma alerts on connectivity issues

## Future Improvements

1. Consider implementing DHCP snooping on network switches
2. Use VLAN segregation for IoT devices (gateways) 
3. Implement IP conflict detection/alerting
4. Regular audit of DHCP leases vs actual network usage
5. Consider static IPs for all infrastructure services
