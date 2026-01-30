# Proxmox Cluster Incident - November 25, 2025

## What Happened

### Timeline
- **08:09:52** - Node 2 (proxmox2 / 192.168.1.125) received a reboot command
- **08:10:48** - Corosync cluster detected node 2 left the quorum (Members went from 3 to 2)
- **08:11:19** - Node 2 rejoined the cluster after reboot
- **08:14:55** - Node 1 (proxmox / 192.168.1.137) began rebooting
- **08:17:13** - Node 1 fully rejoined the cluster
- **Result**: Cluster was running with only 2/3 nodes for ~1 minute, causing performance degradation

### Root Cause
**Cascading reboot event** - When node 2 rebooted unexpectedly, it triggered corosync failover and HA migrations, which caused:
1. **Network congestion** from VM/CT migrations and state sync
2. **Resource exhaustion** on remaining nodes handling the load
3. **Gotify notification timeouts** (seen in logs) - unable to send alerts due to network saturation
4. **Slow response times** across the entire cluster
5. **Secondary reboot** of node 1, likely triggered manually by user attempting to fix the slowness

### Key Evidence
- Node 2 corosync errors: `pmxcfs[937]: [status] crit: cpg_dispatch failed: CS_ERR_LIBRARY`
- Node 1 detected quorum loss: `[QUORUM] Sync left[1]: 2`
- Multiple "Failed to connect to system bus: Broken pipe" errors during shutdown
- Gotify notification failures: "timeout: global" - indicates network was saturated

## Why This Was Bad
1. **Loss of redundancy**: During cascading reboots, cluster ran with insufficient nodes
2. **No fencing** occurred (good!) but caused temporary split-brain risk
3. **Performance degradation**: HA services tried to migrate while nodes were unstable
4. **Network saturation**: All three issues combined overwhelmed the network

## Prevention Strategies

### 1. Prevent Simultaneous Reboots
```bash
# Add to /usr/local/bin/proxmox-safe-reboot.sh (create on all nodes)
#!/bin/bash
LOCK_DIR="/run/proxmox-reboot-lock"
CLUSTER_WAIT=300  # 5 minutes
NODE_NAME=$(hostname)

# Check if another node is rebooting
OTHER_NODES=$(pvesh get /cluster/resources --type node --noborder | grep -v "$NODE_NAME" | grep offline | wc -l)
if [ "$OTHER_NODES" -gt 0 ]; then
    echo "Another node is currently offline, waiting ${CLUSTER_WAIT} seconds for cluster stability..."
    sleep $CLUSTER_WAIT
fi

# Verify quorum before rebooting
if ! pvesh get /cluster/status | grep -q '"quorate":1'; then
    echo "ERROR: Cluster does not have quorum, aborting reboot"
    exit 1
fi

echo "Cluster is stable, proceeding with reboot..."
systemctl reboot
```

Make executable and use instead of direct reboot:
```bash
chmod +x /usr/local/bin/proxmox-safe-reboot.sh
```

### 2. Add Monitoring for Cluster Health

