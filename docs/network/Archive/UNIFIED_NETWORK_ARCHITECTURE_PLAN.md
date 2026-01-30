# Unified Network Architecture and Modernization Plan

**Version:** 2.0
**Created:** 2025-11-06
**Status:** Comprehensive Design Document
**Target Completion:** Q1 2026

---

## Executive Summary

This document combines two complementary network modernization strategies into a unified architecture that addresses both infrastructure reliability (Proxmox cluster) and client segmentation (home network). The design leverages the **Firewalla Gold (FWG)** as the primary Layer 3 firewall and router, transitioning from a flat 192.168.1.0/24 topology to a high-performance, segmented architecture.

### Key Objectives

1. **Infrastructure Resilience:** Fix critical Proxmox cluster stability issues and implement redundant communication paths
2. **Client Segmentation:** Isolate IoT devices, create dedicated user domains, and implement granular security controls
3. **Performance Optimization:** Maximize throughput from dual WAN links (Spectrum 1GB + Frontier Fiber 2.0Gbps) and Wi-Fi 7 access points
4. **Security Enhancement:** Implement defense-in-depth with VLAN isolation and firewall policies
5. **Future-Proofing:** Design for scalability and 10G expansion

### Architecture Overview

**Core Components:**
- **Firewalla Gold (FWG):** Primary L3 router, dual-WAN gateway, firewall, and DHCP server
- **TP-Link SG3218XP-M2:** Managed L2+ switch for VLAN aggregation
- **TP-Link EAP773 (×2):** Wi-Fi 7 access points with Multi-SSID to VLAN mapping
- **Proxmox VE Cluster:** 3-node HA cluster requiring dedicated cluster network
- **TrueNAS:** Storage server requiring high-bandwidth isolated network
- **Omada Controller (LXC 111):** Centralized management for switch and APs

**Current State Issues:**
- 🔴 Proxmox2 using unreliable USB Ethernet adapter (caused cluster reboot on 2025-11-06)
- 🔴 Single flat network with no segmentation or isolation
- 🔴 No redundancy for cluster communication
- 🟡 No multi-WAN optimization for 2.0Gbps Frontier Fiber link
- 🟡 Wi-Fi 7 APs deployed but not using VLAN segmentation

---

## Part 1: Foundational Layer 3 Design (Firewalla Gold Configuration)

### 1.1 Firewalla Gold Operating Mode

The FWG **must** be configured in **Router Mode** to enable:
- VLAN implementation and inter-VLAN routing
- Multi-WAN support for dual ISP connections
- Policy-based routing (PBR)
- Advanced firewall ACLs

### 1.2 Physical Port Assignments

| FWG Port | Assignment | Connection | VLAN Configuration |
|----------|------------|------------|-------------------|
| Port 4 | WAN 1 | Spectrum 1 GB Cable Modem | N/A (WAN) |
| Port 3 | WAN 2 | Frontier Fiber 2.0 Gbps ONT | N/A (WAN) |
| Port 1 | LAN Trunk | SG3218-M2 Port 1 | Native: VLAN 1, Tagged: All |
| Port 2 | Reserved | Future expansion | N/A |

### 1.3 Multi-WAN Strategy and Policy-Based Routing

**Load Balancing Configuration:**

Due to the bandwidth differential (1 GB vs. 2.0 Gbps), simple round-robin is inefficient. Implement **Policy-Based Routing (PBR)**:

**Primary WAN (Frontier Fiber 2.0 Gbps):**
- All high-bandwidth traffic (4K/8K streaming, large file transfers, VM downloads)
- Proxmox updates and ISO downloads
- TrueNAS backup operations
- Default route for all VLANs unless specified

