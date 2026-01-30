# Network Optimization Plan

**Version:** 1.0
**Created:** 2025-11-06
**Status:** Proposed
**Target Completion:** Q1 2026

---

## Executive Summary

This document outlines a comprehensive network optimization plan for the homelab infrastructure, addressing current limitations and implementing best practices for reliability, performance, and security.

**Current State:** Single VLAN flat network with identified stability issues
**Target State:** Segmented, redundant, monitored network infrastructure

---

## Priority 1: Critical Fixes (Week 1)

### 1.1 Fix Proxmox2 Network Interface ⚠️

**Status:** 🔴 CRITICAL
**Effort:** 2-4 hours
**Risk:** High (requires node downtime)
**Dependencies:** None

**Problem:**
- Proxmox2 using USB Ethernet adapter (enxf44dad055788)
- Built-in NIC (eno1) is DOWN
- Caused cluster instability and node reboot on 2025-11-06

**Solution Steps:**

```bash
# 1. Investigate eno1 failure
ssh root@192.168.1.125 'dmesg | grep eno1'
ssh root@192.168.1.125 'lspci | grep -i ethernet'
ssh root@192.168.1.125 'ethtool eno1'

# 2. Try to bring up eno1
ssh root@192.168.1.125 'ip link set eno1 up'
ssh root@192.168.1.125 'ethtool eno1'

# 3. If hardware failure confirmed:
# Option A: Replace motherboard/NIC card
# Option B: Install quality PCIe 2.5G adapter (Intel i225-V based)

# 4. Update /etc/network/interfaces
# Change from enxf44dad055788 to eno1 or new PCIe interface

# 5. Schedule maintenance window
# - Migrate VMs to other nodes
# - Gracefully shutdown proxmox2
# - Replace hardware
# - Verify network connectivity
# - Rejoin cluster
```

**Testing:**
```bash
# After fix, verify:
ethtool eno1 | grep Speed  # Should show 2500Mb/s
ip -br addr show           # Verify IP on correct interface
pvecm status               # Verify cluster membership
corosync-cfgtool -s        # Check Corosync status
```

**Success Criteria:**
- [ ] eno1 showing "Speed: 2500Mb/s"
- [ ] Link detected: yes
- [ ] No errors in dmesg
- [ ] Cluster quorum maintained for 48+ hours
- [ ] No link down events

### 1.2 Test and Replace Cable on Port 6

**Status:** 🔴 CRITICAL
**Effort:** 30 minutes
**Risk:** Low (hot-swappable)

**Steps:**
```bash
# 1. From switch CLI, test cable
ssh administrator@192.168.1.210
enable
cable-test interface Tw1/0/6

# 2. If cable test shows issues, replace with:
# - Cat6A or Cat7 cable
# - Maximum length 100m (prefer <50m)
# - Shielded if near power lines
# - Proper termination (no kinks)

# 3. Monitor after replacement
show logging | include Tw1/0/6
show interface status Tw1/0/6
```

**Success Criteria:**
- [ ] Cable test passes all pairs
- [ ] No link down events for 7 days
- [ ] No CRC errors in port statistics

### 1.3 Document Proxmox Network Configuration

**Status:** 🟡 IMPORTANT
**Effort:** 1 hour
**Risk:** Low

**Tasks:**
```bash
# Collect current configuration from all nodes
for node in proxmox proxmox2 proxmox3; do
    echo "=== $node ===" | tee node-${node}-network.txt
    ssh root@$node 'cat /etc/network/interfaces' | tee -a node-${node}-network.txt
    ssh root@$node 'ip -br addr' | tee -a node-${node}-network.txt
    ssh root@$node 'ip route' | tee -a node-${node}-network.txt
    ssh root@$node 'ethtool $(ip route | grep default | awk "{print \$5}")' | tee -a node-${node}-network.txt
done
```

---

## Priority 2: High Availability Improvements (Week 2)

