# PROXMOX CLUSTER HIGH AVAILABILITY AUDIT REPORT
Generated: November 6, 2025 - 17:35 CST

## EXECUTIVE SUMMARY

### CRITICAL ISSUES REQUIRING IMMEDIATE ATTENTION
🔴 **CRITICAL**: Proxmox node (192.168.1.137) is OFFLINE and unreachable
🔴 **CRITICAL**: No fencing configuration - HA reliability compromised
🟡 **WARNING**: Cluster operating with 2/3 nodes - reduced redundancy
🟡 **WARNING**: Non-HA containers on offline node are unavailable

### OVERALL CLUSTER HEALTH: ⚠️ DEGRADED BUT OPERATIONAL

---

## 1. CLUSTER CONFIGURATION

### Current Status
- **Cluster Name**: homelab-cluster
- **Total Nodes**: 3 (designed)
- **Online Nodes**: 2 (proxmox2, proxmox3)
- **Offline Nodes**: 1 (proxmox @ 192.168.1.137)
- **Quorum Status**: ✅ QUORATE (2 of 3 votes)
- **Expected Votes**: 3
- **Minimum Quorum**: 2

### Node Details
| Node | IP | Status | Role | Uptime |
|------|-------|--------|------|--------|
| proxmox | 192.168.1.137 | 🔴 OFFLINE | Former primary | DOWN |
| proxmox2 | 192.168.1.125 | ✅ ONLINE | Active | 1h 17m |
| proxmox3 | 192.168.1.126 | ✅ ONLINE | HA Master | 1h 32m |

### Corosync Configuration
- **Transport**: knet (Kronosnet)
- **Secure auth**: Enabled
- **Config Version**: 5
- **Ring ID**: 2.919

**⚠️ ISSUE**: Node 1 (proxmox) link down since 17:25, failed ARP resolution

---

## 2. HIGH AVAILABILITY (HA) ASSESSMENT

### HA Service Status: ✅ FUNCTIONING CORRECTLY

**HA Master**: proxmox3 (active)
**Local Resource Managers (LRM)**:
- proxmox: ❌ DEAD (old timestamp)
- proxmox2: ✅ Active
- proxmox3: ✅ Active

### HA-Protected Services (7 total)
| Service | Current Node | Status | Max Restart | Max Relocate |
|---------|-------------|--------|-------------|--------------|
| ct:100 (InfluxDB) | proxmox2 | ✅ Started | 2 | 1 |
| ct:113 (PostgreSQL) | proxmox3 | ✅ Started | 3 | 2 |
| ct:116 | proxmox2 | ✅ Started | 3 | 2 |
| ct:122 (Zigbee2MQTT) | proxmox3 | ✅ Started | 3 | 2 |
| ct:130 (MQTT-prod) | proxmox3 | ✅ Started | 3 | 2 |
| ct:131 | proxmox2 | ✅ Started | 2 | 2 |
| ct:1250 | proxmox2 | ✅ Started | 3 | 2 |

**✅ SUCCESS**: All HA services automatically migrated from offline node

### HA Configuration Gaps

#### 🔴 CRITICAL: No Fencing Configured
**Risk**: Split-brain scenarios, data corruption, service conflicts
**Impact**: HA cannot safely recover from all failure scenarios
**Recommendation**: IMPLEMENT FENCING IMMEDIATELY

**Fencing Options**:
1. **Hardware Watchdog** (Currently enabled but not configured for fencing)
2. **IPMI/iLO fencing** (Requires BMC/IPMI on each node)
3. **Network fencing** (Requires managed switches with SNMP)

#### 🟡 No HA Groups Configured
**Impact**: Cannot define node preferences or affinity rules
**Recommendation**: Consider creating HA groups for:
- Production services (prefer specific nodes)
- Development services (lower priority)
- Critical infrastructure (anti-affinity rules)

---

## 3. STORAGE CONFIGURATION