**Secondary WAN (Spectrum 1 GB):**
- Primary function: Automatic failover for high availability
- Secondary function: Latency-sensitive applications (VoIP, gaming on daughter's network)
- Specific VLAN 30 traffic if needed for QoS

**FWG Configuration Steps:**
1. Navigate to Network Manager → WAN
2. Configure WAN 1 (Spectrum) and WAN 2 (Frontier Fiber)
3. Enable WAN Monitoring for both connections (ping test to 1.1.1.1 and 8.8.8.8)
4. Set default route to WAN 2 (Frontier Fiber)
5. Create PBR rules for specific traffic types or VLANs as needed

### 1.4 Unified VLAN and IP Subnet Scheme

The unified architecture uses two addressing schemes:
- **Client Networks:** 192.168.x.0/24 (for user-facing devices and compatibility)
- **Infrastructure Networks:** 10.10.x.0/24 (for backend systems and services)

| VLAN ID | Network Name | Purpose | CIDR/Subnet | FWG Gateway | DHCP Range | Notes |
|---------|--------------|---------|-------------|-------------|------------|-------|
| **1** | Management (Native) | Switch, APs, Omada, FWG mgmt | 192.168.1.0/24 | 192.168.1.1 | .100-.199 | Untagged on all trunks |
| **5** | Corosync Cluster | Proxmox HA heartbeat | 10.10.5.0/24 | None | N/A (static) | **No inter-VLAN routing** |
| **10** | Main LAN | Trusted endpoints (PCs, phones) | 192.168.10.0/24 | 192.168.10.1 | .100-.199 | Full access |
| **20** | IoT Network | Untrusted devices (cameras, sensors) | 192.168.20.0/24 | 192.168.20.1 | .100-.199 | Isolated from LAN |
| **25** | Hypervisor Mgmt | Proxmox node management IPs | 10.10.25.0/24 | 10.10.25.1 | N/A (static) | Admin access only |
| **30** | Daughter's Domain | Dedicated private network | 192.168.30.0/24 | 192.168.30.1 | .100-.199 | Parental controls |
| **35** | VMs-Trusted | Production VMs/LXCs | 10.10.35.0/24 | 10.10.35.1 | .100-.199 | App servers |
| **40** | Storage Network | TrueNAS, iSCSI, NFS, SMB | 10.10.40.0/24 | 10.10.40.1 | N/A (static) | Jumbo frames |
| **99** | Guest WiFi | Guest internet access | 192.168.99.0/24 | 192.168.99.1 | .10-.250 | Internet only |

**Critical Design Decisions:**

1. **VLAN 1 as Native VLAN:**
   - Untagged traffic on trunk links carries management network (192.168.1.0/24)
   - Ensures SG3218-M2 (192.168.1.210) and EAP773 management interfaces can communicate with FWG
   - Simplifies device adoption and management

2. **VLAN 5 (Corosync) Isolation:**
   - **No Layer 3 routing configured** - this is a completely isolated L2 domain
   - Prevents routing loops and ensures cluster traffic stays on dedicated path
   - Only Proxmox nodes have interfaces on this VLAN

3. **Dual Addressing Schemes:**
   - 192.168.x.0/24: Familiar, user-friendly, device compatibility
   - 10.10.x.0/24: Clear separation of infrastructure from clients

### 1.5 Firewalla Network Manager Configuration

**VLAN Interface Creation:**

Using the FWG web interface (https://my.firewalla.com) or mobile app:

```
1. Network Manager → Create Network → VLAN Network
2. For each VLAN (1, 10, 20, 25, 30, 35, 40, 99):
   - Name: [Network Name from table]
   - VLAN ID: [ID from table]
   - IP Range: [CIDR from table]
   - Gateway: [FWG Gateway from table]
   - DHCP Server: Enabled (except VLAN 5, 25, 40 - static only)
   - DNS: FWG forwards to upstream (1.1.1.1, 8.8.8.8)

3. Special Configuration for VLAN 5 (Corosync):
   - Create VLAN interface in Network Manager
   - IP Range: 10.10.5.0/24
   - DHCP Server: DISABLED
   - Inter-VLAN Routing: DISABLED (critical!)
   - Purpose: L2 connectivity only
```

**Trunk Port Configuration:**

```
1. Network Manager → Network Settings → Port Configuration
2. Configure Port 1 (Trunk to SG3218-M2):
   - Mode: VLAN Trunk
   - Native VLAN: 1 (untagged)
   - Tagged VLANs: 5, 10, 20, 25, 30, 35, 40, 99
   - Allow All VLANs: Enabled
```

---

## Part 2: Layer 2 Implementation (SG3218-M2 Switch Configuration)

### 2.1 Switch Management and Omada Integration

**Current Configuration:**
- Management IP: 192.168.1.210
- Omada Controller: 192.168.1.47:8043 (LXC 111)
- Model: SG3218XP-M2 (16× 1GbE PoE+ ports, 2× 10G SFP+ ports)
- PoE Budget: 240W total, currently using 27.5W

**Recommended Approach:** Use Omada Controller for centralized management of both SG3218-M2 and EAP773 APs.

### 2.2 VLAN Definition and 802.1Q Configuration

**Via Omada Controller:**
```
1. Login to https://192.168.1.47:8043
2. Navigate to Settings → Wired Networks → LAN Networks
3. Create all VLAN networks:
   - Click "Create New LAN"
   - For each VLAN:
     * Name: [Network Name]
     * VLAN ID: [ID]
     * Gateway/Subnet: [As defined in table]
     * DHCP Mode: Relay to Firewalla (192.168.1.1)
     * Purpose: [Purpose from table]
4. Apply to Site
```

**Via CLI (Alternative):**
```bash
ssh administrator@192.168.1.210
enable
configure
vlan 1
  name "Management"
vlan 5
  name "Corosync"
vlan 10
  name "Main-LAN"
vlan 20
  name "IoT"
vlan 25
  name "Hypervisor"
vlan 30
  name "Daughter"
vlan 35
  name "VMs"
vlan 40
  name "Storage"
vlan 99
  name "Guest"
exit
write memory
```

### 2.3 Port Profile Configuration Matrix

**Complete SG3218-M2 Port Assignment:**

| Port | Device Connected | Mode | PVID | Tagged VLANs | Speed | PoE | Notes |
|------|------------------|------|------|--------------|-------|-----|-------|
| **1** | Firewalla Gold Port 1 | Trunk | 1 | 5,10,20,25,30,35,40,99 | 1G | No | L3 Gateway Uplink |
| **2** | Proxmox (192.168.1.137) | Trunk | 1 | 5,25,40 | 1G | No | Cluster + Storage |
| **3** | Workstation | Access | 10 | None | 1G | No | Admin workstation |
| **4** | EAP773 Upstairs | Trunk | 1 | 10,20,30,99 | 1G | 802.3bt | Multi-SSID AP |
| **5** | TrueNAS Link 1 | Access | 40 | None | 1G | No | Storage (will become LAG1) |
| **6** | Proxmox2 (192.168.1.125) | Trunk | 1 | 5,25,40 | 1G | No | **Fix NIC first!** |
| **7** | Proxmox3 (192.168.1.126) | Trunk | 1 | 5,25,40 | 1G | No | Cluster + Storage |
| **8** | EAP773 Downstairs | Trunk | 1 | 10,20,30,99 | 1G | 802.3bt | Multi-SSID AP |
| **9** | TrueNAS Link 2 | Access | 40 | None | 1G | No | Future LAG1 member |
| **10** | SLZB-06 Zigbee | Access | 20 | None | 100M | Yes | IoT device |
| **11** | E-eye Alarm | Access | 20 | None | 100M | No | IoT device |
| **12** | Available | - | 1 | - | 1G | Yes | - |
| **13** | Available | - | 1 | - | 1G | Yes | - |
| **14** | Available | - | 1 | - | 1G | Yes | - |
| **15** | Omada Controller (LXC 111) | Access | 1 | None | 1G | No | Management |
| **16** | Available | - | 1 | - | 1G | Yes | - |
| **17** | SFP+ 10G Port | - | - | - | 10G | No | Future expansion |
| **18** | SFP+ 10G Port | - | - | - | 10G | No | Future expansion |

**Configuration Commands (per port):**

```bash
# Example: Port 2 (Proxmox - Trunk with Corosync + Hypervisor + Storage)
interface GigabitEthernet 1/0/2
  description "Proxmox Node 1"
  switchport mode trunk
  switchport trunk native vlan 1
  switchport trunk allowed vlan 1,5,25,40
  spanning-tree portfast trunk

# Example: Port 4 (EAP773 - Trunk with Client VLANs)
interface GigabitEthernet 1/0/4
  description "EAP773 Upstairs AP"
  switchport mode trunk
  switchport trunk native vlan 1
  switchport trunk allowed vlan 1,10,20,30,99
  power inline enable
  power inline priority high

# Example: Port 5 (TrueNAS - Access on Storage VLAN)
interface GigabitEthernet 1/0/5
  description "TrueNAS Storage Link 1"
  switchport mode access
  switchport access vlan 40
  spanning-tree portfast
```

### 2.4 Critical Switch Settings

**IGMP Snooping:**
```
⚠️ IMPORTANT: Disable IGMP Snooping to ensure FWG mDNS relay works correctly

Via Omada Controller:
Settings → Services → IGMP Snooping → Disable

Via CLI:
configure
no ip igmp snooping
exit
write memory
```

**Spanning Tree Protocol:**
```
# Verify STP configuration
show spanning-tree summary

# Should show:
# - RSTP enabled
# - All client ports with PortFast enabled
# - No ports in Blocking state
```

**Storm Control (Recommended):**
```
# Prevent broadcast storms on access ports
interface range GigabitEthernet 1/0/3, GigabitEthernet 1/0/5, GigabitEthernet 1/0/10-11
  storm-control broadcast level 10
  storm-control multicast level 10
```

---

## Part 3: Wireless Infrastructure (EAP773 Access Points)

### 3.1 EAP773 Specifications and Capabilities

**Performance:**
- Tri-Band Wi-Fi 7 (BE10000)
- 2.4 GHz: 688 Mbps
- 5 GHz: 2882 Mbps
- 6 GHz: 5760 Mbps
- **Total: 10,080 Mbps aggregate**

**Power Requirements:**
- 802.3bt (PoE++) required
- Maximum draw: 24.05W
- Required for full 6 GHz band operation

**Connectivity:**
- 1× 2.5 Gbps PoE+ port (can use 1G with reduced performance)
- VLAN 802.1Q trunk support
- Multi-SSID (up to 8 SSIDs per radio)

### 3.2 Multi-SSID to VLAN Mapping

**Configuration via Omada Controller:**

```
1. Navigate to Settings → Wireless Networks → WiFi
2. Create SSIDs with VLAN mapping:

SSID Configuration:
┌─────────────────────────────────────────────────────────────────┐
│ SSID Name          │ VLAN │ Security      │ Bands      │ Purpose│
├────────────────────┼──────┼───────────────┼────────────┼────────│
│ Lakehouse          │  10  │ WPA3/WPA2-PSK │ 2.4/5/6GHz │ Main   │
│ Lakehouse-IoT      │  20  │ WPA2-PSK      │ 2.4/5GHz   │ IoT    │
│ Lakehouse-Daughter │  30  │ WPA3/WPA2-PSK │ 2.4/5/6GHz │ User   │
│ Lakehouse-Guest    │  99  │ WPA2-PSK      │ 2.4/5GHz   │ Guest  │
│ Lakehouse-Mgmt     │  1   │ WPA3-Enterprise│2.4/5GHz   │ Admin  │
└────────────────────┴──────┴───────────────┴────────────┴────────┘

3. For each SSID:
   - Name: [As above]
   - Security: [As above]
   - Password: [Secure password]
   - VLAN: [ID from table]
   - Band Steering: Enabled (except IoT - 2.4GHz preferred)
   - Fast Roaming: Enabled
   - SSID to VLAN Mapping: Enabled

4. Apply to both EAP773 APs
```

**Security Best Practices:**
- **Main LAN (VLAN 10):** WPA3-SAE with WPA2-PSK fallback
- **IoT (VLAN 20):** WPA2-PSK only (many IoT devices don't support WPA3)
- **Daughter (VLAN 30):** WPA3-SAE for modern devices
- **Guest (VLAN 99):** WPA2-PSK with guest portal (optional)
- **Management (VLAN 1):** WPA3-Enterprise with RADIUS (optional, high security)

### 3.3 EAP Management Interface Configuration

**Important:** EAP773 management traffic must be on **VLAN 1** (Native/Untagged):

```
Via Omada Controller:
1. Devices → Select EAP773
2. Config → Management VLAN: 1
3. IP Address: DHCP (will receive 192.168.1.x)
4. DNS: 192.168.1.1 (Firewalla)
```

This ensures:
- APs can communicate with Omada Controller (192.168.1.47)
- Firmware updates work correctly
- Configuration changes propagate properly

---

## Part 4: Security Policy Implementation (Firewalla ACLs)

### 4.1 Firewall Philosophy

**Default-Deny Strategy:**
- All inter-VLAN traffic **blocked by default**
- Explicit allow rules for required communication
- Stateful firewall automatically permits return traffic
- Logging enabled for blocked attempts

### 4.2 Detailed Firewall Rule Matrix

**Rule Priority Order (Top to Bottom):**

| # | Source VLAN | Dest VLAN | Protocol/Port | Action | Purpose | Logging |
|---|-------------|-----------|---------------|--------|---------|---------|
| **Management Access** |
| 1 | Management (1) | ALL | ALL | ALLOW | Admin full access | Yes |
| 2 | Main LAN (10) | Management (1) | HTTPS/443, SSH/22 | ALLOW | Admin from workstation | Yes |
| **Infrastructure Communication** |
| 3 | Hypervisor (25) | Storage (40) | NFS/2049, iSCSI/3260, SMB/445 | ALLOW | Storage access | No |
| 4 | VMs-Trusted (35) | Storage (40) | NFS/2049, SMB/445 | ALLOW | App data storage | No |
| 5 | Hypervisor (25) | VMs-Trusted (35) | ALL | ALLOW | VM management | No |
| **IoT Isolation and Control** |
| 6 | Main LAN (10) | IoT (20) | HTTP/80, HTTPS/443, MQTT/1883 | ALLOW | Control IoT devices | No |
| 7 | IoT (20) | VMs-Trusted (35) | MQTT/1883, HTTP/80, HTTPS/443 | ALLOW | Home Assistant access | No |
| 8 | IoT (20) | Main LAN (10) | ALL | **DENY** | Prevent lateral movement | **Yes** |
| 9 | IoT (20) | Storage (40) | ALL | **DENY** | Protect storage | **Yes** |
| 10 | IoT (20) | Hypervisor (25) | ALL | **DENY** | Protect infrastructure | **Yes** |
| 11 | IoT (20) | Internet | HTTP/80, HTTPS/443, DNS/53 | ALLOW | Cloud services | No |
| **Daughter's Domain** |
| 12 | Daughter (30) | Main LAN (10) | ALL | **DENY** | User isolation | Yes |
| 13 | Daughter (30) | IoT (20) | ALL | **DENY** | User isolation | Yes |
| 14 | Daughter (30) | Internet | ALL | ALLOW | Internet access | No |
| **Guest Network** |
| 15 | Guest (99) | ALL Local | ALL | **DENY** | Complete isolation | Yes |
| 16 | Guest (99) | Internet | HTTP/80, HTTPS/443, DNS/53 | ALLOW | Internet only | No |
| **Corosync Isolation** |
| 17 | Corosync (5) | ALL | ALL | **NO ROUTE** | L2 only, no routing | N/A |
| 18 | ALL | Corosync (5) | ALL | **NO ROUTE** | L2 only, no routing | N/A |
| **Default Deny** |
| 99 | ALL | ALL | ALL | **DENY** | Catch-all security | **Yes** |

### 4.3 Firewalla Rule Implementation

**Via Firewalla Web Interface:**

```
1. Navigate to Rules → Access Control

2. For each rule above:
   - Click "Add Rule"
   - Name: [Descriptive name, e.g., "Allow Hypervisor to Storage"]
   - Type: Access Control
   - Direction: LAN to LAN (for inter-VLAN)
   - Source: [Source Network/VLAN]
   - Destination: [Dest Network/VLAN]
   - Protocol: [TCP/UDP/ALL]
   - Port: [Specific ports or Any]
   - Action: [Allow/Block/Reject]
   - Logging: [Enable for DENY rules]
   - Schedule: Always
   - Tags: [Optional categorization]

3. Order rules by priority (drag to reorder)

4. Enable rules and test
```

**Example: IoT Isolation (Critical Rules)**

```
Rule: "IoT to LAN - DENY"
├─ Source: IoT Network (192.168.20.0/24)
├─ Destination: Main LAN (192.168.10.0/24)
├─ Protocol: All
├─ Action: Block
├─ Logging: Enabled
└─ Priority: High

Rule: "LAN to IoT Control - ALLOW"
├─ Source: Main LAN (192.168.10.0/24)
├─ Destination: IoT Network (192.168.20.0/24)
├─ Protocol: TCP
├─ Ports: 80, 443, 1883 (MQTT)
├─ Action: Allow
├─ Logging: Disabled
└─ Priority: Higher (above deny rule)
```

### 4.4 Parental Controls for VLAN 30 (Daughter's Domain)

**Firewalla Family Protect Features:**

```
1. Navigate to Family → Create Profile
2. Profile Name: "Daughter's Network"
3. Apply to: Network 192.168.30.0/24 (entire VLAN)
4. Configure:
   ┌────────────────────────────────────────┐
   │ Safe Search: Enforced                  │
   │ Adult Content: Blocked                 │
   │ Violence/Weapons: Blocked              │
   │ Social Media: Allowed (with schedule)  │
   │ Gaming: Allowed (with schedule)        │
   │ Schedule:                              │
   │   - Weekdays: 6 PM - 10 PM            │
   │   - Weekends: 9 AM - 11 PM            │
   │ Pause Internet: Available             │
   │ Activity Monitoring: Enabled           │
   └────────────────────────────────────────┘
5. Save and apply
```

**Recommended Option:** Keep FWG as L3 gateway for VLAN 30 (Option A) to maintain visibility and control.

**Why NOT Double NAT (Option B):**
- Loses per-device visibility
- Parental controls cannot be applied to individual devices
- Gaming/VoIP issues with double NAT
- Troubleshooting becomes complex

---

## Part 5: Advanced Features and Service Discovery

### 5.1 mDNS Relay Configuration (Firewalla)

**Purpose:** Allow devices on Main LAN (VLAN 10) to discover services on IoT network (VLAN 20)
- AirPlay to Apple TV on VLAN 20
- Chromecast discovery
- HomeKit devices
- Printer discovery

**Configuration:**

```
1. Firewalla App/Web → Settings → Advanced
2. mDNS Reflector (now called "Service Discovery")
3. Enable for networks:
   - Main LAN (VLAN 10) ✓
   - IoT Network (VLAN 20) ✓
   - VMs-Trusted (VLAN 35) ✓ (if Home Assistant is here)
4. Verify multicast forwarding:
   - 224.0.0.251 (mDNS)
   - 239.255.255.250 (SSDP)
```

**Testing:**
```bash
# From Main LAN device:
dns-sd -B _airplay._tcp

# Should discover AirPlay devices on VLAN 20
# Even though firewall blocks IoT → LAN, mDNS relay allows discovery
```

### 5.2 IGMP Snooping and Multicast Handling

**Critical Conflict Resolution:**

FWG mDNS Relay requires receiving multicast packets, but IGMP Snooping on SG3218-M2 can filter them.

**Recommended Solution:**
```bash
# Disable IGMP Snooping on SG3218-M2
ssh administrator@192.168.1.210
enable
configure
no ip igmp snooping
exit
write memory
```

**Alternative (Advanced - Not Recommended for Home):**
```
If IGMP Snooping must stay enabled (e.g., IPTV service):
1. Configure FWG as IGMP Querier
2. Ensure switch forwards IGMP queries to all ports
3. Test extensively - high complexity
```

### 5.3 QoS and Traffic Prioritization

**Firewalla QoS Configuration:**

```
1. Navigate to Settings → QoS
2. Enable Smart Queue Management
3. Configure WAN speeds:
   - WAN 1 (Spectrum): 950 Mbps down / 40 Mbps up
   - WAN 2 (Frontier): 2000 Mbps down / 2000 Mbps up
4. Priority Classes:
   ┌─────────────────────────────────────────────┐
   │ Class      │ Examples           │ % Bandwidth│
   ├────────────┼────────────────────┼────────────│
   │ Critical   │ VoIP, Video Calls  │ 20%        │
   │ High       │ Gaming (VLAN 30)   │ 15%        │
   │ Medium     │ Web, Email         │ 40%        │
   │ Low        │ File Downloads     │ 20%        │
   │ Bulk       │ Backups, Updates   │ 5%         │
   └────────────┴────────────────────┴────────────┘
5. Application Detection: Enable (AI-based)
```

---

## Part 6: Critical Hardware Fixes (Priority 1)

### 6.1 Proxmox2 NIC Replacement (CRITICAL)

**Current Issue:**
- Proxmox2 (192.168.1.125) using USB Ethernet adapter `enxf44dad055788`
- Built-in NIC `eno1` is DOWN
- Caused cluster reboot on 2025-11-06 at 11:02:00
- Link failure at 10:53:51 (8+ minute outage)

**Root Cause Analysis:**
```bash
# SSH via cluster network (through proxmox at 192.168.1.137)
ssh -J root@192.168.1.137 root@192.168.1.125

# Investigate eno1 failure
dmesg | grep eno1
lspci | grep -i ethernet
ethtool eno1

# Expected findings:
# - Hardware failure OR
# - Driver issue OR
# - BIOS disabled
```

**Solution Options:**

**Option A: Fix Built-in NIC (Preferred)**
```bash
# Try to enable in BIOS/UEFI:
1. Reboot into BIOS
2. Navigate to Integrated Peripherals
3. Enable onboard LAN
4. Save and reboot

# Test driver reload:
modprobe -r <eno1_driver>  # Find driver: ethtool -i eno1
modprobe <eno1_driver>
ip link set eno1 up
ethtool eno1
```

**Option B: Install PCIe 2.5G NIC (If hardware failed)**
```
Recommended: Intel i225-V based adapter
- Models: Intel X550-T2, ASUS XG-C100C
- Cost: ~$40-60
- Speed: 2.5 Gbps (matches switch capability)
- Driver: Native Linux support (igc driver)
- PCIe: x1 or x4

Installation:
1. Schedule maintenance window (weekend)
2. Migrate VMs to proxmox and proxmox3
3. Shutdown proxmox2 gracefully
4. Install PCIe NIC
5. Boot and verify detection (lspci)
6. Configure /etc/network/interfaces
7. Rejoin cluster
```

**Network Configuration Update:**
```bash
# /etc/network/interfaces (after fix)
# Change from USB adapter to proper NIC

auto eno1  # or enp3s0 for PCIe NIC
iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.125/24
    gateway 192.168.1.1
    bridge-ports eno1  # CHANGED FROM enxf44dad055788
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# Apply:
ifreload -a

# Verify:
brctl show
ip addr show vmbr0
ethtool eno1 | grep Speed  # Should show: Speed: 2500Mb/s
```

**Testing and Validation:**
```bash
# After fix, comprehensive testing:
1. Verify link speed
ethtool eno1 | grep Speed

2. Check cluster status
pvecm status
pvecm nodes

3. Monitor for 48 hours
watch -n 10 'corosync-cfgtool -s'

4. Check for errors
dmesg | grep -i error
journalctl -u pve-cluster -f

Success Criteria:
✓ Speed: 2500Mb/s detected
✓ Link detected: yes
✓ No link down events for 48 hours
✓ Cluster quorum maintained
✓ No errors in dmesg
```

**Timeline:**
- **Immediate:** Investigate eno1 status (30 min)
- **If fixable:** BIOS/driver fix (1 hour)
- **If hardware failed:** Order PCIe NIC (2-3 days shipping)
- **Installation:** Maintenance window - Saturday/Sunday (2-4 hours)

### 6.2 Cable Testing and Replacement (Port 6)

**Switch Port:** Tw1/0/6 (Port 6 on SG3218-M2)
**Connected to:** Proxmox2 (192.168.1.125)

**Evidence of Issues:**
- Link down event at 2025-11-06 10:53:51
- Multiple state changes

**Diagnostic Steps:**
```bash
# Via Switch CLI (if cable tester available):
ssh administrator@192.168.1.210
enable
cable-test interface Tw1/0/6

# Expected results:
# - Pair A: OK, Length: XX meters
# - Pair B: OK, Length: XX meters
# - Pair C: OK, Length: XX meters
# - Pair D: OK, Length: XX meters
# OR
# - Pair X: Short/Open/Cross

# Check port statistics for errors:
show interfaces status Tw1/0/6
show interfaces counters Tw1/0/6

# Look for:
# - CRC errors
# - Collisions
# - Input errors
```

**Replacement Specifications:**
- **Cable Type:** Cat6A or Cat7
- **Length:** Match current (prefer <50m for 2.5G)
- **Shielding:** Recommended if near power/fluorescent lights
- **Termination:** Factory-made preferred, test both ends
- **Color:** Different from current (to identify after replacement)

**Post-Replacement Validation:**
```bash
# Monitor for 7 days:
ssh administrator@192.168.1.210
enable
show logging | include Tw1/0/6

# Should see:
# - "changed state to up" (once)
# - No "changed state to down" messages
# - No CRC errors in: show interfaces counters Tw1/0/6
```

---

## Part 7: Proxmox Cluster HA Improvements (Priority 2)

### 7.1 Corosync Dedicated Network (VLAN 5)

**Current State:**
- Single communication path on VLAN 1 (192.168.1.0/24)
- No redundancy
- Shared with all other traffic (VM, storage, management)
- Tuned timeouts (token: 10s, consensus: 12s) - applied 2025-11-06

**Target State:**
- Dual communication paths:
  - Link 0: VLAN 1 (192.168.1.0/24) - primary
  - Link 1: VLAN 5 (10.10.5.0/24) - dedicated, isolated
- Automatic failover between links
- Reduced timeout sensitivity

**Benefits:**
- Protection from network congestion
- Failover capability if one path fails
- Easier troubleshooting (isolated traffic)
- Foundation for future multi-site clustering

### 7.2 Implementation Roadmap

**Phase 1: VLAN 5 Creation on Firewalla**

```
Firewalla Network Manager:
1. Create Network → VLAN Network
2. Configuration:
   - Name: Corosync-Cluster
   - VLAN ID: 5
   - IP Range: 10.10.5.0/24
   - Gateway: NONE (leave empty) ⚠️ Critical!
   - DHCP: Disabled
   - Inter-VLAN Routing: Disabled ⚠️ Critical!
   - DNS: Not applicable
3. Port Assignment:
   - Port 1 (Trunk): Add VLAN 5 to tagged list
4. Save configuration

⚠️ IMPORTANT: No gateway and no routing for VLAN 5!
This creates an isolated L2 domain for cluster traffic only.
```

**Phase 2: Switch Configuration (SG3218-M2)**

```bash
# Via Omada Controller:
Settings → Wired Networks → Create LAN
- Name: Corosync
- VLAN ID: 5
- Gateway: None
- DHCP: None
- Purpose: Proxmox Cluster Communication

# Update port profiles for Proxmox nodes:
Devices → SW-Main-SG3218XP → Port Config

Port 2 (Proxmox):
- Mode: Trunk
- PVID: 1
- Tagged VLANs: 1, 5, 25, 40

Port 6 (Proxmox2):
- Mode: Trunk
- PVID: 1
- Tagged VLANs: 1, 5, 25, 40

Port 7 (Proxmox3):
- Mode: Trunk
- PVID: 1
- Tagged VLANs: 1, 5, 25, 40
```

**Phase 3: Proxmox VLAN Interface Creation**

```bash
# Execute on each Proxmox node sequentially

# Node: proxmox (192.168.1.137)
ssh root@192.168.1.137
nano /etc/network/interfaces

# Add VLAN 5 interface:
auto vmbr0.5
iface vmbr0.5 inet static
    address 10.10.5.137/24
    vlan-raw-device vmbr0
    # No gateway - isolated L2 domain

# Apply:
ifreload -a

# Verify:
ip addr show vmbr0.5
# Expected: 10.10.5.137/24

# Test connectivity to other nodes (after they're configured):
ping -c 3 10.10.5.125  # proxmox2
ping -c 3 10.10.5.126  # proxmox3
```

```bash
# Node: proxmox2 (192.168.1.125)
ssh root@192.168.1.125  # Or via jump: ssh -J root@192.168.1.137 root@192.168.1.125
nano /etc/network/interfaces

auto vmbr0.5
iface vmbr0.5 inet static
    address 10.10.5.125/24
    vlan-raw-device vmbr0

ifreload -a
ping -c 3 10.10.5.137
ping -c 3 10.10.5.126
```

```bash
# Node: proxmox3 (192.168.1.126)
ssh root@192.168.1.126
nano /etc/network/interfaces

auto vmbr0.5
iface vmbr0.5 inet static
    address 10.10.5.126/24
    vlan-raw-device vmbr0

ifreload -a
ping -c 3 10.10.5.137
ping -c 3 10.10.5.125
```

**Phase 4: Corosync Dual-Link Configuration**

**Before making changes:**
```bash
# Backup existing configuration on all nodes:
cp /etc/corosync/corosync.conf /etc/corosync/corosync.conf.backup-dual-link-$(date +%Y%m%d-%H%M%S)
```

**Edit /etc/corosync/corosync.conf on ALL nodes:**

```bash
# /etc/corosync/corosync.conf (updated with dual links)

totem {
  cluster_name: homelab-cluster
  config_version: 7  # INCREMENT from previous (was 6)

  # Link 0: Primary (existing VLAN 1)
  interface {
    linknumber: 0
    bindnetaddr: 192.168.1.0
    mcastport: 5405
    ttl: 1
  }

  # Link 1: Secondary (new VLAN 5 - dedicated Corosync)
  interface {
    linknumber: 1
    bindnetaddr: 10.10.5.0
    mcastport: 5407
    ttl: 1
  }

  ip_version: ipv4-6
  link_mode: passive
  secauth: on
  version: 2
  transport: knet  # Kronosnet enables multiple links

  # Existing HA tuning (from 2025-11-06)
  token: 10000
  token_retransmits_before_loss_const: 20
  consensus: 12000
}

nodelist {
  node {
    ring0_addr: 192.168.1.137
    ring1_addr: 10.10.5.137
    name: proxmox
    nodeid: 1
    quorum_votes: 1
  }

  node {
    ring0_addr: 192.168.1.125
    ring1_addr: 10.10.5.125
    name: proxmox2
    nodeid: 2
    quorum_votes: 1
  }

  node {
    ring0_addr: 192.168.1.126
    ring1_addr: 10.10.5.126
    name: proxmox3
    nodeid: 3
    quorum_votes: 1
  }
}

quorum {
  provider: corosync_votequorum
  expected_votes: 3
  two_node: 0
}

logging {
  to_logfile: yes
  logfile: /var/log/corosync/corosync.log
  to_syslog: yes
  timestamp: on
}
```

**Apply Configuration (CRITICAL: One node at a time!):**

```bash
# Node 1 (proxmox):
ssh root@192.168.1.137
corosync-cfgtool -R  # Reload configuration
sleep 30  # Wait for stabilization

# Verify cluster is still quorate:
pvecm status | grep Quorate  # Should show "Quorate: Yes"

# Node 2 (proxmox2):
ssh root@192.168.1.125
corosync-cfgtool -R
sleep 30
pvecm status | grep Quorate

# Node 3 (proxmox3):
ssh root@192.168.1.126
corosync-cfgtool -R
sleep 30
pvecm status | grep Quorate
```

**Verification and Testing:**

```bash
# Check link status (run on any node):
corosync-cfgtool -s

# Expected output:
# link[0]: 192.168.1.137 (link: STATUS = up)
# link[1]: 10.10.5.137 (link: STATUS = up)
#
# Same for other nodes

# Check detailed Kronosnet status:
corosync-cmapctl | grep knet

# Should show both links active for all nodes

# View cluster communication:
corosync-quorumtool -s
```

**Failover Testing (After all nodes configured):**

```bash
# Test 1: Disable VLAN 1 on proxmox to verify VLAN 5 failover
ssh root@192.168.1.137

# Bring down primary link temporarily:
ip link set vmbr0 down

# From another node, verify cluster still quorate:
ssh root@192.168.1.125
pvecm status  # Should still show Quorate: Yes

# Corosync should automatically use Link 1 (VLAN 5)
corosync-cfgtool -s  # Should show link[0] down, link[1] up

# Restore primary link:
ssh root@192.168.1.137
ip link set vmbr0 up

# Verify both links active again:
corosync-cfgtool -s
```

**Success Criteria:**
- ✅ All three nodes have 10.10.5.x IP addresses
- ✅ Ping works across VLAN 5 between all nodes
- ✅ `corosync-cfgtool -s` shows 2 active links per node
- ✅ Cluster remains quorate when either link fails
- ✅ No increase in Corosync latency
- ✅ No errors in /var/log/corosync/corosync.log

---

## Part 8: Migration Plan and Timeline

### 8.1 Pre-Migration Preparation (Week 0)

**Documentation and Inventory:**
```bash
# Create comprehensive device inventory:
1. Document all devices and current IPs:
   - Create spreadsheet: docs/network/device-inventory.xlsx
   - Columns: Device Name, MAC, Current IP, New VLAN, New IP, Notes

2. Map services and dependencies:
   - Which devices talk to which?
   - Which require cross-VLAN communication?
   - Which have static IP requirements?

3. Create network diagram:
   - Use draw.io or similar
   - Show physical connections
   - Show logical VLAN assignments

4. Backup all configurations:
   - Firewalla: Export configuration
   - Omada: Export site configuration
   - Proxmox: Backup cluster configuration
   - Document all current IPs and services
```

**Risk Assessment:**
```
High Risk Items (require maintenance window):
- Proxmox2 NIC replacement
- Corosync dual-link implementation
- Storage network migration (VLAN 40)

Medium Risk Items:
- Client device VLAN migration
- Firewall rule implementation

Low Risk Items:
- Guest WiFi setup (new SSID, no existing users)
- Monitoring setup
```

### 8.2 Implementation Timeline

**Phase 1: Foundation (Weeks 1-2) - Hardware and Infrastructure**

```
Week 1: Critical Hardware Fixes
├─ Day 1-2: Proxmox2 NIC Investigation
│  ├─ Diagnose eno1 failure
│  ├─ Order PCIe NIC if needed
│  └─ Plan maintenance window
│
├─ Day 3: Cable Testing
│  ├─ Test all Proxmox node cables
│  ├─ Replace Port 6 cable if needed
│  └─ Monitor for 24 hours
│
├─ Day 4-5: Proxmox2 NIC Replacement (if needed)
│  ├─ Maintenance window: Saturday 8 AM - 12 PM
│  ├─ Migrate VMs to other nodes
│  ├─ Install new hardware
│  ├─ Test and validate
│  └─ 48-hour burn-in monitoring
│
└─ Day 6-7: Validation and Documentation
   ├─ Verify cluster stability
   ├─ Update network documentation
   └─ Baseline performance metrics

Week 2: Firewalla Gold Setup
├─ Day 1-2: Firewalla Installation
│  ├─ Unbox and physically install FWG
│  ├─ Configure Router Mode
│  ├─ Connect WAN 1 (Spectrum) to Port 4
│  ├─ Connect WAN 2 (Frontier) to Port 3
│  ├─ Test internet connectivity on both WANs
│  └─ Configure basic failover
│
├─ Day 3-4: VLAN Creation on FWG
│  ├─ Create all VLAN interfaces (1, 5, 10, 20, 25, 30, 35, 40, 99)
│  ├─ Configure DHCP servers for client VLANs
│  ├─ Disable routing for VLAN 5 (Corosync)
│  ├─ Configure Port 1 as trunk to SG3218-M2
│  └─ Test basic connectivity
│
└─ Day 5-7: Multi-WAN Optimization
   ├─ Configure Policy-Based Routing
   ├─ Set Frontier Fiber as primary WAN
   ├─ Create traffic rules for WAN selection
   ├─ Test failover scenarios
   └─ Validate bandwidth utilization
```

**Phase 2: Infrastructure VLANs (Weeks 3-4) - Low Risk First**

```
Week 3: Corosync and Management VLANs
├─ Day 1-2: VLAN 5 (Corosync) Implementation
│  ├─ Configure switch ports 2, 6, 7 for VLAN 5
│  ├─ Add VLAN 5 interfaces to all Proxmox nodes
│  ├─ Test ping connectivity on 10.10.5.0/24
│  └─ Validate isolated L2 domain (no routing)
│
├─ Day 3-4: Dual Corosync Links
│  ├─ Update corosync.conf on all nodes
│  ├─ Add ring1_addr configuration
│  ├─ Reload Corosync (one node at a time)
│  ├─ Verify both links active
│  └─ Test failover scenarios
│
└─ Day 5-7: VLAN 25 (Hypervisor Management)
   ├─ Create VLAN 25 on Firewalla
   ├─ Add VLAN 25 to switch trunk ports
   ├─ Add secondary IPs to Proxmox nodes (10.10.25.x)
   ├─ Test management interface access
   └─ Update documentation

Week 4: Storage Network (VLAN 40)
├─ Day 1-2: Planning and Preparation
│  ├─ Identify all storage consumers
│  ├─ Plan IP addresses for VLAN 40
│  ├─ Schedule maintenance window (Sunday 6 AM - 10 AM)
│  └─ Prepare rollback procedure
│
├─ Day 3-4: Storage VLAN Implementation
│  ├─ Create VLAN 40 on Firewalla (no DHCP)
│  ├─ Configure switch access port 5 for VLAN 40
│  ├─ Add VLAN 40 to Proxmox trunk ports (2, 6, 7)
│  └─ Test connectivity
│
├─ Day 5: TrueNAS Migration
│  ├─ Maintenance Window Start
│  ├─ Backup TrueNAS configuration
│  ├─ Change TrueNAS primary IP to 10.10.40.10
│  ├─ Add VLAN 40 interfaces to Proxmox (10.10.40.137, .125, .126)
│  ├─ Update NFS/iSCSI mount points in Proxmox
│  ├─ Test storage access from all nodes
│  └─ Maintenance Window End
│
└─ Day 6-7: Storage Performance Tuning
   ├─ Test baseline throughput (iperf3)
   ├─ Configure jumbo frames (MTU 9000) if supported
   ├─ Re-test throughput
   ├─ Monitor for 48 hours
   └─ Document performance improvements
```

**Phase 3: Client VLANs (Weeks 5-6) - Gradual Migration**

```
Week 5: Wi-Fi Network Setup
├─ Day 1-2: EAP773 VLAN Configuration
│  ├─ Via Omada Controller, update both APs
│  ├─ Create SSID: "Lakehouse" → VLAN 10
│  ├─ Create SSID: "Lakehouse-IoT" → VLAN 20
│  ├─ Create SSID: "Lakehouse-Daughter" → VLAN 30
│  ├─ Create SSID: "Lakehouse-Guest" → VLAN 99
│  └─ Verify VLAN tagging on switch ports 4 and 8
│
├─ Day 3: Guest Network Testing (Low Risk)
│  ├─ Connect test device to "Lakehouse-Guest"
│  ├─ Verify receives 192.168.99.x IP
│  ├─ Test internet access
│  ├─ Verify cannot access local resources
│  └─ Enable firewall logging for guest VLAN
│
├─ Day 4-5: Main LAN Migration
│  ├─ Connect personal devices to "Lakehouse" SSID
│  ├─ Verify 192.168.10.x IP assignment
│  ├─ Test all services (printing, file sharing, etc.)
│  ├─ Enable mDNS relay for service discovery
│  └─ Gradually migrate all trusted devices
│
└─ Day 6-7: Daughter's Network Setup
   ├─ Configure VLAN 30 parental controls on FWG
   ├─ Set up access schedule
   ├─ Connect test device to "Lakehouse-Daughter"
   ├─ Verify 192.168.30.x IP
   ├─ Test internet access and restrictions
   └─ Migrate daughter's devices

Week 6: IoT Network Migration (Highest Complexity)
├─ Day 1-2: IoT Device Inventory and Planning
│  ├─ List all IoT devices: cameras, sensors, smart home
│  ├─ Identify which require local control (e.g., Home Assistant)
│  ├─ Plan firewall rules for IoT access
│  └─ Prepare troubleshooting guide
│
├─ Day 3-4: Gradual IoT Migration
│  ├─ Start with non-critical devices
│  ├─ Reconnect to "Lakehouse-IoT" SSID
│  ├─ Verify 192.168.20.x IP assignment
│  ├─ Test cloud connectivity
│  ├─ Configure firewall allow rules for control traffic
│  └─ Test local control from Main LAN
│
├─ Day 5: Critical IoT Devices
│  ├─ Migrate security cameras (test recording)
│  ├─ Migrate Zigbee/Z-Wave hubs (test device control)
│  ├─ Update Home Assistant integration IPs
│  └─ Verify all automations still work
│
└─ Day 6-7: Validation and Optimization
   ├─ Test all IoT→Internet connectivity
   ├─ Test Main LAN→IoT control paths
   ├─ Verify IoT→LAN blocking (security test)
   ├─ Enable IoT firewall logging
   ├─ Monitor for anomalies
   └─ Update documentation
```

**Phase 4: Advanced Features (Weeks 7-8)**

```
Week 7: Performance Optimization
├─ Day 1-3: LACP Link Aggregation (TrueNAS)
│  ├─ Configure LAG1 on switch (ports 5 + 9)
│  ├─ Configure bond0 on TrueNAS (LACP mode)
│  ├─ Test failover (disconnect one link)
│  ├─ Benchmark throughput (iperf3)
│  └─ Monitor for stability
│
├─ Day 4-5: Jumbo Frames Testing
│  ├─ Enable MTU 9000 on switch
│  ├─ Configure storage VLAN (40) for jumbo frames
│  ├─ Update Proxmox storage interfaces (MTU 9000)
│  ├─ Update TrueNAS interface (MTU 9000)
│  ├─ Test with ping -M do -s 8972
│  └─ Benchmark improvement
│
└─ Day 6-7: QoS Fine-Tuning
   ├─ Configure FWG Smart Queue Management
   ├─ Set WAN bandwidth limits
   ├─ Create traffic priority classes
   ├─ Test under load (speed test + streaming)
   └─ Adjust based on results

Week 8: Monitoring and Automation
├─ Day 1-2: SNMP Monitoring Setup
│  ├─ Enable SNMP on SG3218-M2
│  ├─ Enable SNMP on EAP773 APs
│  ├─ Configure monitoring server (LibreNMS or similar)
│  ├─ Add all devices to monitoring
│  └─ Configure alerts
│
├─ Day 3-4: Corosync Health Monitoring
│  ├─ Deploy monitor-corosync.sh script
│  ├─ Configure cron job (every 5 min)
│  ├─ Set up email alerts
│  ├─ Test alert triggering
│  └─ Create dashboard
│
└─ Day 5-7: Documentation and Training
   ├─ Update all network documentation
   ├─ Create troubleshooting guides
   ├─ Document all passwords and access
   ├─ Create network diagram (final version)
   ├─ Train family on new SSIDs
   └─ Create runbook for common tasks
```

### 8.3 Rollback Procedures

**Emergency Rollback (If Critical Failure):**

```bash
# Immediate restoration to flat network:

# 1. Firewalla: Set Port 1 to simple bridge mode
#    All traffic untagged

# 2. Switch: Remove all VLAN configurations
ssh administrator@192.168.1.210
enable
configure
# For all ports:
interface range GigabitEthernet 1/0/1-16
  switchport mode access
  switchport access vlan 1
exit
write memory

# 3. Proxmox: Remove VLAN interfaces
ssh root@192.168.1.137
nano /etc/network/interfaces
# Comment out or remove all vmbr0.X VLAN interfaces
ifreload -a

# 4. Corosync: Revert to single-link configuration
# Restore from backup:
cp /etc/corosync/corosync.conf.backup-[timestamp] /etc/corosync/corosync.conf
corosync-cfgtool -R

# 5. EAP773: Disable VLAN mapping
# Via Omada: Set all SSIDs to "No VLAN"

# 6. Verify all services operational on 192.168.1.0/24
```

**Partial Rollback (Single VLAN Issue):**

```
If specific VLAN has issues:
1. Identify problematic VLAN (e.g., IoT - VLAN 20)
2. Move devices back to Main LAN or Management VLAN
3. Disable firewall rules for that VLAN
4. Remove VLAN from trunk ports temporarily
5. Troubleshoot root cause
6. Re-implement when fixed
```

### 8.4 Testing and Validation Checklist

**For Each VLAN Implementation:**

```
□ DHCP Assignment Test
  ├─ Connect test device
  ├─ Verify correct IP range
  ├─ Verify gateway is FWG
  └─ Verify DNS resolution

□ Internet Connectivity Test
  ├─ ping 8.8.8.8 (IP connectivity)
  ├─ ping google.com (DNS resolution)
  ├─ curl https://google.com (HTTPS)
  └─ speedtest (bandwidth)

□ Inter-VLAN Security Test
  ├─ Attempt to ping device on different VLAN
  ├─ Attempt to SSH to device on restricted VLAN
  ├─ Verify firewall logs show blocks
  └─ Test allow rules (where applicable)

□ Service Discovery Test (if applicable)
  ├─ Test AirPlay discovery
  ├─ Test Chromecast discovery
  ├─ Test printer discovery
  └─ Verify mDNS relay working

□ Performance Test
  ├─ iperf3 throughput test
  ├─ Latency test (ping statistics)
  ├─ DNS resolution speed
  └─ Web browsing responsiveness

□ Failover Test (infrastructure VLANs only)
  ├─ Disable one link
  ├─ Verify automatic failover
  ├─ Verify services remain available
  ├─ Re-enable link
  └─ Verify return to normal

□ 24-Hour Stability Test
  ├─ Monitor for disconnections
  ├─ Check firewall logs for anomalies
  ├─ Verify DHCP lease renewal
  └─ Confirm no performance degradation
```

---

## Part 9: Success Metrics and KPIs

### 9.1 Reliability Metrics (30-Day Post-Implementation)

```
Target: 99.9% Uptime

Measurements:
□ Zero unplanned Proxmox node reboots
  Current: 1 reboot in 30 days (2025-11-06)
  Target: 0 reboots in 30 days

□ Cluster quorum uptime: 99.9%
  Current: ~99.4% (8 min outage on 2025-11-06)
  Target: 99.9% (max 43 min/month)

□ WAN failover events: Logged and functional
  Target: <1 min switchover time

□ Network-related incidents: Zero
  Current: 1 critical incident (NIC failure)
  Target: 0 incidents

□ Mean Time Between Failures (MTBF): >90 days
  Current: Unknown (new deployment)
  Target: >90 days for any single component
```

### 9.2 Performance Metrics

```
Target: Low Latency, High Throughput

Corosync Cluster Performance:
□ Average latency: <1 ms
  Test: corosync-cfgtool -s (view avg latency)
  Target: <1 ms on both links

□ Packet loss: 0%
  Test: ping -c 1000 -i 0.01 10.10.5.125
  Target: 0.00% loss

□ Jitter: <0.5 ms
  Test: Monitor Corosync statistics
  Target: <0.5 ms variation

Storage Network Performance:
□ Throughput per client: >200 MB/s
  Test: iperf3 -c 10.10.40.10 -t 60
  Target: >200 MB/s (1.6 Gbps)

□ With LACP: >400 MB/s aggregate
  Test: Multiple parallel iperf3 streams
  Target: >400 MB/s (3.2 Gbps aggregate)

□ With Jumbo Frames: >250 MB/s
  Test: Large file copy (rsync)
  Target: >250 MB/s (2.0 Gbps)

WAN Performance:
□ Frontier Fiber utilization: >80% of traffic
  Monitor: FWG traffic statistics
  Target: 80% on WAN2, 20% on WAN1/failover

□ Download speed: >1.8 Gbps (Frontier)
  Test: speedtest.net
  Target: >1.8 Gbps (90% of 2.0 Gbps line)

□ Upload speed: >1.8 Gbps (Frontier)
  Test: speedtest.net upload
  Target: >1.8 Gbps

Wi-Fi Performance:
□ 6 GHz throughput: >1 Gbps
  Test: iperf3 from Wi-Fi 7 client
  Target: >1 Gbps on 6 GHz band

□ 5 GHz throughput: >500 Mbps
  Test: iperf3 from Wi-Fi 6 client
  Target: >500 Mbps
```

### 9.3 Security Metrics

```
Target: Zero Unauthorized Access

VLAN Isolation:
□ IoT→LAN blocked connections: >0 attempts, 0 success
  Monitor: FWG firewall logs
  Target: 100% block rate

□ IoT→Storage blocked: >0 attempts, 0 success
  Target: 100% block rate

□ Guest→LAN blocked: >0 attempts, 0 success
  Target: 100% block rate

Parental Controls (VLAN 30):
□ Content filter effectiveness: 100%
  Test: Attempt to access blocked categories
  Target: 100% block rate

□ Schedule enforcement: 100%
  Test: Access outside allowed hours
  Target: 100% compliance

Threat Detection:
□ FWG threat blocks: Monitored
  Target: All threats blocked, user alerted

□ Anomalous traffic detection: Enabled
  Target: Alerts on unusual patterns
```

### 9.4 Operational Metrics

```
Target: Efficient Management

Monitoring Coverage:
□ All network devices monitored: 100%
  Devices: FWG, SG3218-M2, EAP773×2, Proxmox×3, TrueNAS
  Target: 100% SNMP coverage

□ Alert response time: <15 minutes
  Target: Acknowledge within 15 min, resolve within 4 hours

Documentation:
□ Network diagram: Up to date
  Target: Updated within 24 hours of changes

□ Device inventory: Complete
  Target: All devices documented with IPs, VLANs, purposes

□ Runbooks: Created
  Target: Procedures for common tasks

Training:
□ Family SSID understanding: 100%
  Target: All users know which SSID to use

□ Troubleshooting guide: Available
  Target: Self-service for common issues
```

---

## Part 10: Cost Analysis and ROI

### 10.1 Hardware Investment

```
Required Purchases:
┌──────────────────────────────────────────────────────────┐
│ Item                        │ Qty │ Unit Cost │ Total    │
├─────────────────────────────┼─────┼───────────┼──────────│
│ Firewalla Gold              │  1  │ $468      │ $468     │
│ PCIe 2.5G NIC (if needed)   │  1  │ $50       │ $50      │
│ Cat6A cables (replacement)  │  2  │ $15       │ $30      │
│ 10G SFP+ modules (future)   │  2  │ $40       │ $80      │
│ DAC cable (future)          │  1  │ $25       │ $25      │
├─────────────────────────────┴─────┴───────────┼──────────│
│ Total (Initial)                               │ $548     │
│ Total (With 10G Future)                       │ $653     │
└───────────────────────────────────────────────┴──────────┘

Existing Equipment (No Cost):
- TP-Link SG3218XP-M2 (already owned)
- TP-Link EAP773 × 2 (already owned)
- Proxmox servers × 3 (already owned)
- TrueNAS (already owned)
```

### 10.2 Time Investment

```
Administrator Time:
- Planning and design: 8 hours
- Implementation (8 weeks): 60 hours
- Testing and validation: 20 hours
- Documentation: 12 hours
Total: ~100 hours

Value of Time:
If outsourced at $100/hr: $10,000
DIY with guidance: $0 (learning experience)
```

### 10.3 Return on Investment

**Quantifiable Benefits:**

```
1. Prevented Downtime
   - Proxmox cluster stability improvements
   - Dual Corosync links prevent split-brain
   - Estimated prevention: 4 hours/year downtime
   - Value (if production): $500/hour = $2,000/year

2. Internet Cost Optimization
   - Maximize utilization of 2.0 Gbps Frontier Fiber
   - Reduce reliance on slower Spectrum connection
   - Potential to downgrade or cancel Spectrum
   - Savings: $70/month × 12 = $840/year

3. Security Incident Prevention
   - IoT isolation prevents lateral movement
   - Estimated risk reduction: 80%
   - Average cost of home network breach: $2,000
   - Expected value: $1,600/year

4. Performance Improvements
   - Storage network optimization
   - Reduced backup/restore times
   - Value: Time savings estimated $500/year

Total Quantifiable ROI: $4,940/year
Payback Period: ~1.3 months (if downtime valued)
               ~9.8 months (without downtime value)
```

**Non-Quantifiable Benefits:**
- Enhanced security and peace of mind
- Better parental controls
- Network management skills
- Improved guest access experience
- Future-proofing for 10G expansion
- Centralized monitoring and visibility

---

## Part 11: Maintenance and Operational Procedures

### 11.1 Regular Maintenance Schedule

**Daily Automated Checks:**
```bash
# Corosync health check (via cron):
*/5 * * * * /usr/local/bin/monitor-corosync.sh

# Interface error check:
*/10 * * * * /usr/local/bin/check-interface-errors.sh

# FWG monitors automatically:
# - WAN health (ping tests every 30s)
# - Threat detection
# - Device connectivity
```

**Weekly Manual Checks:**
```
Every Sunday @ 10 AM:
□ Review FWG dashboard
  ├─ Check WAN uptime and utilization
  ├─ Review blocked threats
  ├─ Check top bandwidth consumers
  └─ Verify parental control effectiveness

□ Review switch status (Omada)
  ├─ Check port statistics for errors
  ├─ Verify PoE budget and usage
  ├─ Review VLAN configuration
  └─ Check for firmware updates

□ Check Proxmox cluster health
  ├─ pvecm status (quorum)
  ├─ corosync-cfgtool -s (link status)
  ├─ Review /var/log/corosync/corosync.log
  └─ Verify all nodes online

□ Review logs for anomalies
  ├─ Firewall blocks (unusual patterns)
  ├─ Network disconnections
  ├─ Authentication failures
  └─ Performance degradation
```

**Monthly Tasks:**
```
First Saturday of Month:
□ Backup all configurations
  ├─ Export Firewalla configuration
  ├─ Export Omada site configuration
  ├─ Backup /etc/network/interfaces from all Proxmox nodes
  ├─ Backup /etc/corosync/corosync.conf
  └─ Save to encrypted cloud storage

□ Firmware update check
  ├─ Firewalla Gold (auto-update optional)
  ├─ SG3218-M2 switch
  ├─ EAP773 APs
  └─ Proxmox VE (minor updates)

□ Performance testing
  ├─ speedtest.net on both WANs
  ├─ iperf3 storage network test
  ├─ Wi-Fi speed test on all bands
  └─ Compare to baseline metrics

□ Security audit
  ├─ Review firewall rule effectiveness
  ├─ Check for unusual devices
  ├─ Verify IoT isolation
  └─ Test parental controls

□ Documentation update
  ├─ Update device inventory
  ├─ Note any configuration changes
  └─ Update network diagram if needed
```

**Quarterly Tasks:**
```
□ Cable plant inspection
  ├─ Visual check all connections
  ├─ Verify cable routing
  ├─ Check for damage or wear
  └─ Re-seat any questionable connections

□ Capacity planning
  ├─ Review network utilization trends
  ├─ Check switch port availability
  ├─ Assess PoE budget headroom
  └─ Plan for growth

□ Disaster recovery test
  ├─ Simulate WAN failure
  ├─ Simulate switch failure
  ├─ Test backup restoration
  └─ Verify recovery procedures

□ Comprehensive audit
  ├─ Review all success metrics
  ├─ Identify optimization opportunities
  └─ Update planning documents
```

### 11.2 Troubleshooting Guide

**Symptom: Proxmox Cluster Loses Quorum**

```
Diagnosis Steps:
1. Check cluster status:
   pvecm status
   # Look for: Quorate: No, missing nodes

2. Check Corosync links:
   corosync-cfgtool -s
   # Look for: STATUS = down on one or both links

3. Check network connectivity:
   ping 192.168.1.137  # Primary link
   ping 10.10.5.137    # Corosync link

4. Check for network loops/storms:
   # Via switch: show interfaces counters
   # Look for excessive errors/drops

Resolution:
A. If one link down but cluster quorate:
   - Investigate failed link
   - Corosync should auto-failover to working link
   - Fix failed link, Corosync will auto-restore

B. If both links down:
   - Check switch VLAN configuration
   - Verify Firewalla routing (shouldn't route VLAN 5!)
   - Check physical cables
   - Restart Corosync if necessary (last resort)

C. If split-brain (nodes see different quorum):
   - ⚠️ DO NOT force quorum until understood
   - Verify network topology
   - Check for accidental loop
   - If necessary: shut down minority partition
```

**Symptom: IoT Device Can't Connect to Cloud**

```
Diagnosis Steps:
1. Verify device has correct IP:
   # Should be 192.168.20.x

2. Check SSID to VLAN mapping:
   # Via Omada: SSID "Lakehouse-IoT" → VLAN 20

3. Test internet from IoT VLAN:
   # Connect phone to IoT SSID
   ping 8.8.8.8
   nslookup google.com

4. Check Firewalla rules:
   # Ensure IoT → Internet is ALLOWED
   # Rule should be ABOVE any DENY rules

Resolution:
A. If DHCP issue:
   - Verify FWG DHCP server for VLAN 20
   - Check device can see DHCP offer
   - Restart device

B. If internet blocked:
   - Check firewall rule order
   - Ensure allow rule is before deny rule
   - Verify rule applies to VLAN 20

C. If DNS issue:
   - Verify FWG is providing DNS (192.168.20.1)
   - Test alternate DNS: 1.1.1.1
```

**Symptom: Can't Discover AirPlay Device on IoT VLAN**

```
Diagnosis Steps:
1. Verify mDNS relay enabled on FWG:
   Settings → Advanced → Service Discovery
   # Should be enabled for Main LAN and IoT

2. Check IGMP Snooping on switch:
   show ip igmp snooping
   # Should be: disabled

3. Test multicast forwarding:
   # From Main LAN client:
   dns-sd -B _airplay._tcp

4. Verify firewall not blocking mDNS:
   # Protocol: UDP
   # Port: 5353
   # Multicast: 224.0.0.251

Resolution:
A. Enable mDNS relay on FWG for both VLANs

B. Disable IGMP Snooping on switch:
   configure
   no ip igmp snooping
   exit
   write memory

C. Verify firewall allows response traffic
   (stateful firewall should auto-allow)
```

**Symptom: High CPU on Firewalla**

```
Diagnosis Steps:
1. Check active connections:
   # Via FWG web interface: Monitor → Connections

2. Identify traffic patterns:
   # Look for: Excessive connections from single device

3. Check for DDOS or port scan:
   # Monitor → Threats

Resolution:
A. If legitimate high traffic:
   - Verify QoS settings
   - Consider traffic shaping

B. If malicious activity:
   - Block source IP/device
   - Review firewall logs
   - Isolate affected VLAN

C. If bug/misconfiguration:
   - Check mDNS relay (can be CPU-intensive)
   - Review firewall rule complexity
   - Consider firmware update
```

### 11.3 Emergency Contacts and Escalation

```
Tier 1: Self-Service
- This documentation
- Firewalla support portal: help.firewalla.com
- TP-Link Omada support: www.tp-link.com/support/
- Proxmox forum: forum.proxmox.com

Tier 2: Vendor Support
- Firewalla Support: support@firewalla.com
- TP-Link Support: 1-866-225-8139
- ISP Support:
  - Spectrum: 1-855-707-7328
  - Frontier: 1-800-921-8101

Tier 3: Professional Services
- Local network consultant (if needed)
- Proxmox commercial support (if business-critical)
```

---

## Part 12: Future Expansion Roadmap

### 12.1 Short-term Enhancements (6-12 months)

**1. TrueNAS 10G Upgrade**
```
Objective: Dedicated 10 Gbps storage path

Hardware Required:
- 1× Intel X550-T2 (2×10GBASE-T) for TrueNAS: $200
- 1× 10G SFP+ module for switch: $40
- 1× SFP+ DAC cable: $25
Total: ~$265

Configuration:
- Connect TrueNAS 10G NIC to SFP+ port 17 (SG3218-M2)
- Configure VLAN 40 on 10G interface
- Jumbo frames (MTU 9000)
- Expected throughput: >800 MB/s (6.4 Gbps)

Benefits:
- 4× faster backup/restore
- Support for multiple concurrent VM operations
- Future-proof storage architecture
```

**2. Network Monitoring Platform (LibreNMS)**
```
Objective: Comprehensive monitoring and alerting

Deployment:
- LXC container on Proxmox (2 vCPU, 4GB RAM)
- VLAN 1 (Management) or VLAN 35 (VMs)
- IP: 192.168.1.x or 10.10.35.x

Features:
- SNMP polling all devices
- Graphical performance dashboards
- Alerting (email/SMS/Slack)
- Historical trend analysis
- Automatic topology discovery

Integration:
- FWG: SNMP v2c/v3
- SG3218-M2: SNMP monitoring
- EAP773 APs: SNMP monitoring
- Proxmox: API integration
- TrueNAS: SNMP monitoring
```

**3. Configuration Backup Automation (Oxidized)**
```
Objective: Automated daily config backups

Deployment:
- Docker container or LXC
- Scheduled daily backups
- Git repository for version control

Devices:
- Firewalla (export configuration)
- SG3218-M2 (running-config)
- Proxmox cluster (corosync.conf, interfaces)
- Omada Controller (site export)

Retention:
- Daily: 30 days
- Weekly: 12 weeks
- Monthly: 12 months
```

### 12.2 Medium-term Enhancements (1-2 years)

**1. Second Switch for Redundancy**
```
Objective: Eliminate single point of failure

Topology:
- Purchase second SG3218XP-M2
- Create LACP trunk between switches (ports 17-18)
- Dual-home critical devices (Proxmox, TrueNAS, FWG)

Benefits:
- No single switch failure takes down network
- Increased aggregate bandwidth
- Maintenance without downtime

Configuration:
Switch 1 (existing):
├─ Ports 1-16: Access/trunks (as current)
└─ Ports 17-18: Inter-switch LAG (all VLANs)

Switch 2 (new):
├─ Ports 1-16: Mirror of Switch 1
└─ Ports 17-18: Inter-switch LAG (all VLANs)

Dual-homed devices:
- Proxmox nodes: 2× NICs, bonded LACP
- TrueNAS: Already has 2× NICs, use for bonding
- FWG: Use Port 2 for redundant trunk
```

**2. Dedicated IPAM (Netbox)**
```
Objective: Professional IP address management

Features:
- Device inventory
- IP address tracking
- VLAN documentation
- Cable management
- API for automation

Benefits:
- Prevent IP conflicts
- Easier planning
- Integration with monitoring
- Change tracking
```

**3. VPN for Remote Access**
```
Objective: Secure remote access to home network

Implementation Options:

Option A: Firewalla Built-in VPN
- OpenVPN or WireGuard
- User profiles for each family member
- Access to specific VLANs only
- Simple setup via FWG app

Option B: Dedicated VPN Server (WireGuard)
- LXC on Proxmox
- More control and flexibility
- Split-tunnel configuration
- Peer-to-peer capabilities

Access Profiles:
- Admin: Full access (all VLANs)
- User: Main LAN + IoT control
- Guest: Internet only via VPN
```

### 12.3 Long-term Vision (2+ years)

**1. Multi-Site Clustering**
```
Objective: Proxmox cluster across multiple sites

Scenario:
- Main site (current location)
- Remote site (vacation home, office, etc.)
- Corosync over VPN (requires <5ms latency)

Requirements:
- Dedicated VPN tunnel (site-to-site)
- Low-latency connection (<5ms)
- Minimum 100 Mbps symmetrical bandwidth
- VLAN extension to remote site

Benefits:
- Geographic redundancy
- Disaster recovery
- Live migration across sites
```

**2. Home Automation Integration**
```
Objective: Deep network/home integration

Features:
- Home Assistant on VLAN 35
- Network-aware automations:
  - "Pause internet on daughter's VLAN at bedtime"
  - "Alert if IoT device connects at unusual time"
  - "Enable guest WiFi when doorbell detects visitor"
- Presence detection via network (device tracking)
- Security automations (lock down on intrusion)

Integration Points:
- FWG API for firewall control
- Omada API for network changes
- Presence detection via network
```

**3. Advanced Security (IDS/IPS)**
```
Objective: Intrusion detection and prevention

Implementation:

Option A: Firewalla Pro Features
- Enable advanced threat detection
- Behavioral analysis
- Automatic blocking

Option B: Dedicated Suricata/Snort
- Mirror port on switch (port monitoring)
- LXC running Suricata IDS
- Integration with FWG for automatic blocking

Monitoring:
- DDoS detection
- Port scans
- Malware C2 communication
- Data exfiltration attempts
```

**4. Network Analytics and Baselines**
```
Objective: ML-based anomaly detection

Tools:
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Network flow analysis (NetFlow/sFlow)
- Behavioral baselines

Use Cases:
- Detect unusual traffic patterns
- Identify compromised devices
- Optimize network performance
- Capacity planning
```

---

## Appendices

### Appendix A: Command Reference

**Firewalla Gold Quick Commands:**
```bash
# Via SSH (if enabled):
ssh pi@192.168.1.1

# View routes:
ip route show

# View VLANs:
ip addr show

# Monitor traffic:
iftop

# View firewall rules:
sudo iptables -L -v -n

# Restart Firewalla:
sudo systemctl restart firewalla
```

**SG3218-M2 Switch Quick Commands:**
```bash
# Access CLI:
ssh administrator@192.168.1.210
enable

# Show VLAN configuration:
show vlan

# Show port status:
show interfaces status

# Show port statistics:
show interfaces counters

# Show spanning tree:
show spanning-tree

# Show MAC address table:
show mac address-table

# Cable test:
cable-test interface Tw1/0/X

# Show running config:
show running-config

# Save config:
write memory
```

**Proxmox Quick Commands:**
```bash
# Cluster status:
pvecm status
pvecm nodes

# Corosync status:
corosync-cfgtool -s
corosync-quorumtool -s

# View Corosync log:
tail -f /var/log/corosync/corosync.log

# Reload Corosync config:
corosync-cfgtool -R

# Network configuration:
ip addr show
brctl show
cat /etc/network/interfaces

# Restart networking:
ifreload -a
systemctl restart networking

# VM/LXC management:
pvesh get /cluster/resources --type vm
qm list  # VMs
pct list  # Containers
```

### Appendix B: IP Address Allocation

**Management VLAN (1) - 192.168.1.0/24:**
```
.1        - Firewalla Gold (gateway)
.10       - TrueNAS (legacy, will move to VLAN 40)
.47       - Omada Controller (LXC 111)
.100-.199 - DHCP pool (workstations, printers)
.125      - Proxmox2 (vmbr0)
.126      - Proxmox3 (vmbr0)
.137      - Proxmox (vmbr0)
.154      - Caddy reverse proxy
.155      - Home Assistant
.210      - SG3218-M2 switch management
.224      - EAP773 Upstairs
.253      - Legacy AdGuard (decommissioned)
```

**Corosync VLAN (5) - 10.10.5.0/24:**
```
.125      - Proxmox2 (vmbr0.5)
.126      - Proxmox3 (vmbr0.5)
.137      - Proxmox (vmbr0.5)
```

**Main LAN VLAN (10) - 192.168.10.0/24:**
```
.1        - Firewalla Gold (gateway)
.100-.199 - DHCP pool (trusted client devices)
```

**IoT VLAN (20) - 192.168.20.0/24:**
```
.1        - Firewalla Gold (gateway)
.10       - SLZB-06 Zigbee coordinator
.11       - E-eye Alarm panel
.100-.199 - DHCP pool (IoT devices)
```

**Hypervisor Mgmt VLAN (25) - 10.10.25.0/24:**
```
.1        - Firewalla Gold (gateway)
.125      - Proxmox2 secondary mgmt IP
.126      - Proxmox3 secondary mgmt IP
.137      - Proxmox secondary mgmt IP
```

**Daughter's VLAN (30) - 192.168.30.0/24:**
```
.1        - Firewalla Gold (gateway)
.100-.199 - DHCP pool (user devices)
```

**VMs-Trusted VLAN (35) - 10.10.35.0/24:**
```
.1        - Firewalla Gold (gateway)
.10       - Home Assistant (if moved from VLAN 1)
.11       - Omada Controller (if moved from VLAN 1)
.100-.199 - DHCP pool (VMs and LXCs)
```

**Storage VLAN (40) - 10.10.40.0/24:**
```
.1        - Firewalla Gold (gateway)
.10       - TrueNAS storage interfaces
.125      - Proxmox2 storage interface (vmbr0.40)
.126      - Proxmox3 storage interface (vmbr0.40)
.137      - Proxmox storage interface (vmbr0.40)
```

**Guest VLAN (99) - 192.168.99.0/24:**
```
.1        - Firewalla Gold (gateway)
.10-.250  - DHCP pool (guest devices)
```

### Appendix C: Default Credentials Reference

**⚠️ SECURITY WARNING: Change all default credentials immediately!**

```
Firewalla Gold:
├─ Web/App: Email-based authentication
├─ SSH: Disabled by default (enable carefully)
└─ Default IP: Varies (assigned during setup)

SG3218-M2 Switch:
├─ Web: https://192.168.1.210
├─ Username: administrator (NOT admin!)
├─ Password: [User-configured during setup]
└─ SSH: Same credentials

Omada Controller (Software):
├─ Web: https://192.168.1.47:8043
├─ Username: [User-configured email]
├─ Password: [User-configured]
└─ MongoDB: Port 27217 (localhost only)

EAP773 Access Points:
├─ Management: Via Omada Controller (adopted)
├─ Standalone IP: DHCP (if not adopted)
└─ Default: admin/admin (CHANGE IMMEDIATELY)

Proxmox VE:
├─ Web: https://192.168.1.137:8006
├─ Username: root@pam
├─ Password: [User-configured]
└─ SSH: Same credentials

TrueNAS:
├─ Web: https://192.168.1.10 (current) → 10.10.40.10 (future)
├─ Username: [User-configured]
└─ Password: [User-configured]
```

**Post-Deployment Security Checklist:**
```
□ All default passwords changed
□ Strong passwords (>16 chars, mixed case, symbols)
□ SSH key authentication enabled (password disabled)
□ HTTPS certificates verified (no self-signed in production)
□ Management interfaces on VLAN 1 only
□ Firewall rules restrict management access to admin IPs
□ Two-factor authentication enabled (where supported)
□ Regular password rotation (quarterly)
```

### Appendix D: Acronyms and Terminology

```
ACL      - Access Control List
AP       - Access Point (EAP773)
DHCP     - Dynamic Host Configuration Protocol
FWG      - Firewalla Gold
HA       - High Availability
IGMP     - Internet Group Management Protocol
IoT      - Internet of Things
IPAM     - IP Address Management
iSCSI    - Internet Small Computer Systems Interface
L2       - Layer 2 (Data Link Layer)
L3       - Layer 3 (Network Layer)
LACP     - Link Aggregation Control Protocol (802.3ad)
LAG      - Link Aggregation Group
LAN      - Local Area Network
LXC      - Linux Container
mDNS     - Multicast DNS (Bonjour/Zeroconf)
MTU      - Maximum Transmission Unit
NAT      - Network Address Translation
NFS      - Network File System
NIC      - Network Interface Card
Omada    - TP-Link SDN management platform
PBR      - Policy-Based Routing
PCIe     - Peripheral Component Interconnect Express
PoE      - Power over Ethernet (802.3af/at/bt)
Proxmox  - Proxmox Virtual Environment (hypervisor)
PVID     - Port VLAN ID (native/untagged VLAN)
QoS      - Quality of Service
RSTP     - Rapid Spanning Tree Protocol
SDN      - Software Defined Networking
SFP+     - Small Form-factor Pluggable (10G)
SMB      - Server Message Block (file sharing)
SNMP     - Simple Network Management Protocol
SSID     - Service Set Identifier (WiFi network name)
STP      - Spanning Tree Protocol
TrueNAS  - Open-source NAS operating system
VLAN     - Virtual Local Area Network (802.1Q)
VM       - Virtual Machine
VPN      - Virtual Private Network
WAN      - Wide Area Network (Internet connection)
WPA3     - Wi-Fi Protected Access 3
```

---

## Document Version History

```
v2.0 - 2025-11-06
- Combined original Firewalla-based plan with infrastructure optimization plan
- Unified VLAN scheme (9 VLANs total)
- Integrated Proxmox cluster improvements (Corosync dual-link)
- Added comprehensive implementation timeline (8 weeks)
- Included detailed hardware fix procedures (Proxmox2 NIC)
- Enhanced security policy matrix
- Added monitoring and operational procedures
- Comprehensive testing and validation checklists

v1.0 - [Earlier Date - Original Firewalla Plan]
- Initial architecture design
- Basic VLAN segmentation (VLANs 1, 10, 20, 30)
- Firewalla Gold dual-WAN configuration
- Wi-Fi 7 AP deployment
- Basic security policies
```

---

**End of Unified Network Architecture and Modernization Plan**

*This document serves as the authoritative guide for network infrastructure design, implementation, operation, and future expansion.*