### 2.1 Implement Dedicated Corosync Network (VLAN 10)

**Status:** 🟡 HIGH PRIORITY
**Effort:** 4-6 hours
**Risk:** Medium (cluster network change)
**Dependencies:** P1 fixes completed

**Benefits:**
- Isolated cluster heartbeat traffic
- Protection from network congestion
- Easier troubleshooting
- Foundation for future improvements

**Implementation:**

#### Phase 1: VLAN Creation (Omada Controller)
```
1. Login to Omada Controller (https://192.168.1.47:8043)
2. Navigate to Settings → Wired Networks → LAN
3. Create new network:
   - Name: Corosync-Cluster
   - VLAN ID: 10
   - Gateway: 10.10.10.1
   - Subnet: 10.10.10.0/24
   - DHCP: Disabled
4. Apply configuration
```

#### Phase 2: Switch Port Configuration
```
1. Navigate to Devices → SW-Main-SG3218XP
2. Configure ports 2, 6, 7 (Proxmox nodes):
   - Profile: Trunk (802.1Q)
   - Native VLAN: 1 (untagged)
   - Tagged VLANs: 10
3. Apply and verify
```

#### Phase 3: Proxmox VLAN Interface Creation
```bash
# On each Proxmox node, edit /etc/network/interfaces

# Example for proxmox (192.168.1.137):
auto vmbr0.10
iface vmbr0.10 inet static
    address 10.10.10.137/24
    vlan-raw-device vmbr0

# For proxmox2 (192.168.1.125):
auto vmbr0.10
iface vmbr0.10 inet static
    address 10.10.10.125/24
    vlan-raw-device vmbr0

# For proxmox3 (192.168.1.126):
auto vmbr0.10
iface vmbr0.10 inet static
    address 10.10.10.126/24
    vlan-raw-device vmbr0

# Apply configuration:
ifreload -a

# Verify:
ip addr show vmbr0.10
ping -c 3 10.10.10.125
ping -c 3 10.10.10.126
```

#### Phase 4: Add Corosync Link 1
```bash
# On ALL nodes, edit /etc/corosync/corosync.conf
# Add second interface in totem section:

totem {
  cluster_name: homelab-cluster
  config_version: 7  # Increment

  interface {
    linknumber: 0
    bindnetaddr: 192.168.1.0
    mcastport: 5405
  }

  interface {
    linknumber: 1
    bindnetaddr: 10.10.10.0
    mcastport: 5407
  }

  transport: knet

  # Existing HA tuning
  token: 10000
  token_retransmits_before_loss_const: 20
  consensus: 12000
}

# Reload Corosync on all nodes (one at a time):
corosync-cfgtool -R

# Verify both links active:
corosync-cfgtool -s
```

**Testing:**
```bash
# Disable VLAN 1 on one node temporarily to verify failover
ip link set vmbr0 down

# Cluster should remain quorate using VLAN 10
pvecm status

# Restore
ip link set vmbr0 up
```

**Success Criteria:**
- [ ] VLAN 10 created and propagated
- [ ] All Proxmox nodes have 10.10.10.x addresses
- [ ] Ping works across VLAN 10
- [ ] Corosync shows 2 active links
- [ ] Cluster survives single link failure
- [ ] No increase in cluster latency

### 2.2 Network Monitoring Setup

**Status:** 🟡 HIGH PRIORITY
**Effort:** 3-4 hours
**Risk:** Low

**Components:**
1. **SNMP Monitoring** (Switch and APs)
2. **Corosync Health Checks** (Automated)
3. **Link Quality Monitoring** (Interface statistics)

#### 2.2.1 Enable SNMP on Switch
```bash
# Via Omada Controller or CLI:
ssh administrator@192.168.1.210
enable
configure
snmp-server community public ro
snmp-server host 192.168.1.110 public  # Your monitoring server
snmp-server enable traps
exit

# Test from monitoring server:
snmpwalk -v2c -c public 192.168.1.210 system
```