### Shared Storage (HA-Compatible) ✅
| Storage | Type | Server | Size | Usage | Content |
|---------|------|--------|------|-------|---------|
| TrueNas_NVMe | NFS | 192.168.1.98 | 900GB | 83% (738GB) | images, rootdir, backups |
| Truenas_jbod | NFS | 192.168.1.98 | 1.6TB | 18% (285GB) | all content types |

**✅ STRENGTH**: Shared NFS storage enables seamless VM/CT migration
**🟡 WARNING**: NVMe storage is 83% full - plan capacity expansion

### Local Storage (Node-Specific)
| Storage | Type | Content | HA Compatible |
|---------|------|---------|---------------|
| local-lvm | LVM-thin | images, rootdir | ❌ No (local only) |
| local | Directory | ISO, templates, backups | ❌ No (local only) |

**⚠️ RISK**: VMs/CTs on local storage cannot be migrated automatically

### Storage Recommendations
1. ✅ **Shared storage properly configured** for HA workloads
2. 🔴 **Single point of failure**: TrueNAS server (192.168.1.98)
3. 🟡 **No storage replication** between TrueNAS and local storage
4. 🟡 **Monitor NVMe capacity** - approaching 85% threshold

---

## 4. BACKUP CONFIGURATION

### Backup Jobs: ✅ WELL CONFIGURED

**5 Active Backup Jobs**:
1. **Daily Production** (21:00): VMs 104,101,108,102,103,114,115,100
2. **Weekly Full** (Sun 01:00): VMs 103,104,102,108,101,114,115,100
3. **Weekly All** (Sun 01:00): All VMs/CTs
4. **Critical Daily** (01:00): VMs 114,125,124 (14 days retention)
5. **Dev Weekly** (Sun 03:00): VMs 128,118,123,127,129,130

### Backup Retention
- **Standard**: 7 daily, 4 weekly, 3 monthly
- **Critical**: 14 daily, 8 weekly, 6 monthly
- **Dev**: 3 daily, 2 weekly, 1 monthly

### Backup Storage
- **Target**: Truenas_jbod (NFS share)
- **Compression**: zstd
- **Mode**: snapshot
- **Notification**: failure (always for critical)

**✅ STRENGTHS**:
- Good retention policies
- Separation of critical and dev workloads
- Compression enabled

**⚠️ RISKS**:
- Backups on same NFS server as production (no offsite)
- No backup verification/testing documented
- Single backup destination

---

## 5. NETWORK CONFIGURATION

### Primary Network (vmbr0)
- **Bridge**: vmbr0 on all nodes
- **Subnet**: 192.168.1.0/24
- **Gateway**: 192.168.1.1
- **VLAN-Aware**: Yes (VIDs 2-4094)

### SDN Configuration ✅
- **Zone**: internal (simple type)
- **VNet**: internal (alias: int)
- **IPAM**: pve
- **Subnet**: 192.168.5.1/24 (DHCP: .10-.50)
- **Status**: Configured and functional

### Network Redundancy Assessment

**❌ CRITICAL GAPS**:
1. **Single network path** - no bonding/redundancy
2. **No separate cluster network** - all traffic on same network
3. **No dedicated migration network**

**Recommendations**:
1. Implement network bonding (bond0) for redundancy
2. Consider separate VLAN for cluster traffic (corosync)
3. Configure dedicated migration network for live migrations

---

## 6. VM/CONTAINER DISTRIBUTION

### Distribution Analysis
**Total VMs/Containers**: ~35 across cluster

**Current Distribution** (post-node failure):
- **proxmox**: Unknown (node offline) - ~12 VMs/CTs inaccessible
- **proxmox2**: Running majority of HA + migrated services
- **proxmox3**: Running critical services (HA master)

**Containers on Offline Node** (STATUS: UNKNOWN):
- grafana (192.168.1.140)
- cloudflared (192.168.1.100)
- Others (non-HA protected)

**⚠️ IMBALANCE CONCERNS**:
1. No documented balancing strategy
2. Load concentrated on proxmox2 after migration
3. No anti-affinity rules for redundant services