#### Create cluster health monitoring script
```bash
cat > /usr/local/bin/check-cluster-health.sh << 'EOF'
#!/bin/bash
ALERT_EMAIL="root"

# Check cluster quorum status
if ! pvesh get /cluster/status | grep -q '"quorate":1'; then
    echo "CRITICAL: Cluster has lost quorum!" | mail -s "[CRITICAL] Proxmox Cluster Alert" $ALERT_EMAIL
    exit 1
fi

# Check if all nodes are online
EXPECTED_NODES=3
ONLINE_NODES=$(pvesh get /cluster/resources --type node --noborder | grep -c "online")
if [ "$ONLINE_NODES" -lt "$EXPECTED_NODES" ]; then
    echo "WARNING: Only $ONLINE_NODES/$EXPECTED_NODES nodes are online" | mail -s "[WARNING] Proxmox Node Alert" $ALERT_EMAIL
    exit 1
fi

# Check corosync health
if ! corosync-quorumtool -s | grep -q "Quorate: Yes"; then
    echo "CRITICAL: Corosync quorum issue detected!" | mail -s "[CRITICAL] Proxmox Corosync Alert" $ALERT_EMAIL
    exit 1
fi

# Check for high load on any node
HIGH_LOAD=$(pvesh get /cluster/resources --type node --noborder | awk '{if ($3 > 0.8) print $1}')
if [ -n "$HIGH_LOAD" ]; then
    echo "WARNING: High load detected on nodes: $HIGH_LOAD" | mail -s "[WARNING] Proxmox High Load Alert" $ALERT_EMAIL
fi

exit 0
EOF

chmod +x /usr/local/bin/check-cluster-health.sh

# Add to crontab (run every 5 minutes) - deploy to all nodes
echo "*/5 * * * * /usr/local/bin/check-cluster-health.sh" | crontab -
```

### 3. Configure HA Service Delays
```bash
# Set migration delays to prevent immediate migrations during temporary issues
ha-manager set migration migration_delay=120
ha-manager set migration migration_network_threshold=50
```

### 4. Network & Corosync Optimization
```bash
# Edit /etc/corosync/corosync.conf on all nodes
# Increase timeouts for better stability:

totem {
    version: 2
    cluster_name: homelab-cluster
    transport: knet
    token: 10000              # Increase from 3000 to handle brief network issues
    token_retransmits_before_loss_const: 10  # Increase from 6
    join: 60                  # Default
    consensus: 12000          # Increased from 6000
}

# After editing, reload configuration:
systemctl reload corosync
```

### 5. Add Uptime Kuma Monitoring
Create specific monitors for:
- Cluster quorum status (HTTP check on `/api2/json/cluster/status`)
- Individual node health
- Corosync connectivity
- HA service migrations (alert on frequent migrations)

### 6. Document Escalation Procedure

**When cluster issues occur:**
1. **DO NOT** reboot additional nodes until the cluster is stable
2. Check cluster status first: `pvesh get /cluster/status`
3. Verify quorum: `corosync-quorumtool -s`
4. Check which services are migrating: `ha-manager status`
5. Wait for cluster to stabilize (quorate=1, all nodes online)
6. Only then proceed with planned maintenance

## Immediate Actions Taken
✅ Cluster recovered and stable (all 3 nodes online)
✅ Health score: 100/100
✅ All VMs and CTs running normally
✅ Uptime: Node 1 (8 min), Node 2 (14 min), Node 3 (1d 19h)
✅ Fixed APT repository errors

## Recommended Next Steps
1. ✅ Fix APT repository errors (already completed)
2. 🔲 Deploy safe-reboot script to all nodes
3. 🔲 Add cluster health monitoring cron job
4. 🔲 Review and optimize HA migration settings
5. 🔲 Update corosync configuration with increased timeouts
6. 🔲 Test failover scenarios in controlled manner
7. 🔲 Add Uptime Kuma monitors for cluster health
8. 🔲 Fix Gotify rate limiting issues
9. 🔲 Document runbook for cluster maintenance

## Lessons Learned
- **3-node clusters are sensitive to cascading failures** - losing 2 nodes risks quorum
- **Network saturation during failover** can cause cascading issues
- **Manual intervention during failover** can make things worse
- **Need coordinated reboot procedures** to prevent simultaneous node failures
- **Monitoring is reactive, not preventive** - need better health checks

## Notes
- Node 3 (proxmox3) remained stable throughout (uptime: 1d 19h)
- No data loss occurred
- All HA services (influxdb, postgresql, traefik, adguard, zigbee2mqtt, mqtt-prod) recovered successfully
- This incident highlights the need for better reboot coordination in 3-node clusters
- Consider implementing a "maintenance mode" flag that prevents automatic HA migrations