#### 2.2.2 Corosync Monitoring Script
```bash
#!/bin/bash
# /usr/local/bin/monitor-corosync.sh

LOG="/var/log/corosync-health.log"
ALERT_EMAIL="admin@example.com"

check_cluster() {
    # Check quorum
    if ! pvecm status | grep -q "Quorate.*Yes"; then
        echo "[$(date)] CRITICAL: Cluster not quorate!" | tee -a $LOG
        # Send alert
        return 1
    fi

    # Check Corosync ring status
    if corosync-cfgtool -s | grep -q "FAULTY"; then
        echo "[$(date)] WARNING: Corosync link faulty!" | tee -a $LOG
        return 1
    fi

    # Check all nodes online
    EXPECTED_NODES=3
    ONLINE_NODES=$(pvecm nodes | grep -c "online")
    if [ $ONLINE_NODES -lt $EXPECTED_NODES ]; then
        echo "[$(date)] WARNING: Only $ONLINE_NODES/$EXPECTED_NODES nodes online" | tee -a $LOG
        return 1
    fi

    return 0
}

check_cluster
exit $?
```

```bash
# Install as cron job on all Proxmox nodes:
echo "*/5 * * * * /usr/local/bin/monitor-corosync.sh" | crontab -

# Make executable:
chmod +x /usr/local/bin/monitor-corosync.sh
```

#### 2.2.3 Interface Statistics Monitoring
```bash
#!/bin/bash
# /usr/local/bin/check-interface-errors.sh

INTERFACE="vmbr0"
LOG="/var/log/interface-errors.log"

# Get current error counts
ERRORS=$(ip -s link show $INTERFACE | awk '/RX:/{getline; print $3}')
DROPS=$(ip -s link show $INTERFACE | awk '/RX:/{getline; print $4}')

# Log if non-zero
if [ "$ERRORS" -gt 0 ] || [ "$DROPS" -gt 0 ]; then
    echo "[$(date)] Interface $INTERFACE - Errors: $ERRORS, Drops: $DROPS" | tee -a $LOG
fi

# Check link status
if ! ethtool $INTERFACE | grep -q "Link detected: yes"; then
    echo "[$(date)] CRITICAL: $INTERFACE link down!" | tee -a $LOG
fi
```

**Success Criteria:**
- [ ] SNMP queries returning data
- [ ] Monitoring scripts running every 5 minutes
- [ ] Logs being generated
- [ ] Alerts triggering on test failures

---

## Priority 3: Network Segmentation (Month 1)

### 3.1 VLAN Strategy Implementation

**Status:** 🟡 MEDIUM PRIORITY
**Effort:** 8-12 hours
**Risk:** Medium (network redesign)

**Proposed VLAN Scheme:**

| VLAN ID | Name | Subnet | Gateway | Purpose | Firewall Rules |
|---------|------|--------|---------|---------|----------------|
| 1 | Management | 192.168.1.0/24 | 192.168.1.1 | Switch, APs, Omada | Restricted to admin IPs |
| 10 | Corosync | 10.10.10.0/24 | None | Cluster heartbeat | Isolated (no routing) |
| 20 | Hypervisor | 10.20.20.0/24 | 10.20.20.1 | Proxmox management | Restricted to admin IPs |
| 30 | VMs-Trusted | 10.30.30.0/24 | 10.30.30.1 | Production VMs/LXCs | Allow to internet, DB |
| 40 | Storage | 10.40.40.0/24 | 10.40.40.1 | TrueNAS, iSCSI, NFS | Isolated to hypervisors |
| 50 | IoT | 10.50.50.0/24 | 10.50.50.1 | Smart home devices | No access to other VLANs |
| 99 | Guest | 10.99.99.0/24 | 10.99.99.1 | Guest WiFi | Internet only |

**Migration Plan:**