---

## 7. WATCHDOG & FENCING

### Watchdog Status: ✅ ENABLED
- **Service**: watchdog-mux (active on all nodes)
- **Timeout**: 10 minutes
- **Purpose**: Prevent runaway processes from blocking HA

**✅ FIXED**: InfluxDB metrics timeout (5s) prevents watchdog expiration

### Fencing Status: ❌ NOT CONFIGURED

**CRITICAL REQUIREMENT FOR PRODUCTION HA**:
Without fencing, Proxmox HA cannot:
- Safely recover from split-brain scenarios
- Guarantee service exclusivity
- Prevent data corruption during failover

**Action Required**: Implement one of:
1. IPMI/iLO hardware fencing
2. Watchdog-based fencing
3. Network-based fencing (requires managed infrastructure)

---

## 8. SINGLE POINTS OF FAILURE (SPOF)

### Critical SPOFs Identified

#### 🔴 Infrastructure SPOFs
1. **TrueNAS Storage Server** (192.168.1.98)
   - Hosts all shared storage
   - All HA VMs depend on it
   - No redundancy or failover

2. **Network Infrastructure**
   - Single network path per node
   - No bonded interfaces
   - Single switch dependency (implied)

3. **Gateway** (192.168.1.1)
   - Single default route
   - No redundant gateway protocol

#### 🔴 Configuration SPOFs
1. **No Fencing** - HA incomplete without it
2. **Backup Storage** - Same server as production
3. **Quorum** - Currently vulnerable (2/3 nodes)

#### 🟡 Operational SPOFs
1. **Offline Node** - Reduces cluster redundancy to minimum
2. **HA Master** - Single master (normal, but watch for failures)

---

## 9. RESOURCE UTILIZATION

### proxmox2 (192.168.1.125)
- **CPU**: Low load
- **Memory**: Moderate usage (hosting HA migrations)
- **Disk**: Adequate
- **Containers**: 11 running

### proxmox3 (192.168.1.126)
- **CPU**: Low load (0.81 avg)
- **Memory**: 6.4GB / 31GB (20% used)
- **Disk**: Local: 5% used, NFS: 83%/19%
- **Containers**: 8 running
- **Role**: HA Master (current)

**✅ CAPACITY**: Adequate resources on remaining nodes
**⚠️ BALANCE**: Load shifted to proxmox2 after migration

---

## 10. CRITICAL RECOMMENDATIONS

### IMMEDIATE ACTIONS (Within 24 hours)

#### 1. 🔴 RESTORE PROXMOX NODE (Priority 1)
**Issue**: Primary node offline, cluster operating at minimum
**Actions**:
- **Physical access required** - node not responding to network
- Check console/monitor for boot errors
- Verify network cable and port connectivity
- Check for kernel panic or filesystem issues
- If network config issue, use emergency console access

**Troubleshooting Steps**:
```bash
# From proxmox console (physical access):
1. Check boot logs: journalctl -xb
2. Check network: ip addr show; ip link show
3. Check interfaces: cat /etc/network/interfaces
4. Verify source directive exists: grep "source /etc/network/interfaces.d" /etc/network/interfaces
5. Test corosync: systemctl status corosync pve-cluster
6. Check cluster communication: pvecm status
```

#### 2. 🔴 IMPLEMENT FENCING (Priority 1)
**Risk**: Without fencing, HA cannot prevent split-brain
**Options** (choose one):
1. **Watchdog Fencing** (Simplest):
   ```bash
   # On each node:
   echo "watchdog-device /dev/watchdog" >> /etc/pve/ha/fence.cfg
   ```

2. **IPMI Fencing** (Recommended if hardware supports):
   ```bash
   # Configure IPMI credentials per node
   pvesh set /nodes/{node}/hardware/ipmi ...
   ```

#### 3. 🟡 MONITOR STORAGE CAPACITY
**Action**: TrueNAS NVMe at 83% - plan expansion
```bash
# Set up monitoring alerts at 85%, 90%, 95%
# Review large/old files for cleanup
# Plan capacity expansion
```

