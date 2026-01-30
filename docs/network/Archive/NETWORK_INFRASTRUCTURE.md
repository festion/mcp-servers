# Homelab Network Infrastructure Documentation

**Last Updated:** 2025-11-06
**Document Version:** 1.0
**Maintained By:** Network Infrastructure Team

---

## Table of Contents

1. [Network Overview](#network-overview)
2. [Network Topology](#network-topology)
3. [IP Address Scheme](#ip-address-scheme)
4. [Network Devices](#network-devices)
5. [VLAN Configuration](#vlan-configuration)
6. [Switch Configuration](#switch-configuration)
7. [Proxmox Cluster Configuration](#proxmox-cluster-configuration)
8. [Known Issues](#known-issues)
9. [Recent Changes](#recent-changes)
10. [Maintenance Procedures](#maintenance-procedures)

---

## Network Overview

### Network Summary
- **Primary Network:** 192.168.1.0/24
- **Gateway:** 192.168.1.1 (Firewalla)
- **DNS Servers:**
  - Primary: 192.168.1.253 (AdGuard Home - Primary)
  - Secondary: 192.168.1.224 (AdGuard Home - Secondary)
- **DHCP Servers:**
  - Primary: 192.168.1.133 (kea-dhcp-1)
  - Secondary: 192.168.1.134 (kea-dhcp-2)
- **NTP Server:** pool.ntp.org
- **Timezone:** UTC-06:00 (Central Time)

### Key Infrastructure Components
- **Core Switch:** TP-Link SG3218XP-M2
- **Network Controller:** Omada SDN Controller
- **Compute Cluster:** 3-node Proxmox VE cluster
- **Storage:** TrueNAS
- **Firewall:** Firewalla

---

## Network Topology

```
Internet
    |
[ISP Modem]
    |
[Firewalla GW] 192.168.1.1
    |
    ├─ Port 1 ──────────────────────────────┐
    |                                        |
[TP-Link SG3218XP-M2 Switch]                |
192.168.1.210                               |
    |                                        |
    ├─ Port 1: Firewalla (2.5G)            ←┘
    ├─ Port 2: Proxmox3 (2.5G) ────────┐
    ├─ Port 3: Linda Workstation (2.5G)|
    ├─ Port 4: Upstairs AP (2.5G)      |
    ├─ Port 5: TrueNAS (2.5G)          |  Proxmox
    ├─ Port 6: Proxmox2 (2.5G) ────────┤  HA Cluster
    ├─ Port 7: Proxmox (2.5G) ─────────┘  (Corosync)
    ├─ Port 8: Downstairs AP (2.5G)
    ├─ Port 9-14: Available (2.5G)
    ├─ Port 15: SLZB-06 Zigbee (100M)
    ├─ Port 16: E-eye Alarm (100M)
    ├─ Port 17: Available (10G SFP+)
    └─ Port 18: Available (10G SFP+)
         |
         ├─ Wireless APs
         │   ├─ EAP773 Upstairs (192.168.1.74)
         │   └─ EAP773 Downstairs (192.168.1.242)
         |
         └─ Management
             └─ Omada Controller (192.168.1.47 - LXC 111)
```

---

## IP Address Scheme

### Reserved Ranges
| Range | Purpose | Notes |
|-------|---------|-------|
| 192.168.1.1-10 | Network Infrastructure | Gateway, DNS, management |
| 192.168.1.11-50 | Servers & Core Services | Static assignments |
| 192.168.1.51-99 | IoT Devices | Static/DHCP reserved |
| 192.168.1.100-199 | Dynamic DHCP Pool | Workstations, devices |
| 192.168.1.200-250 | Network Equipment | Switches, APs, controllers |
| 192.168.1.251-254 | Infrastructure Services | DNS, DHCP, monitoring |

### Static IP Assignments

#### Core Infrastructure
| IP Address | Hostname | Device Type | MAC Address | Description |
|------------|----------|-------------|-------------|-------------|
| 192.168.1.1 | firewalla | Gateway/Firewall | - | Primary gateway and firewall |
| 192.168.1.47 | omada.internal.lakehouse.wtf | Omada Controller | - | TP-Link Omada SDN Controller (LXC 111 on Proxmox) |
| 192.168.1.74 | upstairs-ap | Access Point | - | EAP773 Upstairs AP |
| 192.168.1.110 | traefik.internal.lakehouse.wtf | Reverse Proxy | - | Traefik reverse proxy |
| 192.168.1.210 | SW-Main-SG3218XP | Managed Switch | EC-75-0C-A5-C1-9D | TP-Link SG3218XP-M2 main switch |
| 192.168.1.224 | adguard2.internal.lakehouse.wtf | DNS Server | - | AdGuard Home Secondary |
| 192.168.1.242 | downstairs-ap | Access Point | - | EAP773 Downstairs AP |
| 192.168.1.253 | adguard.internal.lakehouse.wtf | DNS Server | - | AdGuard Home Primary |

#### Proxmox Cluster
| IP Address | Hostname | Node ID | Role | Network Interface | Description |
|------------|----------|---------|------|-------------------|-------------|
| 192.168.1.137 | proxmox | 1 | Cluster Node | enx803f5dfcef74 (USB 2.5G) | Proxmox VE Host 1 |
| 192.168.1.125 | proxmox2 | 2 | Cluster Node | enxf44dad055788 (USB 2.5G) | Proxmox VE Host 2 ⚠️ |
| 192.168.1.126 | proxmox3 | 3 | Cluster Node | - | Proxmox VE Host 3 |

> ⚠️ **WARNING:** Proxmox2 is using USB Ethernet adapter. Built-in NIC (eno1) is DOWN.

#### DHCP Servers (Kea HA Pair)
| IP Address | Hostname | Role | Status |
|------------|----------|------|--------|
| 192.168.1.133 | kea-dhcp-1 | Primary | Active |
| 192.168.1.134 | kea-dhcp-2 | Secondary | Standby |

#### Storage
| IP Address | Hostname | Type | Description |
|------------|----------|------|-------------|
| 192.168.1.* | truenas | NAS | TrueNAS storage server |

#### IoT Devices
| IP Address | Hostname | Device Type | Description |
|------------|----------|-------------|-------------|
| 192.168.1.* | slzb-06 | Zigbee Coordinator | SLZB-06 Zigbee coordinator |
| 192.168.1.* | e-eye-alarm | Security System | E-eye alarm system |

---

## Network Devices

### Core Switch: TP-Link SG3218XP-M2

**Device Information:**
- **Model:** SG3218XP-M2 v1.0
- **Hardware Version:** SG3218XP-M2 1.0
- **Firmware Version:** 1.0.11 Build 20250428 Rel.61524
- **MAC Address:** EC-75-0C-A5-C1-9D
- **Serial Number:** Y24C0E2000082
- **IP Address:** 192.168.1.210/24
- **Management:** Omada SDN Controller
- **SSH Access:** Enabled (administrator/password)
- **Web Interface:** HTTPS on port 443
- **Uptime (as of 2025-11-06):** 1 day, 17 hours, 49 minutes

**Port Configuration:**
| Port | Description | Speed | Status | Device Connected | VLAN | PoE |
|------|-------------|-------|--------|------------------|------|-----|
| Tw1/0/1 | Firewalla | 2.5G | Up | Gateway/Firewall | 1 | No |
| Tw1/0/2 | Proxmox3 | 2.5G | Up | Proxmox Host 3 | 1 | No |
| Tw1/0/3 | Linda | 2.5G | Up | Workstation | 1 | No |
| Tw1/0/4 | UpstairsAP | 2.5G | Up | EAP773 AP | 1 | PoE+ |
| Tw1/0/5 | TrueNAS | 2.5G | Up | Storage Server | 1 | No |
| Tw1/0/6 | Proxmox2 | 2.5G | Up | Proxmox Host 2 ⚠️ | 1 | No |
| Tw1/0/7 | Proxmox | 2.5G | Up | Proxmox Host 1 | 1 | No |
| Tw1/0/8 | DownstairsAP | 2.5G | Up | EAP773 AP | 1 | PoE+ |
| Tw1/0/9 | Port9 | Auto | Down | Available | 1 | PoE+ |
| Tw1/0/10 | Port10 | Auto | Down | Available | 1 | PoE+ |
| Tw1/0/11 | Port11 | Auto | Down | Available | 1 | PoE+ |
| Tw1/0/12 | Port12 | Auto | Down | Available | 1 | PoE+ |
| Tw1/0/13 | Port13 | Auto | Down | Available | 1 | PoE+ |
| Tw1/0/14 | Port14 | Auto | Down | Available | 1 | PoE+ |
| Tw1/0/15 | SLZB-06 | 100M | Up | Zigbee Gateway | 1 | No |
| Tw1/0/16 | E-eye Alarm | 100M | Up | Security System | 1 | No |
| Te1/0/17 | Port17 | 10G | Down | Available (SFP+) | 1 | No |
| Te1/0/18 | Port18 | 10G | Down | Available (SFP+) | 1 | No |

**PoE Status:**
- **Total PoE Budget:** 240W
- **Current Usage:** 27.5W (11%)
- **Available:** 212.5W
- **PoE Enabled Ports:** 8 (Ports 1-8)

**Switch Features:**
- **Spanning Tree Protocol:** RSTP (Rapid Spanning Tree)
- **All ports in Forwarding state:** Yes
- **LAG Support:** 8 LAGs supported (currently unused)
- **LLDP:** Enabled
- **Flow Control:** Enabled on all active ports
- **Jumbo Frames:** 1518 bytes
- **Management VLAN:** VLAN 1

**STP Configuration:**
| Port | STP State | Role | Edge Port | P2P | Status |
|------|-----------|------|-----------|-----|--------|
| All Active Ports | Forwarding | Designated | Yes | Yes (auto) | Normal |

### Wireless Access Points

#### Upstairs AP (EAP773)
- **Model:** EAP773 v1.0
- **IP Address:** 192.168.1.74
- **Connected to:** Switch Port 4 (2.5G, PoE+)
- **Firmware:** 1.0.14
- **Management:** Omada Controller

#### Downstairs AP (EAP773)
- **Model:** EAP773 v1.0
- **IP Address:** 192.168.1.242
- **Connected to:** Switch Port 8 (2.5G, PoE+)
- **Firmware:** 1.0.14
- **Management:** Omada Controller

### Omada SDN Controller
- **Type:** Software Controller (LXC Container)
- **Host:** Proxmox Cluster (LXC 111)
- **IP Address:** 192.168.1.47
- **Access:** https://omada.internal.lakehouse.wtf:8043
- **Manages:** 1x Switch, 2x Access Points
- **MongoDB Port:** 27217 (internal)
- **Database:** MongoDB 7.0.25

---

## VLAN Configuration

### Current VLAN Setup

| VLAN ID | Name | Purpose | Ports | Subnet | Notes |
|---------|------|---------|-------|--------|-------|
| 1 | System-VLAN | Default/Management | All (Untagged) | 192.168.1.0/24 | Flat network - all traffic |

**Current State:** Flat network topology (single VLAN)

> ⚠️ **Recommendation:** Implement VLAN segmentation for improved security and traffic isolation. See [Optimization Recommendations](#optimization-recommendations) section.

---

## Switch Configuration

### Management Access

**SSH Configuration:**
```bash
# SSH is enabled
# Port: 22
# Protocol: SSH-2.0-TPSSH-1.0.0
# Layer 3 Access: Enabled (as of 2025-11-06)
# Username: administrator
# Authentication: Password
```

**SSH Connection:**
```bash
ssh administrator@192.168.1.210
# Or via hostname:
ssh administrator@SW-Main-SG3218XP.internal.lakehouse.wtf
```

**Legacy Cipher Requirements:**
For OpenSSH 7.0+, use these options:
```bash
ssh -o KexAlgorithms=+diffie-hellman-group1-sha1 \
    -o HostKeyAlgorithms=+ssh-rsa,ssh-dss \
    -o PubkeyAcceptedKeyTypes=+ssh-rsa,ssh-dss \
    administrator@192.168.1.210
```

### IP Configuration
- **Mode:** Static
- **IP:** 192.168.1.210
- **Netmask:** 255.255.255.0
- **Gateway:** 192.168.1.1
- **DNS:** 192.168.1.253

### System Settings
- **Hostname:** EC-75-0C-A5-C1-9D
- **System Time:** NTP synchronized
- **NTP Server:** pool.ntp.org
- **Timezone:** UTC-06:00
- **DST:** Enabled (Mar 9 - Nov 2, 2025)
- **Serial Port Baud Rate:** 38400

### Network Features
- **IGMP Snooping:** Enabled (VLAN 1)
- **MLD Snooping:** Enabled (IPv6)
- **DHCP L2 Relay:** Enabled on Port 12
- **LLDP:** Enabled globally, LLDP-MED enabled on all ports
- **IPv6 Routing:** Enabled
- **Telnet:** Disabled (SSH only)

---

## Proxmox Cluster Configuration

### Cluster Information

**Cluster Name:** homelab-cluster
**Cluster Version:** 3-node configuration
**Quorum:** 2/3 required
**Current Quorum Status:** ✅ Quorate (3/3 nodes online)

### Node Configuration

| Node ID | Hostname | IP Address | Votes | Status | Network Interface | Interface Type |
|---------|----------|------------|-------|--------|-------------------|----------------|
| 1 | proxmox | 192.168.1.137 | 1 | Online | enx803f5dfcef74 → vmbr0 | USB 2.5G Adapter ⚠️ |
| 2 | proxmox2 | 192.168.1.125 | 1 | Online | enxf44dad055788 → vmbr0 | USB 2.5G Adapter ⚠️ |
| 3 | proxmox3 | 192.168.1.126 | 1 | Online | (interface TBD) → vmbr0 | (TBD) |

> ⚠️ **CRITICAL:** Proxmox and Proxmox2 are using USB Ethernet adapters instead of built-in NICs. This can cause stability issues.

### Corosync Configuration

**Configuration File:** `/etc/corosync/corosync.conf`
**Config Version:** 6 (updated 2025-11-06)

```ini
totem {
  cluster_name: homelab-cluster
  config_version: 6
  interface {
    linknumber: 0
  }
  ip_version: ipv4-6
  link_mode: passive
  secauth: on
  version: 2

  # HA Tuning (Applied 2025-11-06)
  # Increased tolerance for brief network disruptions
  token: 10000                              # Default: 3000ms → 10000ms
  token_retransmits_before_loss_const: 20   # Default: 10 → 20
  consensus: 12000                          # Default: 3600ms → 12000ms
}
```

**Corosync Network:**
- **Transport:** knet (Kronosnet)
- **Protocol:** UDP multicast
- **Link 0:** 192.168.1.0/24 network
- **Redundant Links:** Not configured ⚠️

**HA Tuning Details:**
- **Token Timeout:** 10 seconds (increased from 3s)
- **Token Retransmits:** 20 attempts before declaring node lost (increased from 10)
- **Consensus Timeout:** 12 seconds (increased from 3.6s)
- **Purpose:** Prevent unnecessary failovers during brief network disruptions
- **Applied:** 2025-11-06 11:44 CST
- **Status:** ✅ Active on all nodes

### Network Configuration (Proxmox Node Example)

**Proxmox (192.168.1.137):**
```bash
auto lo
iface lo inet loopback

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.137/24
    gateway 192.168.1.1
    bridge-ports enx803f5dfcef74    # USB Ethernet
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

### High Availability Status
- **Watchdog:** Enabled on all nodes
- **Fencing:** Configured
- **Last Incident:** 2025-11-06 11:02 (Proxmox2 rebooted due to watchdog timeout)
- **Root Cause:** Network link failure on Port 6 (duration: ~8 minutes)

---

## Known Issues

### 🚨 Critical Issues

#### 1. Proxmox2 Using USB Ethernet Adapter
**Status:** 🔴 **CRITICAL - REQUIRES IMMEDIATE ATTENTION**
**Discovered:** 2025-11-06
**Impact:** Network instability, cluster communication failures

**Details:**
- Proxmox2 built-in NIC (eno1) is DOWN
- Currently using USB Ethernet adapter (enxf44dad055788)
- USB adapter shows "Speed: Unknown!" in ethtool
- Switch Port 6 experienced link down event at 10:53:51 on 2025-11-06

**Timeline of Related Events:**
```
2025-11-06 10:53:51 - Proxmox2 link went DOWN (Port Tw1/0/6)
2025-11-06 11:02:00 - HA Watchdog expired on Proxmox2
2025-11-06 11:02:01 - Proxmox2 forced reboot
2025-11-06 11:02:26 - Proxmox2 link down (rebooting)
2025-11-06 11:02:30 - Proxmox2 link restored
```

**Required Actions:**
1. Diagnose built-in NIC (eno1) failure on Proxmox2
2. Check for hardware fault or driver issues
3. Replace/repair NIC or move to high-quality PCIe 2.5G adapter
4. Test cable on switch Port 6
5. Monitor for recurring link instability

**Workaround:** Currently functional but unstable. Monitor closely.

#### 2. Proxmox Also Using USB Ethernet
**Status:** 🟡 **WARNING**
**Impact:** Potential single point of failure

**Details:**
- Proxmox (192.168.1.137) also using USB adapter (enx803f5dfcef74)
- Built-in NIC (enp1s0) appears available but not configured
- No recent stability issues reported

**Recommendation:** Migrate to built-in NIC or PCIe adapter for better reliability.

### 🟡 Medium Priority Issues

#### 3. Single Network Path for Cluster Communication
**Status:** 🟡 **WARNING**
**Impact:** No redundancy for cluster heartbeat

**Details:**
- Corosync using single network path (VLAN 1)
- Network disruption = cluster communication loss
- No redundant link configured

**Recommendation:**
- Implement VLAN 10 for dedicated Corosync traffic
- Configure dual Corosync links for redundancy

#### 4. Flat Network Topology (Single VLAN)
**Status:** 🟡 **WARNING**
**Impact:** Security, performance, troubleshooting

**Details:**
- All traffic on VLAN 1
- No network segmentation
- Broadcast domain includes all devices
- Management traffic shares bandwidth with VMs/LXCs

**Recommendation:** Implement VLAN segmentation strategy

#### 5. Omada Controller "ports or lags is null" Error
**Status:** 🟢 **MONITORING**
**Last Occurrence:** 2025-11-04 18:49:52
**Impact:** Logging noise, potential indicator of configuration sync issues

**Details:**
```
11-04-2025 18:49:52 - WARNING: Osw EC-75-0C-A5-C1-9D with omadac
f47ac8a84518c97c8acfd9c7edf32841 ports or lags is null
```

**Analysis:**
- Appears to be transient error during configuration sync
- Switch ports and LAGs are properly configured
- No functional impact observed
- May be related to Omada controller software

**Action:** Monitor for recurrence. No immediate action required.

### 🟢 Low Priority Issues

#### 6. No LACP/LAG Configuration
**Status:** 🟢 **ENHANCEMENT**
**Impact:** Missing performance optimization opportunity

**Details:**
- Switch supports 8 LAGs (currently unused)
- TrueNAS could benefit from LACP bonding
- Would provide bandwidth aggregation and failover

**Recommendation:** Configure LACP for TrueNAS (see optimization guide)

---

## Recent Changes

### 2025-11-06 - Corosync HA Tuning
**Time:** 11:44 CST
**Changed By:** Network Administrator
**Scope:** All Proxmox cluster nodes

**Changes Made:**
1. Backed up `/etc/corosync/corosync.conf` on all nodes
2. Updated Corosync totem settings:
   - `token: 3000 → 10000` (10 seconds)
   - `token_retransmits_before_loss_const: 10 → 20`
   - `consensus: 3600 → 12000` (12 seconds)
   - `config_version: 5 → 6`
3. Reloaded Corosync on all nodes: `corosync-cfgtool -R`
4. Verified cluster health

**Reason:** Prevent unnecessary reboots from brief network disruptions

**Testing:** Cluster remained quorate during reload. No service interruption.

**Backup Location:** `/etc/corosync/corosync.conf.backup-20251106-114443`

### 2025-11-06 - Switch SSH Layer 3 Access Enabled
**Time:** 12:30 CST
**Changed By:** Network Administrator

**Changes Made:**
- Enabled Layer 3 SSH access on switch
- Removed `ip ssh block-l3` restriction
- Verified SSH connectivity from management workstation

**Reason:** Enable remote management and troubleshooting

### 2025-11-06 - Omada Configuration Sync
**Time:** 11:40:03-11:40:10
**Type:** Automatic (Omada Controller)

**Events:**
- All ports briefly went down/up
- Configuration pushed from Omada Controller
- LLDP, STP, DHCP L2 Relay, and port settings synchronized
- All ports returned to forwarding state

**Impact:** Brief network disruption (~7 seconds)

---

## Maintenance Procedures

### Regular Maintenance Tasks

#### Daily
- [ ] Monitor Proxmox cluster quorum status
- [ ] Check for Corosync errors in logs
- [ ] Verify all critical services are running

#### Weekly
- [ ] Review switch logs for errors
- [ ] Check PoE power consumption trends
- [ ] Verify backup completion on all nodes
- [ ] Review network traffic patterns

#### Monthly
- [ ] Firmware update check (switch, APs)
- [ ] Review and clean up unused VMs/LXCs
- [ ] Test failover scenarios
- [ ] Update network documentation
- [ ] Review security logs

#### Quarterly
- [ ] Physical inspection of network cables
- [ ] Clean switch and server air intake
- [ ] Test disaster recovery procedures
- [ ] Audit user access and credentials

### Emergency Procedures

#### Cluster Node Failure
```bash
# Check cluster status
pvecm status

# Check which node is missing
pvecm nodes

# If quorum lost and only 1 node available:
pvecm expected 1

# After recovery, restore normal quorum:
pvecm expected 2
```

#### Switch Failure
1. If switch fails, all network services will be down
2. Connect directly to affected devices if possible
3. Check switch power and physical connections
4. Access via console cable if network down
5. Check Omada Controller for device status

#### Network Troubleshooting Commands

**Proxmox Corosync:**
```bash
# Check cluster status
pvecm status

# Check Corosync runtime status
corosync-cfgtool -s

# Check ring status
corosync-cfgtool -R

# View Corosync logs
journalctl -u corosync -f

# Check which nodes can communicate
pvecm nodes
```

**Switch Diagnostics:**
```bash
# SSH to switch
ssh administrator@192.168.1.210

# Enable privileged mode
enable

# Show system info
show system-info

# Show interface status
show interface status

# Show STP status
show spanning-tree interface

# Show recent logs
show logging

# Show port statistics (if supported)
show interface counters
```

**Network Testing:**
```bash
# Ping test
ping -c 5 192.168.1.210

# Trace route
traceroute 192.168.1.210

# Check link speed
ethtool eth0

# Monitor traffic
tcpdump -i vmbr0 host 192.168.1.125

# Test DNS resolution
nslookup proxmox2.internal.lakehouse.wtf
```

### Backup Procedures

#### Switch Configuration Backup
```bash
# Download configuration from Omada Controller
# Settings → Maintenance → Backup & Restore → Backup

# CLI backup via SSH (if supported)
ssh administrator@192.168.1.210 "show running-config" > switch-config-backup-$(date +%Y%m%d).txt
```

#### Corosync Configuration Backup
```bash
# On each Proxmox node:
cp /etc/corosync/corosync.conf /etc/corosync/corosync.conf.backup-$(date +%Y%m%d-%H%M%S)

# Centralized backup
for node in proxmox proxmox2 proxmox3; do
    scp root@$node:/etc/corosync/corosync.conf ./corosync-${node}-$(date +%Y%m%d).conf
done
```

---

## Optimization Recommendations

See separate document: [NETWORK_OPTIMIZATION_PLAN.md](./NETWORK_OPTIMIZATION_PLAN.md)

**Quick Summary:**
1. 🚨 **Critical:** Fix Proxmox2 NIC issue (USB → built-in)
2. 🚨 **High:** Implement dedicated Corosync VLAN
3. 🚨 **High:** Configure redundant Corosync links
4. 🟡 **Medium:** Implement VLAN segmentation
5. 🟡 **Medium:** Configure LACP for TrueNAS
6. 🟢 **Low:** Set up network monitoring (SNMP)

---

## Appendix

### Switch CLI Quick Reference

```bash
# Connect to switch
ssh administrator@192.168.1.210

# Enter privileged mode
enable

# Common show commands
show system-info
show interface status
show vlan brief
show spanning-tree interface
show power inline
show logging

# Exit
exit
```

### Proxmox Cluster CLI Quick Reference

```bash
# Cluster status
pvecm status
pvecm nodes

# Corosync status
corosync-cfgtool -s
corosync-cfgtool -R

# Network interface status
ip -br addr
ip -s link

# Check link speed
ethtool <interface>

# Cluster logs
journalctl -u pve-ha-crm -f
journalctl -u corosync -f
```

### Port Descriptions Reference

| Port | Switch Interface | Description | Device Type |
|------|------------------|-------------|-------------|
| 1 | Tw1/0/1 | Firewalla | Gateway/Firewall |
| 2 | Tw1/0/2 | Proxmox3 | Hypervisor Node |
| 3 | Tw1/0/3 | Linda | Workstation |
| 4 | Tw1/0/4 | UpstairsAP | Wireless AP (PoE+) |
| 5 | Tw1/0/5 | TrueNAS | NAS Storage |
| 6 | Tw1/0/6 | Proxmox2 | Hypervisor Node ⚠️ |
| 7 | Tw1/0/7 | Proxmox | Hypervisor Node |
| 8 | Tw1/0/8 | DownstairsAP | Wireless AP (PoE+) |
| 9-14 | Tw1/0/9-14 | Available | PoE+ Capable |
| 15 | Tw1/0/15 | SLZB-06 | Zigbee Gateway |
| 16 | Tw1/0/16 | E-eye Alarm | Security System |
| 17-18 | Te1/0/17-18 | Available | 10G SFP+ |

---

## Document Control

**Document History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-06 | System Administrator | Initial comprehensive documentation |

**Related Documents:**
- [NETWORK_OPTIMIZATION_PLAN.md](./NETWORK_OPTIMIZATION_PLAN.md)
- [INCIDENT_REPORTS.md](./INCIDENT_REPORTS.md)
- [VLAN_IMPLEMENTATION_GUIDE.md](./VLAN_IMPLEMENTATION_GUIDE.md) (To be created)

**Review Schedule:**
- Review frequency: Monthly
- Next review due: 2025-12-06
- Owner: Network Infrastructure Team

---

*This document is maintained as part of the homelab infrastructure documentation.*
*For questions or updates, please contact the network administrator.*