#### Phase 1: Planning (Week 1)
- [ ] Document all current IPs and services
- [ ] Design VLAN assignment for each device
- [ ] Create firewall rule matrix
- [ ] Schedule maintenance window

#### Phase 2: VLAN Creation (Week 2)
- [ ] Create VLANs in Omada Controller
- [ ] Configure VLAN interfaces on Firewalla
- [ ] Test basic connectivity

#### Phase 3: Gradual Migration (Week 3-4)
```
Day 1: IoT devices (low risk)
Day 2: Guest network
Day 3: Storage network
Day 4: Hypervisor management
Day 5: VM/LXC migration
Day 6: Testing and validation
Day 7: Cleanup and documentation
```

#### Phase 4: Port Assignment
```
Port 1: Trunk (VLAN 1, 20, 30, 40, 50, 99) - Firewalla
Port 2: Trunk (VLAN 1, 10, 20, 40) - Proxmox3
Port 3: Access VLAN 1 - Workstation
Port 4: Trunk (VLAN 1, 50) - Upstairs AP
Port 5: Access VLAN 40 - TrueNAS
Port 6: Trunk (VLAN 1, 10, 20, 40) - Proxmox2
Port 7: Trunk (VLAN 1, 10, 20, 40) - Proxmox
Port 8: Trunk (VLAN 1, 50) - Downstairs AP
Port 9-14: Access VLAN 1 (Available)
Port 15: Access VLAN 50 - SLZB-06
Port 16: Access VLAN 50 - E-eye Alarm
```

**Rollback Plan:**
```bash
# If issues occur, revert to single VLAN:
1. Remove VLAN tags from switch ports
2. Set all ports to Access mode VLAN 1
3. Remove VLAN interfaces from Proxmox nodes
4. Document issues for later resolution
```

### 3.2 Firewall Rules Matrix

**Inter-VLAN Access Control:**

| Source VLAN | Destination VLAN | Allowed Protocols | Purpose |
|-------------|------------------|-------------------|---------|
| Management (1) | All | All | Admin access |
| Hypervisor (20) | Storage (40) | NFS, iSCSI, SMB | Storage access |
| VMs-Trusted (30) | Storage (40) | NFS, SMB | Application storage |
| VMs-Trusted (30) | Internet | HTTP, HTTPS, DNS | External access |
| IoT (50) | Internet | HTTP, HTTPS, MQTT | Cloud services |
| IoT (50) | VMs-Trusted (30) | MQTT, HTTP | Home Assistant |
| Guest (99) | Internet | HTTP, HTTPS, DNS | Guest internet |
| **All Others** | **Denied by default** | **- | Security |

---

## Priority 4: Performance Optimization (Month 2)

### 4.1 LACP Link Aggregation for TrueNAS

**Status:** 🟢 LOW PRIORITY (Nice to have)
**Effort:** 2-3 hours
**Risk:** Low

**Benefits:**
- 5 Gbps aggregate bandwidth (2.5G × 2)
- Automatic failover
- Load balancing

**Implementation:**

#### Switch Configuration (Omada)
```
1. Navigate to Devices → SW-Main-SG3218XP → Port Config
2. Create LAG1:
   - Name: TrueNAS-LAG
   - Mode: LACP (802.3ad)
   - Ports: 5, 9
   - Hash Algorithm: Layer 2+3
3. Apply configuration
```

#### TrueNAS Configuration
```
1. Login to TrueNAS web interface
2. Network → Interfaces → Add
3. Create bond0:
   - Type: Link Aggregation
   - Members: igb0, igb1 (or equivalent)
   - Protocol: LACP
   - Transmit Hash: LAYER2+3
4. Configure IP: 192.168.1.x (or VLAN 40 after segmentation)
5. Test thoroughly before production
```

**Testing:**
```bash
# On TrueNAS:
ifconfig bond0

# From Proxmox:
iperf3 -c <truenas-ip> -t 60 -P 4

# Expected: ~4+ Gbps aggregate throughput
```

### 4.2 Jumbo Frames Configuration