### SHORT-TERM IMPROVEMENTS (Within 1 week)

#### 4. Network Redundancy
- Implement bonded network interfaces (bond0)
- Configure separate cluster network (VLAN)
- Set up dedicated migration network

#### 5. Backup Strategy Enhancement
- Configure offsite backup replication
- Implement backup verification testing
- Document restore procedures

#### 6. HA Groups Configuration
```bash
# Create HA groups for workload segregation
# Production group (higher priority)
# Development group (lower priority)
# Anti-affinity for redundant services
```

#### 7. Storage Redundancy
- **Consider**: TrueNAS HA pair or clustered storage
- **Alternative**: Ceph distributed storage
- **Minimum**: Regular TrueNAS backups to separate location

### LONG-TERM ENHANCEMENTS (Within 1 month)

#### 8. Infrastructure Improvements
- Redundant network switches
- UPS for all nodes and storage
- Out-of-band management (IPMI/iLO)

#### 9. Monitoring & Alerting
- Centralized logging (already have InfluxDB)
- Grafana dashboards for HA metrics
- Alert rules for cluster health

#### 10. Documentation
- HA failover procedures
- Recovery runbooks
- Capacity planning guidelines

---

## 11. HA RESILIENCE SCORE

### Current Configuration: ⚠️ 6.5/10

| Category | Score | Status |
|----------|-------|--------|
| Cluster Quorum | 6/10 | ⚠️ Degraded (2/3 nodes) |
| HA Services | 9/10 | ✅ Working well |
| Storage | 7/10 | ✅ Shared storage, ⚠️ SPOF |
| Networking | 5/10 | ⚠️ No redundancy |
| Fencing | 0/10 | 🔴 Not configured |
| Backups | 8/10 | ✅ Good policies, ⚠️ SPOF |
| Monitoring | 7/10 | ✅ Basic monitoring |
| Documentation | ?/10 | ⚠️ Not assessed |

**Target Score**: 8.5/10 (Production-Ready HA)

**To reach target**:
- Fix offline node (+1.0)
- Implement fencing (+1.5)
- Add network redundancy (+0.5)
- Diversify backup storage (+0.5)
- Add TrueNAS redundancy (+1.0)

---

## 12. SUMMARY

### What's Working Well ✅
1. HA services migrated successfully during node failure
2. Cluster maintained quorum
3. Shared storage enables seamless migration
4. Comprehensive backup strategy
5. Watchdog protection configured
6. InfluxDB metrics timeout prevents cascading failures

### Critical Gaps 🔴
1. **Proxmox node offline** - immediate recovery required
2. **No fencing** - HA incomplete and risky
3. **Storage SPOF** - single TrueNAS dependency
4. **Network SPOF** - no redundancy
5. **Reduced cluster capacity** - operating at minimum

### Next Steps
1. **IMMEDIATE**: Restore proxmox node (physical access required)
2. **IMMEDIATE**: Configure fencing
3. **SHORT-TERM**: Implement network redundancy
4. **SHORT-TERM**: Enhance backup strategy
5. **LONG-TERM**: Address storage redundancy

---

## APPENDIX A: CLUSTER COMMANDS REFERENCE

### Check Cluster Status
```bash
pvecm status                    # Cluster status
ha-manager status               # HA service status
pvecm nodes                     # Node list
pvesh get /cluster/resources    # All resources
```

### HA Management
```bash
ha-manager add ct:100           # Add HA protection
ha-manager remove ct:100        # Remove HA protection
ha-manager set ct:100 --state started
ha-manager migrate ct:100 proxmox2
```

### Fencing
```bash
pvesh get /nodes/{node}/hardware/ipmi  # Check IPMI status
```

### Node Recovery
```bash
pvecm delnode proxmox           # Remove dead node (if unrecoverable)
pvecm add --force               # Re-add node to cluster
```

---

END OF REPORT
