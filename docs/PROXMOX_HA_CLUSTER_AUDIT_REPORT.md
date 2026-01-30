# Proxmox HA Cluster Audit Report
**Date:** 2025-11-10
**Audited by:** Claude Code
**Cluster:** homelab-cluster

## Executive Summary

This audit identified **critical high-availability gaps** that led to complete service outage when proxmox (192.168.1.137) required reboot this morning. The root cause was both Traefik instances running on the same non-HA-managed host.

### Critical Issues Found:
1. ✗ **Both Traefik instances on same host** (proxmox/192.168.1.137)
2. ✗ **Traefik not managed by HA** - only onboot, no automatic failover
3. ✗ **Proxmox experienced unclean shutdown** with filesystem corruption
4. ✗ **Possible memory hardware error** detected (IBECC MEMORY ERROR)
5. ✗ **No HA groups configured** for resource distribution
6. ✗ **Imbalanced HA resource distribution** across cluster

---

## 1. DNS Resolution Status ✓

### Finding: DNS Working But Slow
- **Primary DNS** (192.168.1.253 - AdGuard on proxmox3): Operational but slow response
- **Secondary DNS** (192.168.1.224 - AdGuard-2 on proxmox2): Fast and reliable
- **systemd-resolved**: Properly disabled on all nodes - no conflicts

### Recommendation:
- Monitor AdGuard (1250) performance on proxmox3
- Consider investigating why primary DNS is slower than secondary

---

## 2. Traefik HA Configuration ✗ CRITICAL

### Current Configuration:
```
Container 110 (traefik)    - Node: proxmox (192.168.1.137)  - IP: 192.168.1.110
Container 121 (traefik-2)  - Node: proxmox (192.168.1.137)  - IP: 192.168.1.103
```