**Status:** 🟢 LOW PRIORITY
**Effort:** 2 hours
**Risk:** Low

**When to implement:** After VLAN 40 (Storage) is created

**Configuration:**

```bash
# Switch (Omada Controller)
Settings → Switch → Jumbo Frame: 9000 bytes

# TrueNAS
Network → Global Configuration → MTU: 9000

# Proxmox nodes (on storage network only)
auto vmbr0.40
iface vmbr0.40 inet static
    address 10.40.40.137/24
    mtu 9000
    vlan-raw-device vmbr0

# Verify:
ping -M do -s 8972 -c 4 10.40.40.x  # 8972 + 28 = 9000
```

**Benefits:**
- Reduced CPU overhead
- Improved storage throughput
- Better large file transfer performance

---

## Priority 5: Long-term Improvements (Q1 2026)

### 5.1 10G Uplink Planning

**Future Expansion:**

**Option A: 10G to TrueNAS**
- Add 10G SFP+ NIC to TrueNAS
- Direct attach copper (DAC) to switch port 17
- Dedicated high-speed storage network

**Option B: 10G Switch Uplink**
- Purchase second switch with 10G capabilities
- Use ports 17-18 for inter-switch trunk
- Expand network capacity

**Option C: 10G to Backup Server**
- Dedicated 10G link for backup traffic
- Offload backup from main network

### 5.2 Network Documentation Automation

**Tools to implement:**
- Netbox for IP address management (IPAM)
- LibreNMS for monitoring
- Oxidized for config backup
- Grafana for visualization

---

## Implementation Timeline

### Week 1: Critical Fixes
- Day 1-2: Fix Proxmox2 NIC
- Day 3: Cable testing and replacement
- Day 4-5: Testing and validation

### Week 2: HA Improvements
- Day 1-2: VLAN 10 creation and testing
- Day 3-4: Dual Corosync links
- Day 5: Monitoring setup

### Month 1: Network Segmentation
- Week 1: Planning and design
- Week 2: VLAN creation
- Week 3-4: Gradual migration

### Month 2: Performance
- Week 1: LACP configuration
- Week 2: Jumbo frames testing
- Week 3-4: Final optimization and tuning

---

## Risk Mitigation

### High-Risk Activities

**Activity:** Proxmox2 NIC replacement
**Risk:** Extended downtime, data loss
**Mitigation:**
- Schedule during maintenance window
- Migrate all VMs before shutdown
- Test network before bringing back online
- Have USB Ethernet as fallback

**Activity:** Corosync network changes
**Risk:** Cluster split-brain
**Mitigation:**
- Change config_version incrementally
- Reload nodes one at a time
- Maintain quorum during changes
- Have console access ready

**Activity:** VLAN migration
**Risk:** Service disruption
**Mitigation:**
- Detailed rollback plan
- Migrate one VLAN at a time
- Test each step thoroughly
- Keep management access separate

---

## Success Metrics

### Reliability
- [ ] Zero unplanned node reboots (30 days)
- [ ] 99.9% cluster quorum uptime
- [ ] Zero network-related incidents (30 days)

### Performance
- [ ] Corosync latency < 1ms average
- [ ] No packet loss on cluster links
- [ ] Storage throughput > 200 MB/s (per client)

### Security
- [ ] All VLANs segmented with firewall rules
- [ ] IoT devices isolated from trusted network
- [ ] Management access restricted by IP

---

## Resources Required

### Hardware
- 2× PCIe 2.5G NIC (if needed): ~$60
- 2× Cat6A/Cat7 cables: ~$30
- Optional: 10G SFP+ modules and DAC: ~$100

### Software
- Existing: Omada Controller, Proxmox, Firewalla
- Optional: LibreNMS, Netbox (free)

### Time
- Network administrator: 40-60 hours
- Testing/validation: 20-30 hours

---

*This optimization plan is a living document and should be updated as changes are implemented.*
