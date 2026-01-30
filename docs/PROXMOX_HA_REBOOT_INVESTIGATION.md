# Proxmox HA Cluster Reboot Investigation Report

## Root Cause Identified: Corosync Token Timeouts

### Problem Summary

**Symptom**: Multiple unexpected reboots of Proxmox nodes (137 and 125) throughout Nov 8-9, 2025

**Root Cause**: Corosync cluster communication token timeouts causing HA fencing

### Evidence

#### 1. Corosync Token Timeout Errors (Repeated Pattern)

```
Nov 09 10:33:27 proxmox corosync[2764]: [TOTEM] A processor failed, forming new configuration: token timed out (3650ms), waiting 4380ms for consensus.
Nov 09 10:33:31 proxmox corosync[2764]: [TOTEM] Failed to receive the leave message. failed: 2 3
```

**Frequency**: Occurring every 20-40 minutes throughout the day

**Pattern**: 
- Node 2 (proxmox2 @ 192.168.1.125) failing most frequently
- Sometimes node 3 also fails
- Token timeout threshold: 3650ms

#### 2. HA Fencing Events

```
Nov 08 11:46:02 proxmox2 pve-ha-crm[1084]: node 'proxmox': state changed from 'unknown' => 'fence'
Nov 08 11:46:02 proxmox2 pve-ha-crm[1084]: service 'ct:100': state changed from 'started' to 'fence'
Nov 08 11:47:03 proxmox2 pve-ha-crm[1084]: recover service 'ct:100' from fenced node 'proxmox' to node 'proxmox2'
```

**Consequence**: When corosync token timeout occurs, HA manager fences the "failed" node (reboots it) to prevent split-brain

#### 3. HA Managed Services

7 containers under HA management:
- ct:100, ct:113, ct:116, ct:122, ct:130, ct:131, ct:1250

These services are being migrated between nodes when fencing occurs.

### Technical Analysis

#### Corosync Token Protocol

Corosync uses a token-passing protocol for cluster communication:
1. A token circulates between nodes
2. If a node doesn't pass the token within the timeout period (default ~3000ms), it's considered failed
3. The cluster forms a new configuration without that node
4. HA manager then fences the "failed" node to ensure service consistency

#### Current Configuration

```
Cluster: homelab-cluster
Nodes: 3 (proxmox, proxmox2, proxmox3)
Quorum: 2 of 3 nodes required
Network: 10Gbps (vmbr0)
Token timeout: Using defaults (~3000ms)
```

#### Network Status

- **Speed**: 10000Mb/s
- **Duplex**: Unknown! (255) ⚠️ **Unusual - may indicate network driver/switch issue**
- **Load**: Normal (< 1.0 on all nodes)
- **Memory**: Plenty available (22-27GB free)
- **Cluster Ring**: Currently connected (all 3 nodes)

### Possible Causes

1. **Network Delays/Congestion**
   - Intermittent packet loss
   - Switch buffering/backpressure
   - Network path issues between nodes

2. **Resource Contention** (Less likely given current metrics)
   - CPU scheduling delays
   - I/O wait times
   - Memory pressure (not observed)

3. **Aggressive Timeout Settings**
   - Default 3000ms token timeout may be too short
   - Network variance can cause occasional delays > 3000ms

4. **Network Configuration Issues**
   - Duplex mismatch (showing "Unknown")
   - MTU issues
   - Network driver problems

### Recommendations

#### Immediate Actions (High Priority)

**1. Increase Corosync Token Timeout**

Add to `/etc/pve/corosync.conf`:

```
totem {
  cluster_name: homelab-cluster
  config_version: 6  # Increment this
  token: 10000        # Increase from default 3000ms to 10000ms
  token_retransmits_before_loss_const: 10  # Default is 10
  interface {
    linknumber: 0
  }
}
```

Then sync and restart:
```bash
# On all nodes:
pvecm expected 3
systemctl restart corosync
```

**Benefits**: More tolerance for temporary network delays without triggering fencing

**2. Investigate Network Duplex Issue**

```bash
# Check physical network interface
ethtool enp0s31f6  # Or whatever your physical interface is
```

Look for duplex mismatches between switch and server.

#### Short-term Actions (Medium Priority)

**3. Monitor Corosync Latency**

```bash
# Check ring latency
corosync-cfgtool -s

# Monitor in real-time
journalctl -f -u corosync
```

**4. Check Network Statistics**

```bash
# Look for errors, drops, overruns
ip -s link show vmbr0
```

**5. Test Network Latency Between Nodes**

```bash
# From each node to others
ping -c 100 -i 0.01 192.168.1.125  # Fast ping test
```

#### Long-term Actions (Low Priority)

**6. Consider Dedicated Cluster Network**

If issues persist, configure a separate physical network for cluster traffic (separate from VM traffic)

**7. Upgrade Network Infrastructure**

If switches are old, consider upgrading to newer models with better buffering

**8. Review HA Configuration**

Evaluate if all services need HA, or if some can be static assignments

### Current Status

✅ **Cluster**: Healthy and quorate  
✅ **All Services**: Running correctly  
⚠️ **Token Timeouts**: Ongoing issue  
⚠️ **Duplex Status**: Unknown/problematic  

### Expected Outcome

After increasing token timeout to 10000ms:
- Reduce fencing frequency dramatically
- Allow for normal network variance
- Prevent unnecessary reboots
- Maintain cluster stability

### Risk Assessment

**Risk of increasing timeout**: 
- **Low** - Slightly slower failure detection (10s vs 3s)
- **Acceptable** - Still well within reasonable HA response times
- **Benefit** - Prevents false-positive fencing

**Risk of not fixing**:
- **High** - Continued unexpected reboots
- **Impact** - Service disruptions, container migrations
- **User Experience** - Poor availability despite HA setup

---

**Report Date**: 2025-11-09  
**Investigator**: Claude Code  
**Status**: Root Cause Identified - Fix Recommended