### Issues:
- **Both on same host** - Single point of failure (CONFIRMED during this morning's reboot)
- **Not HA managed** - No automatic failover
- **Only onboot=1** - Manual intervention required on failure

### Impact:
When proxmox rebooted at 08:36 this morning, ALL Traefik services were down, causing:
- Complete loss of reverse proxy access
- All internal services (*.internal.lakehouse.wtf) unreachable
- No automatic recovery

---

## 3. HA Resource Distribution Analysis

### Current HA Managed Resources:
| VMID | Name | Node | Purpose |
|------|------|------|---------|
| 100 | influxdb | proxmox2 | Time-series database |
| 113 | postgresql | proxmox3 | Database |
| 116 | adguard-2 | proxmox2 | Secondary DNS |
| 122 | zigbee2mqtt | proxmox3 | IoT gateway |
| 130 | mqtt-prod | proxmox3 | Message broker |
| 131 | netbox | proxmox2 | IPAM/DCIM |
| 1250 | adguard | proxmox3 | Primary DNS |

### Distribution by Node:
```
proxmox  (192.168.1.137): 0 HA resources ⚠️
proxmox2 (192.168.1.125): 3 HA resources
proxmox3 (192.168.1.126): 4 HA resources ⚠️
```

### Critical Non-HA Services on Proxmox:
```
110 - traefik          ❌ CRITICAL - Should be HA
121 - traefik-2        ❌ CRITICAL - Should be HA
132 - uptime-kuma      ⚠️  Should be HA
134 - kea-dhcp-2       ⚠️  Should be HA (secondary DHCP)
135 - stork-server     ℹ️  Monitoring - less critical
```

---

## 4. HA Groups Configuration ✗

### Current Status:
**NO HA GROUPS CONFIGURED**

### Impact:
- No resource placement constraints
- No guaranteed resource distribution
- Manual rebalancing required
- Risk of resource clustering on single node

---

## 5. Proxmox Reboot Investigation

### Reboot Timeline:
- **Last Boot:** 2025-11-10 01:48
- **Reboot:** 2025-11-10 08:36 (unclean shutdown)
- **Uptime at failure:** ~6 hours 48 minutes

### Evidence of Issues:

#### A. Memory Error Detected:
```
[Mon Nov 10 08:36:35 2025] EDAC igen6 MC0: HANDLING IBECC MEMORY ERROR
```

#### B. Filesystem Corruption (Post-Reboot):
```
Multiple containers with filesystem errors:
- dm-16: ext4_journal_check_start errors
- dm-17: ext4_journal_check_start errors
- dm-14: 3 errors since last fsck
- dm-15: ext4_journal_check_start errors
- dm-19: 2 errors since last fsck
```

### Root Cause Assessment:
**Likely causes (in order of probability):**
1. **Hardware memory error** - IBECC error detected
2. **Unclean power cycle** - filesystem corruption pattern
3. **Manual hard reset** - user intervention

### Immediate Actions Required:
1. Run memtest86+ on proxmox node to verify RAM
2. Run e2fsck on affected container volumes
3. Monitor for recurring memory errors
4. Consider RAM replacement if errors persist

---

## 6. Enterprise-Grade Recommendations

### CRITICAL Priority (Implement Immediately):

#### A. Enable HA Management for Traefik:
```bash
# Add traefik to HA management
ssh root@192.168.1.137 "ha-manager add ct:110 --state started --max_restart 3 --max_relocate 2"
ssh root@192.168.1.137 "ha-manager add ct:121 --state started --max_restart 3 --max_relocate 2"
```

#### B. Configure HA Groups for Resource Distribution:
```bash
# Create HA groups with node preferences
ssh root@192.168.1.137 "pvesh create /cluster/ha/groups -group traefik-group -nodes 'proxmox2:1,proxmox3:1,proxmox:0' -restricted 1"
ssh root@192.168.1.137 "pvesh create /cluster/ha/groups -group backend-group -nodes 'proxmox2:2,proxmox3:1,proxmox:1'"

# Assign resources to groups
ssh root@192.168.1.137 "ha-manager set ct:110 --group traefik-group"
ssh root@192.168.1.137 "ha-manager set ct:121 --group traefik-group"
```

#### C. Verify Container Startup Order:
```bash
# Ensure critical infrastructure starts first
# DNS/DHCP (order 1-2), Traefik (order 3-5), Apps (order 6+)

# Update startup order for Traefik
ssh root@192.168.1.137 "pct set 110 --startup order=3,up=30"
ssh root@192.168.1.137 "pct set 121 --startup order=3,up=30"
```

### HIGH Priority (Implement This Week):

#### D. Add Critical Services to HA:
```bash
# Add uptime-kuma to HA
ssh root@192.168.1.137 "ha-manager add ct:132 --state started --max_restart 3 --max_relocate 2"

# Add kea-dhcp-2 to HA
ssh root@192.168.1.137 "ha-manager add ct:134 --state started --max_restart 3 --max_relocate 2"
```

#### E. Rebalance HA Resources:
```bash
# Move some resources from proxmox3 to proxmox to balance load
# Example: Move mqtt-prod (130) to proxmox
ssh root@192.168.1.137 "ha-manager migrate ct:130 proxmox"
```

#### F. Hardware Diagnostics:
```bash
# Check for memory errors
ssh root@192.168.1.137 "apt-get install memtester -y"
ssh root@192.168.1.137 "memtester 1024M 1"  # Test 1GB

# Monitor for recurring errors
ssh root@192.168.1.137 "watch -n 60 'dmesg -T | grep -i \"ibecc\\|memory error\"'"
```

#### G. Filesystem Repair:
```bash
# Stop affected containers and run e2fsck
# (Do this during maintenance window)
ssh root@192.168.1.137 "pct stop <vmid> && e2fsck -f /dev/mapper/dm-XX"
```

### MEDIUM Priority (Implement This Month):

#### H. Implement Fencing:
```bash
# Configure fence devices for automatic node recovery
# Requires iLO/iDRAC or network-based fencing
```

#### I. Backup Validation:
- Verify all HA resources have automated backups
- Test restore procedures for critical services
- Document recovery time objectives (RTO)

#### J. Monitoring Enhancements:
- Add HA resource state monitoring to Uptime Kuma
- Alert on HA resource migrations
- Monitor cluster quorum status
- Track node resource utilization

---

## 7. Optimal HA Configuration Blueprint

### Recommended HA Groups:

#### Group: critical-infrastructure
**Purpose:** DNS, DHCP, Essential Services
**Nodes:** All nodes, prefer proxmox2/proxmox3
**Resources:**
- ct:116 (adguard-2)
- ct:1250 (adguard)
- ct:133 (kea-dhcp-1)
- ct:134 (kea-dhcp-2)

#### Group: reverse-proxy
**Purpose:** Traefik load balancers
**Nodes:** proxmox2 and proxmox3 ONLY (restricted)
**Resources:**
- ct:110 (traefik)
- ct:121 (traefik-2)

#### Group: databases
**Purpose:** Database services
**Nodes:** All nodes, distributed
**Resources:**
- ct:100 (influxdb)
- ct:113 (postgresql)

#### Group: applications
**Purpose:** Application containers
**Nodes:** All nodes, balanced distribution
**Resources:**
- ct:131 (netbox)
- ct:132 (uptime-kuma)
- Other application containers

### Recommended Resource Distribution:

```
proxmox  (192.168.1.137):
  - ct:110 (traefik) OR ct:121 (traefik-2)  [HA managed]
  - ct:132 (uptime-kuma)                     [HA managed]
  - ct:130 (mqtt-prod)                       [HA managed]
  - Non-critical services

proxmox2 (192.168.1.125):
  - ct:100 (influxdb)                        [HA managed]
  - ct:116 (adguard-2)                       [HA managed]
  - ct:133 (kea-dhcp-1)                      [HA managed]
  - ct:131 (netbox)                          [HA managed]
  - One Traefik instance                     [HA managed]

proxmox3 (192.168.1.126):
  - ct:113 (postgresql)                      [HA managed]
  - ct:1250 (adguard)                        [HA managed]
  - ct:134 (kea-dhcp-2)                      [HA managed]
  - ct:122 (zigbee2mqtt)                     [HA managed]
  - One Traefik instance                     [HA managed]
```

### Startup Order Configuration:

```
Order 1: DNS (AdGuard containers)
Order 2: DHCP (Kea containers)
Order 3: Reverse Proxy (Traefik containers)
Order 4: Databases (InfluxDB, PostgreSQL)
Order 5: Core Services (Netbox, MQTT)
Order 6+: Application containers
```

---

## 8. Testing & Validation Plan

### Phase 1: Pre-Implementation Tests
- [ ] Document current state (screenshots, configs)
- [ ] Backup all container configurations
- [ ] Test backup restore procedure
- [ ] Verify cluster quorum

### Phase 2: Implementation
- [ ] Enable HA for Traefik instances
- [ ] Create HA groups
- [ ] Assign resources to groups
- [ ] Update startup orders
- [ ] Rebalance resources

### Phase 3: Validation Tests
- [ ] Simulate node failure (reboot test)
- [ ] Verify automatic Traefik failover
- [ ] Test internal site accessibility during failover
- [ ] Measure failover time (should be < 2 minutes)
- [ ] Verify resource redistribution
- [ ] Check cluster logs for errors

### Phase 4: Ongoing Monitoring
- [ ] Monitor HA manager logs daily
- [ ] Track resource migrations
- [ ] Alert on failed migrations
- [ ] Monthly disaster recovery drill

---

## 9. Risk Assessment

### Current Risk Level: **HIGH** 🔴

**Single Points of Failure:**
- Traefik (both instances on one host)
- Proxmox node hardware (memory errors detected)

**Impact of Node Failure:**
- **proxmox:** Complete outage of all reverse proxy services
- **proxmox2:** Loss of InfluxDB, AdGuard-2, Netbox, Kea-1
- **proxmox3:** Loss of PostgreSQL, AdGuard-1, MQTT, Zigbee2MQTT

### Target Risk Level: **LOW** 🟢

**After Implementation:**
- No single point of failure for critical services
- Automatic failover for all HA-managed resources
- < 2 minute recovery time for service disruptions
- Proper resource distribution across cluster
- Hardware monitoring and alerting

---

## 10. Maintenance Schedule

### Daily:
- Monitor HA manager status
- Check for memory errors in dmesg
- Verify all HA resources are in expected state

### Weekly:
- Review HA migration logs
- Verify backup completion
- Check cluster resource balance

### Monthly:
- Disaster recovery drill
- Review and update HA policies
- Capacity planning review
- Hardware health check

### Quarterly:
- Full cluster health audit
- Test fence device functionality
- Review and update documentation
- Evaluate HA group configurations

---

## 11. Immediate Action Items (Next 24 Hours)

1. **Enable HA for Traefik** (15 minutes)
   ```bash
   ha-manager add ct:110 --state started --max_restart 3 --max_relocate 2
   ha-manager add ct:121 --state started --max_restart 3 --max_relocate 2
   ```

2. **Run Memory Diagnostics** (30 minutes)
   ```bash
   # Check for additional memory errors
   dmesg -T | grep -i "memory\|ecc\|ibecc" > /tmp/memory_check.log
   ```

3. **Fix Filesystem Errors** (1 hour - maintenance window)
   ```bash
   # Schedule for off-hours
   # Run e2fsck on affected containers
   ```

4. **Create HA Groups** (30 minutes)
   - Configure traefik-group with node restrictions
   - Assign Traefik instances to group

5. **Test Failover** (1 hour)
   - Graceful reboot of proxmox node
   - Verify Traefik automatic migration
   - Confirm service continuity

---

## 12. Success Criteria

- ✓ Both Traefik instances on different nodes
- ✓ All critical services HA-managed
- ✓ HA groups properly configured
- ✓ Resource distribution balanced
- ✓ Automatic failover tested and working
- ✓ No memory errors detected
- ✓ All filesystem errors resolved
- ✓ RTO < 2 minutes for critical services
- ✓ Monitoring and alerting in place

---

## Appendix A: HA Manager Commands Reference

```bash
# View HA status
ha-manager status

# Add resource to HA
ha-manager add ct:VMID --state started --max_restart 3 --max_relocate 2

# Remove resource from HA
ha-manager remove ct:VMID

# Migrate resource to specific node
ha-manager migrate ct:VMID TARGET_NODE

# Set resource group
ha-manager set ct:VMID --group GROUP_NAME

# Create HA group
pvesh create /cluster/ha/groups -group GROUP_NAME -nodes 'node1:PRIORITY,node2:PRIORITY'

# List HA resources
pvesh get /cluster/ha/resources

# List HA groups
pvesh get /cluster/ha/groups
```

---

## Appendix B: Contact Information

**Cluster Details:**
- Name: homelab-cluster
- Nodes: 3
- Quorum: 2/3
- Version: Proxmox VE (check `pveversion`)

**Node IPs:**
- proxmox: 192.168.1.137
- proxmox2: 192.168.1.125
- proxmox3: 192.168.1.126

**Critical Services:**
- Traefik-1: 192.168.1.110 (ct:110)
- Traefik-2: 192.168.1.103 (ct:121)
- AdGuard-1: 192.168.1.253 (ct:1250)
- AdGuard-2: 192.168.1.224 (ct:116)
