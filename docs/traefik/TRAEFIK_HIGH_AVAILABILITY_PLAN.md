# Traefik High Availability Implementation Plan

## Executive Summary

This plan details the implementation of a highly available (HA) Traefik reverse proxy setup using a **Virtual IP (VIP) with keepalived** for automatic failover. The current single Traefik instance (LXC 110) will be paired with a second instance to provide redundancy and zero-downtime maintenance capabilities.

**Current Setup:**
- Single Traefik instance: LXC 110 @ 192.168.1.110
- Traefik version: 3.0.0
- 21 production services (static YAML routes)
- Proxmox plugin for auto-discovery
- Cloudflare SSL certificates

**Target Architecture:**
- Two Traefik instances in active-passive configuration
- Virtual IP (VIP) for seamless failover
- Automated configuration synchronization
- Sub-second failover times
- Zero-disruption deployments

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Implementation Phases](#implementation-phases)
4. [Detailed Configuration](#detailed-configuration)
5. [Testing & Validation](#testing--validation)
6. [Monitoring & Alerting](#monitoring--alerting)
7. [Rollback Procedures](#rollback-procedures)
8. [Maintenance Operations](#maintenance-operations)

---

## Architecture Overview

### High-Level Design

```
                          ┌─────────────────────┐
                          │  Virtual IP (VIP)   │
                          │  192.168.1.100      │
                          └──────────┬──────────┘
                                     │
                ┌────────────────────┴────────────────────┐
                │                                         │
                │                                         │
        ┌───────▼────────┐                       ┌───────▼────────┐
        │  Traefik-1     │                       │  Traefik-2     │
        │  LXC 110       │◄──────keepalived──────┤  LXC 111       │
        │  192.168.1.110 │      (heartbeat)      │  192.168.1.111 │
        │  MASTER        │                       │  BACKUP        │
        └───────┬────────┘                       └───────┬────────┘
                │                                         │
                │         ┌─────────────────┐             │
                └─────────┤  Config Sync    ├─────────────┘
                          │  (lsyncd)       │
                          └─────────────────┘
                                     │
                                     │
                          ┌──────────▼──────────┐
                          │  Backend Services   │
                          │  (21 services)      │
                          └─────────────────────┘
```

### Architecture Decisions

**1. Active-Passive (Recommended) vs. Active-Active**

**Selected: Active-Passive with keepalived**

| Feature | Active-Passive | Active-Active |
|---------|---------------|---------------|
| **Complexity** | Low | High |
| **Resource Usage** | 50% idle capacity | 100% utilized |
| **Failover Time** | < 1 second | N/A (already distributed) |
| **SSL Certificate Sharing** | Simple (shared FS or sync) | Complex (needs centralized cert store) |
| **Split-Brain Risk** | Low | Medium |
| **Maintenance** | Simple | Complex |
| **Cost** | 1 VIP | Requires load balancer |

**Why Active-Passive:**
- Simpler configuration and maintenance
- Proven reliability with keepalived
- No need for external load balancer
- SSL certificates easily shared
- Perfect for home lab / small enterprise
- Failover is fast enough (< 1 second)
- Easier to troubleshoot

**2. Virtual IP Strategy**

**Selected VIP: 192.168.1.100**

- Available IP in the management network
- Easy to remember (.100 = HA services)
- All DNS records will point here
- keepalived manages VIP ownership

**3. Configuration Synchronization**

**Selected: lsyncd (live sync daemon)**

- Real-time file synchronization
- Monitors `/etc/traefik/` for changes
- Automatic replication to secondary
- Low resource overhead
- Battle-tested for config sync

### Component Specifications

#### Primary Traefik (LXC 110)
- **IP**: 192.168.1.110
- **Role**: MASTER (keepalived priority 200)
- **Resources**: 2 CPU cores, 2GB RAM
- **OS**: Debian 12 (current)

#### Secondary Traefik (LXC 111)
- **IP**: 192.168.1.111 (new)
- **Role**: BACKUP (keepalived priority 100)
- **Resources**: 2 CPU cores, 2GB RAM
- **OS**: Debian 12 (clone from 110)

#### Virtual IP (VIP)
- **IP**: 192.168.1.100
- **Interface**: eth0
- **VRID**: 51 (Virtual Router ID)
- **Advertisement Interval**: 1 second
- **Auth Password**: (generated during setup)

---

## Prerequisites

### Network Requirements
- ✅ Available IP: 192.168.1.111 for second Traefik
- ✅ Available VIP: 192.168.1.100
- ✅ Multicast support on network (for VRRP heartbeat)
- ✅ No firewall blocking VRRP protocol (IP protocol 112)

### Proxmox Resources
- ✅ Sufficient resources on Proxmox hosts
  - 2 CPU cores for LXC 111
  - 2GB RAM for LXC 111
  - 20GB storage for LXC 111
- ✅ Root SSH access to all Proxmox nodes

### Current Configuration Backup
Before starting, backup current Traefik configuration:
```bash
# Backup entire Traefik config
ssh root@192.168.1.110 "tar czf /tmp/traefik-backup-$(date +%Y%m%d).tar.gz /etc/traefik/ /etc/systemd/system/traefik.service"
scp root@192.168.1.110:/tmp/traefik-backup-*.tar.gz /home/dev/workspace/backups/
```

### DNS Considerations
After HA is deployed, all DNS records pointing to 192.168.1.110 should be updated to point to 192.168.1.100 (VIP). However, during phased implementation, we'll keep both working.

---

## Implementation Phases

### Phase 1: Preparation (Week 1 - Day 1-2)
**Goal**: Prepare infrastructure and validate prerequisites

**Tasks:**
1. Reserve IP addresses (192.168.1.100, 192.168.1.111)
2. Add static DHCP reservations (if using DHCP)
3. Backup current Traefik configuration
4. Document all DNS records currently pointing to 192.168.1.110
5. Create implementation checklist
6. Schedule maintenance window (low-traffic period)

**Success Criteria:**
- ✅ All IPs reserved and documented
- ✅ Backup completed and verified
- ✅ Maintenance window scheduled
- ✅ Team notified (if applicable)

**Time Estimate:** 2-3 hours

---

### Phase 2: Deploy Secondary Traefik (Week 1 - Day 3-4)
**Goal**: Create second Traefik instance as clone of primary

**Tasks:**

**2.1: Clone LXC 110 to create LXC 111**

```bash
# On Proxmox host (192.168.1.137 or wherever LXC 110 resides)
ssh root@192.168.1.137

# Stop the source container temporarily (for consistent clone)
pct stop 110

# Clone the container
pct clone 110 111 --hostname traefik-2 --full 1

# Start the original back up
pct start 110

# Configure the new container with different IP
pct set 111 -net0 name=eth0,bridge=vmbr0,ip=192.168.1.111/24,gw=192.168.1.1

# Start the new container
pct start 111
```

**2.2: Update hostname and configuration on LXC 111**

```bash
ssh root@192.168.1.111

# Update hostname
hostnamectl set-hostname traefik-2
echo "traefik-2" > /etc/hostname

# Update /etc/hosts
cat > /etc/hosts <<'EOF'
127.0.0.1       localhost
192.168.1.111   traefik-2.internal.lakehouse.wtf traefik-2
192.168.1.110   traefik-1.internal.lakehouse.wtf traefik-1
192.168.1.100   traefik.internal.lakehouse.wtf traefik

# Proxmox cluster
192.168.1.137   proxmox.internal.lakehouse.wtf proxmox
192.168.1.125   proxmox2.internal.lakehouse.wtf proxmox2
192.168.1.126   proxmox3.internal.lakehouse.wtf proxmox3
EOF

# Verify Traefik is running
systemctl status traefik

# Test Traefik dashboard access
curl -k https://localhost/api/rawdata
```

**2.3: Verify both instances work independently**

```bash
# From your workstation
# Test Traefik-1 (original)
curl -k -H "Host: traefik.internal.lakehouse.wtf" https://192.168.1.110/api/rawdata | jq '.routers | length'

# Test Traefik-2 (new)
curl -k -H "Host: traefik.internal.lakehouse.wtf" https://192.168.1.111/api/rawdata | jq '.routers | length'

# Both should return 21 (or current router count)
```

**Success Criteria:**
- ✅ LXC 111 created and running
- ✅ Traefik service healthy on both instances
- ✅ Both instances serve same routes
- ✅ No errors in logs

**Time Estimate:** 2-3 hours

---

### Phase 3: Configure keepalived (Week 1 - Day 4-5)
**Goal**: Install and configure VRRP for automatic failover

**Tasks:**

**3.1: Install keepalived on both instances**

```bash
# On both LXC 110 and LXC 111
apt update
apt install -y keepalived

# Enable keepalived service
systemctl enable keepalived
```

**3.2: Configure keepalived on PRIMARY (LXC 110)**

```bash
ssh root@192.168.1.110

# Generate authentication password
VRRP_PASSWORD=$(openssl rand -base64 12)
echo "VRRP Password: $VRRP_PASSWORD"  # Save this for secondary config

# Create keepalived config
cat > /etc/keepalived/keepalived.conf <<EOF
# Traefik HA - Primary (MASTER)
global_defs {
    router_id traefik-1
    enable_script_security
    script_user root
}

vrrp_script check_traefik {
    script "/usr/local/bin/check_traefik.sh"
    interval 2           # Check every 2 seconds
    timeout 3            # Script must complete in 3 seconds
    weight -20           # Reduce priority by 20 if check fails
    fall 2               # Require 2 failures before considering it down
    rise 2               # Require 2 successes before considering it up
}

vrrp_instance VI_TRAEFIK {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 200         # Higher priority = MASTER
    advert_int 1         # Advertise every 1 second

    authentication {
        auth_type PASS
        auth_pass $VRRP_PASSWORD
    }

    virtual_ipaddress {
        192.168.1.100/24 dev eth0
    }

    track_script {
        check_traefik
    }

    # Notify scripts for monitoring
    notify_master "/usr/local/bin/keepalived_notify.sh MASTER"
    notify_backup "/usr/local/bin/keepalived_notify.sh BACKUP"
    notify_fault "/usr/local/bin/keepalived_notify.sh FAULT"
}
EOF
```

**3.3: Create health check script on PRIMARY**

```bash
ssh root@192.168.1.110

cat > /usr/local/bin/check_traefik.sh <<'EOF'
#!/bin/bash
# Traefik health check for keepalived
# Returns 0 if healthy, 1 if unhealthy

# Check 1: Traefik service is running
if ! systemctl is-active --quiet traefik; then
    echo "$(date): Traefik service not running" >> /var/log/keepalived-checks.log
    exit 1
fi

# Check 2: Traefik API responds
if ! curl -sf -k https://localhost/api/rawdata >/dev/null 2>&1; then
    echo "$(date): Traefik API not responding" >> /var/log/keepalived-checks.log
    exit 1
fi

# Check 3: At least one router is loaded
ROUTER_COUNT=$(curl -sf -k https://localhost/api/rawdata 2>/dev/null | jq -r '.routers | length' 2>/dev/null || echo "0")
if [ "$ROUTER_COUNT" -lt 1 ]; then
    echo "$(date): No routers loaded (count: $ROUTER_COUNT)" >> /var/log/keepalived-checks.log
    exit 1
fi

# All checks passed
exit 0
EOF

chmod +x /usr/local/bin/check_traefik.sh

# Test the health check
/usr/local/bin/check_traefik.sh && echo "Health check passed" || echo "Health check failed"
```

**3.4: Create notification script on PRIMARY**

```bash
ssh root@192.168.1.110

cat > /usr/local/bin/keepalived_notify.sh <<'EOF'
#!/bin/bash
# Keepalived state change notification

STATE=$1
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# Log state change
echo "[$TIMESTAMP] $HOSTNAME transitioned to $STATE" >> /var/log/keepalived-state.log

# Optional: Send notification (Pushover, webhook, etc.)
# Uncomment and configure as needed:
# curl -s \
#   -F "token=YOUR_PUSHOVER_APP_TOKEN" \
#   -F "user=YOUR_PUSHOVER_USER_KEY" \
#   -F "title=Traefik HA State Change" \
#   -F "message=$HOSTNAME is now $STATE" \
#   https://api.pushover.net/1/messages.json

# Restart Traefik if becoming MASTER (ensures fresh state)
if [ "$STATE" = "MASTER" ]; then
    systemctl reload traefik
fi
EOF

chmod +x /usr/local/bin/keepalived_notify.sh
```

**3.5: Configure keepalived on BACKUP (LXC 111)**

```bash
ssh root@192.168.1.111

# Use the same VRRP_PASSWORD from primary setup
VRRP_PASSWORD="<paste-password-from-primary>"

cat > /etc/keepalived/keepalived.conf <<EOF
# Traefik HA - Secondary (BACKUP)
global_defs {
    router_id traefik-2
    enable_script_security
    script_user root
}

vrrp_script check_traefik {
    script "/usr/local/bin/check_traefik.sh"
    interval 2
    timeout 3
    weight -20
    fall 2
    rise 2
}

vrrp_instance VI_TRAEFIK {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100         # Lower priority = BACKUP
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass $VRRP_PASSWORD
    }

    virtual_ipaddress {
        192.168.1.100/24 dev eth0
    }

    track_script {
        check_traefik
    }

    notify_master "/usr/local/bin/keepalived_notify.sh MASTER"
    notify_backup "/usr/local/bin/keepalived_notify.sh BACKUP"
    notify_fault "/usr/local/bin/keepalived_notify.sh FAULT"
}
EOF

# Copy health check script from primary
scp root@192.168.1.110:/usr/local/bin/check_traefik.sh /usr/local/bin/
scp root@192.168.1.110:/usr/local/bin/keepalived_notify.sh /usr/local/bin/
chmod +x /usr/local/bin/check_traefik.sh
chmod +x /usr/local/bin/keepalived_notify.sh
```

**3.6: Start keepalived on both instances**

```bash
# Start on BACKUP first, then MASTER (best practice)
ssh root@192.168.1.111 "systemctl start keepalived && systemctl status keepalived"
ssh root@192.168.1.110 "systemctl start keepalived && systemctl status keepalived"
```

**3.7: Verify VIP is active**

```bash
# Check which instance owns the VIP (should be primary)
ssh root@192.168.1.110 "ip addr show eth0 | grep 192.168.1.100"
# Should show: inet 192.168.1.100/24 scope global secondary eth0

ssh root@192.168.1.111 "ip addr show eth0 | grep 192.168.1.100"
# Should show nothing (backup doesn't have VIP)

# Test VIP responds
ping -c 3 192.168.1.100
curl -k https://192.168.1.100/api/rawdata
```

**Success Criteria:**
- ✅ keepalived running on both instances
- ✅ VIP (192.168.1.100) owned by primary (LXC 110)
- ✅ VIP responds to ping and HTTP requests
- ✅ Health checks passing on both instances

**Time Estimate:** 3-4 hours

---

### Phase 4: Configuration Synchronization (Week 1 - Day 5-6)
**Goal**: Automate config sync from primary to secondary

**Tasks:**

**4.1: Install lsyncd on PRIMARY (LXC 110)**

```bash
ssh root@192.168.1.110

# Install lsyncd
apt update
apt install -y lsyncd rsync

# Enable lsyncd
systemctl enable lsyncd
```

**4.2: Set up SSH key authentication**

```bash
ssh root@192.168.1.110

# Generate SSH key (no passphrase for automated sync)
ssh-keygen -t ed25519 -f /root/.ssh/traefik_sync -N ""

# Copy public key to secondary
ssh-copy-id -i /root/.ssh/traefik_sync.pub root@192.168.1.111

# Test passwordless SSH
ssh -i /root/.ssh/traefik_sync root@192.168.1.111 "echo 'SSH test successful'"
```

**4.3: Configure lsyncd on PRIMARY**

```bash
ssh root@192.168.1.110

cat > /etc/lsyncd/lsyncd.conf.lua <<'EOF'
-- Traefik Configuration Sync
-- Automatically replicates /etc/traefik/ from primary to secondary

settings {
    logfile = "/var/log/lsyncd/lsyncd.log",
    statusFile = "/var/log/lsyncd/lsyncd.status",
    statusInterval = 10,
    nodaemon = false,
}

-- Sync Traefik configuration directory
sync {
    default.rsyncssh,
    source = "/etc/traefik/",
    host = "root@192.168.1.111",
    targetdir = "/etc/traefik/",
    rsync = {
        archive = true,
        compress = false,
        verbose = true,
        _extra = {"-i /root/.ssh/traefik_sync"}
    },
    delay = 2,  -- Wait 2 seconds after detecting changes
    exclude = {
        "*.log",
        "*.pid",
        ".git/"
    },
    ssh = {
        identityFile = "/root/.ssh/traefik_sync"
    }
}
EOF

# Create log directory
mkdir -p /var/log/lsyncd

# Start lsyncd
systemctl start lsyncd
systemctl status lsyncd
```

**4.4: Test configuration sync**

```bash
# On primary, create a test file
ssh root@192.168.1.110 "echo 'test' > /etc/traefik/sync-test.txt"

# Wait 5 seconds
sleep 5

# Check if file appeared on secondary
ssh root@192.168.1.111 "cat /etc/traefik/sync-test.txt"
# Should output: test

# Clean up test file
ssh root@192.168.1.110 "rm /etc/traefik/sync-test.txt"
sleep 5
ssh root@192.168.1.111 "ls /etc/traefik/sync-test.txt"
# Should show: No such file
```

**4.5: Configure automatic Traefik reload on secondary**

```bash
ssh root@192.168.1.111

# Install inotify-tools
apt install -y inotify-tools

# Create file watcher service
cat > /etc/systemd/system/traefik-config-watcher.service <<'EOF'
[Unit]
Description=Traefik Configuration File Watcher
After=network.target traefik.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStart=/usr/local/bin/traefik-config-watcher.sh

[Install]
WantedBy=multi-user.target
EOF

# Create watcher script
cat > /usr/local/bin/traefik-config-watcher.sh <<'EOF'
#!/bin/bash
# Watch for Traefik config changes and reload

WATCH_DIR="/etc/traefik"
LOG_FILE="/var/log/traefik-config-watcher.log"

echo "$(date): Starting Traefik config watcher" >> "$LOG_FILE"

inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" --exclude '\.log$|\.pid$' | \
while read -r directory events filename; do
    echo "$(date): Detected $events on $directory$filename" >> "$LOG_FILE"

    # Wait a moment for file to finish writing
    sleep 2

    # Reload Traefik
    systemctl reload traefik

    echo "$(date): Traefik reloaded" >> "$LOG_FILE"
done
EOF

chmod +x /usr/local/bin/traefik-config-watcher.sh

# Enable and start watcher
systemctl enable traefik-config-watcher
systemctl start traefik-config-watcher
systemctl status traefik-config-watcher
```

**4.6: Test automatic reload**

```bash
# On primary, make a change to a dynamic config file
ssh root@192.168.1.110 "echo '# Test comment' >> /etc/traefik/dynamic/services.yml"

# Wait 10 seconds
sleep 10

# Check secondary logs for reload
ssh root@192.168.1.111 "tail -20 /var/log/traefik-config-watcher.log"
ssh root@192.168.1.111 "journalctl -u traefik --since '1 minute ago' | grep -i reload"

# Verify change was synced
ssh root@192.168.1.111 "tail -5 /etc/traefik/dynamic/services.yml"
```

**Success Criteria:**
- ✅ lsyncd running on primary
- ✅ Configuration changes sync within 5 seconds
- ✅ Secondary Traefik automatically reloads after sync
- ✅ No errors in sync logs

**Time Estimate:** 2-3 hours

---

### Phase 5: Failover Testing (Week 1 - Day 6-7)
**Goal**: Validate automatic failover works correctly

**Tasks:**

**5.1: Document current state**

```bash
# Record which instance is MASTER
ssh root@192.168.1.110 "systemctl status keepalived | grep -E 'Active|State'"
ssh root@192.168.1.111 "systemctl status keepalived | grep -E 'Active|State'"

# Record VIP ownership
ssh root@192.168.1.110 "ip addr show eth0 | grep 192.168.1.100"

# Test VIP access
curl -k https://192.168.1.100/api/rawdata | jq -r '.routers | keys | length'
```

**5.2: Test automatic failover (simulate failure)**

```bash
# Stop Traefik service on primary to trigger failover
ssh root@192.168.1.110 "systemctl stop traefik"

# Monitor failover (watch for ~3-5 seconds)
watch -n 0.5 'ping -c 1 -W 1 192.168.1.100 > /dev/null && echo "VIP UP" || echo "VIP DOWN"'

# After failover, verify VIP moved to secondary
ssh root@192.168.1.111 "ip addr show eth0 | grep 192.168.1.100"
# Should show VIP on secondary now

# Test VIP still serves traffic
curl -k https://192.168.1.100/api/rawdata | jq -r '.routers | keys | length'

# Check keepalived logs for transition
ssh root@192.168.1.111 "tail -20 /var/log/keepalived-state.log"
```

**5.3: Test failback (restore primary)**

```bash
# Start Traefik on primary again
ssh root@192.168.1.110 "systemctl start traefik"

# Wait 5 seconds for health checks to pass
sleep 5

# VIP should move back to primary (higher priority)
ssh root@192.168.1.110 "ip addr show eth0 | grep 192.168.1.100"
# Should show VIP back on primary

# Verify VIP still serves traffic
curl -k https://192.168.1.100/api/rawdata | jq -r '.routers | keys | length'

# Check keepalived logs
ssh root@192.168.1.110 "tail -20 /var/log/keepalived-state.log"
```

**5.4: Test hard failure (container stop)**

```bash
# Stop entire primary container
ssh root@192.168.1.137 "pct stop 110"

# Monitor failover
sleep 3
ping -c 3 192.168.1.100

# Verify VIP on secondary
ssh root@192.168.1.111 "ip addr show eth0 | grep 192.168.1.100"

# Test traffic
curl -k https://192.168.1.100/api/rawdata

# Restore primary
ssh root@192.168.1.137 "pct start 110"

# Wait for services to come up
sleep 10

# Verify failback
ssh root@192.168.1.110 "ip addr show eth0 | grep 192.168.1.100"
```

**5.5: Load testing (optional)**

```bash
# Run load test during failover
# Install apache bench
apt install -y apache2-utils

# Start load test (1000 requests, 10 concurrent)
ab -n 1000 -c 10 -k https://192.168.1.100/ &

# While running, stop primary
sleep 2
ssh root@192.168.1.110 "systemctl stop traefik"

# Wait for test to complete
wait

# Check results - should see minimal failures (only during 1-2 second failover window)
```

**Success Criteria:**
- ✅ Failover completes in < 5 seconds
- ✅ VIP automatically moves to backup
- ✅ Traffic continues with minimal disruption
- ✅ Failback works when primary recovers
- ✅ No service errors during failover
- ✅ All routes accessible via VIP

**Time Estimate:** 2-3 hours

---

### Phase 6: DNS Migration (Week 2 - Day 1-2)
**Goal**: Update all DNS records to point to VIP

**Tasks:**

**6.1: Identify all DNS records**

Current services using Traefik (21 total):
- adguard.internal.lakehouse.wtf
- adguard-2.internal.lakehouse.wtf
- uptime-kuma.internal.lakehouse.wtf
- influxdb.internal.lakehouse.wtf
- kea-1.internal.lakehouse.wtf
- kea-2.internal.lakehouse.wtf
- myspeed.internal.lakehouse.wtf
- omada.internal.lakehouse.wtf
- pairdrop.internal.lakehouse.wtf
- proxmox.internal.lakehouse.wtf
- proxmox2.internal.lakehouse.wtf
- proxmox3.internal.lakehouse.wtf
- pulse.internal.lakehouse.wtf
- watchyourlan.internal.lakehouse.wtf
- wiki.internal.lakehouse.wtf
- esphome.internal.lakehouse.wtf
- zigbee2mqtt.internal.lakehouse.wtf
- zwave-js-ui.internal.lakehouse.wtf
- netbox.internal.lakehouse.wtf
- stork.internal.lakehouse.wtf
- truenas.internal.lakehouse.wtf
- traefik.internal.lakehouse.wtf
- grafana.internal.lakehouse.wtf
- hoarder.internal.lakehouse.wtf
- memos.internal.lakehouse.wtf
- gitops.internal.lakehouse.wtf

**6.2: Update DNS records to VIP**

Assuming using AdGuard Home for DNS:

```bash
# Log into AdGuard at https://adguard.internal.lakehouse.wtf
# Navigate to Filters > DNS rewrites
# Update all records from 192.168.1.110 → 192.168.1.100

# Example using AdGuard API (if available):
# This is a template - adjust based on your DNS management method

for service in adguard adguard-2 uptime-kuma influxdb kea-1 kea-2 myspeed \
               omada pairdrop proxmox proxmox2 proxmox3 pulse watchyourlan \
               wiki esphome zigbee2mqtt zwave-js-ui netbox stork truenas \
               traefik grafana hoarder memos gitops; do
    echo "Updating DNS for $service.internal.lakehouse.wtf → 192.168.1.100"
    # Update your DNS server here
done
```

**6.3: Gradual DNS migration approach (safer)**

Instead of changing all at once, migrate in phases:

**Day 1 - Test with traefik dashboard only:**
```bash
# Update only traefik.internal.lakehouse.wtf → 192.168.1.100
# Test dashboard access for 24 hours
```

**Day 2 - Migrate non-critical services:**
```bash
# Update: memos, hoarder, gitops, pairdrop
# Monitor for 24 hours
```

**Day 3 - Migrate monitoring services:**
```bash
# Update: grafana, uptime-kuma, influxdb
# Monitor for 24 hours
```

**Day 4 - Migrate infrastructure:**
```bash
# Update: proxmox*, adguard*, kea*, esphome, zigbee2mqtt, zwave-js-ui
# Monitor for 24 hours
```

**Day 5 - Final migration:**
```bash
# Update remaining services
# All DNS now points to VIP
```

**Success Criteria:**
- ✅ All DNS records updated to 192.168.1.100
- ✅ No access issues reported
- ✅ Services accessible via new VIP
- ✅ SSL certificates still valid

**Time Estimate:** 1-2 hours (spread over 5 days)

---

### Phase 7: Monitoring & Documentation (Week 2 - Day 3-4)
**Goal**: Set up monitoring and complete documentation

**Tasks:**

**7.1: Add Uptime Kuma monitors**

```bash
# Add monitors for:
# 1. Traefik VIP (192.168.1.100)
# 2. Traefik Primary (192.168.1.110)
# 3. Traefik Secondary (192.168.1.111)
# 4. keepalived service on both

# Example: Monitor VIP
Monitor name: Traefik HA VIP
Monitor type: HTTP(s)
URL: https://192.168.1.100/api/rawdata
Heartbeat interval: 60s
Max retries: 2

# Example: Monitor keepalived
Monitor name: Traefik-1 Keepalived
Monitor type: Custom (script monitoring)
# Use remote SSH to check systemctl status keepalived
```

**7.2: Create monitoring dashboard**

```bash
# Script to show HA status
cat > /home/dev/workspace/traefik-ha-status.sh <<'EOF'
#!/bin/bash
# Traefik HA Status Dashboard

echo "=========================================="
echo "Traefik High Availability Status"
echo "=========================================="
echo

echo "=== VIP Status ==="
VIP_PING=$(ping -c 1 -W 1 192.168.1.100 > /dev/null 2>&1 && echo "✓ UP" || echo "✗ DOWN")
echo "VIP (192.168.1.100): $VIP_PING"
echo

echo "=== Instance Status ==="
echo "Primary (traefik-1 @ 192.168.1.110):"
ssh root@192.168.1.110 "systemctl is-active traefik" 2>/dev/null | sed 's/^/  Traefik: /'
ssh root@192.168.1.110 "systemctl is-active keepalived" 2>/dev/null | sed 's/^/  keepalived: /'
PRIMARY_VIP=$(ssh root@192.168.1.110 "ip addr show eth0 | grep 192.168.1.100" 2>/dev/null)
if [ -n "$PRIMARY_VIP" ]; then
    echo "  Role: MASTER (owns VIP)"
else
    echo "  Role: BACKUP"
fi
echo

echo "Secondary (traefik-2 @ 192.168.1.111):"
ssh root@192.168.1.111 "systemctl is-active traefik" 2>/dev/null | sed 's/^/  Traefik: /'
ssh root@192.168.1.111 "systemctl is-active keepalived" 2>/dev/null | sed 's/^/  keepalived: /'
SECONDARY_VIP=$(ssh root@192.168.1.111 "ip addr show eth0 | grep 192.168.1.100" 2>/dev/null)
if [ -n "$SECONDARY_VIP" ]; then
    echo "  Role: MASTER (owns VIP)"
else
    echo "  Role: BACKUP"
fi
echo

echo "=== Configuration Sync Status ==="
ssh root@192.168.1.110 "systemctl is-active lsyncd" 2>/dev/null | sed 's/^/  lsyncd: /'
LAST_SYNC=$(ssh root@192.168.1.110 "tail -1 /var/log/lsyncd/lsyncd.log 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'" || echo "N/A")
echo "  Last sync: $LAST_SYNC"
echo

echo "=== Recent State Changes ==="
ssh root@192.168.1.110 "tail -5 /var/log/keepalived-state.log 2>/dev/null" | sed 's/^/  /'
echo

echo "=== Health Checks ==="
PRIMARY_HEALTH=$(ssh root@192.168.1.110 "/usr/local/bin/check_traefik.sh" 2>/dev/null && echo "✓ Healthy" || echo "✗ Unhealthy")
SECONDARY_HEALTH=$(ssh root@192.168.1.111 "/usr/local/bin/check_traefik.sh" 2>/dev/null && echo "✓ Healthy" || echo "✗ Unhealthy")
echo "Primary: $PRIMARY_HEALTH"
echo "Secondary: $SECONDARY_HEALTH"
echo

echo "=========================================="
echo "Status check completed at $(date)"
echo "=========================================="
EOF

chmod +x /home/dev/workspace/traefik-ha-status.sh

# Test it
/home/dev/workspace/traefik-ha-status.sh
```

**7.3: Set up log rotation**

```bash
# On both instances
ssh root@192.168.1.110 "cat > /etc/logrotate.d/keepalived-custom <<'EOF'
/var/log/keepalived-state.log
/var/log/keepalived-checks.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0640 root adm
}
EOF"

ssh root@192.168.1.111 "cat > /etc/logrotate.d/keepalived-custom <<'EOF'
/var/log/keepalived-state.log
/var/log/keepalived-checks.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0640 root adm
}
EOF"
```

**7.4: Create operational runbook**

(Document common operations - see Maintenance Operations section below)

**Success Criteria:**
- ✅ Uptime Kuma monitoring configured
- ✅ Status dashboard script working
- ✅ Log rotation configured
- ✅ Documentation complete

**Time Estimate:** 2-3 hours

---

## Detailed Configuration

### SSL Certificate Handling

Currently using Cloudflare certificates. No changes needed - certificates are already stored in `/etc/traefik/certs/` which is synced via lsyncd.

**Verify certificate sync:**
```bash
# On primary
ssh root@192.168.1.110 "ls -lh /etc/traefik/certs/"

# On secondary (should match)
ssh root@192.168.1.111 "ls -lh /etc/traefik/certs/"
```

### Proxmox Plugin Considerations

The Proxmox provider plugin is configured with API token. Both instances will poll Proxmox independently. No changes needed since they share the same configuration.

**Token reuse:** Same API token can be used by both instances (read-only operations).

### Network Requirements

**Firewall rules (if using firewall):**
```bash
# Allow VRRP (protocol 112) between instances
# Allow TCP 443 (HTTPS) to VIP
# Allow TCP 80 (HTTP) to VIP
# Allow TCP 8080 (Traefik dashboard) to VIP
```

**Proxmox network settings:**
```bash
# Ensure multicast is allowed (for VRRP)
# Check Proxmox firewall settings on vmbr0
ssh root@192.168.1.137 "pvesh get /nodes/proxmox/network"
```

---

## Testing & Validation

### Comprehensive Test Suite

**Test 1: Service continuity during failover**
```bash
# Start continuous requests
while true; do
    curl -sk https://192.168.1.100/api/rawdata > /dev/null && echo "$(date +%T) - OK" || echo "$(date +%T) - FAIL"
    sleep 0.5
done &
BG_PID=$!

# Trigger failover
sleep 5
ssh root@192.168.1.110 "systemctl stop traefik"

# Wait 10 seconds
sleep 10

# Stop continuous test
kill $BG_PID

# Expected: 1-2 failures during 1-second failover window
```

**Test 2: Configuration sync**
```bash
# Add a test route on primary
ssh root@192.168.1.110 "cat >> /etc/traefik/dynamic/routers.yml <<'EOF'

  test-sync-router:
    rule: Host(\`test-sync.internal.lakehouse.wtf\`)
    service: test-sync-service
    entryPoints:
      - websecure
EOF"

# Wait 10 seconds
sleep 10

# Verify on secondary
ssh root@192.168.1.111 "grep -A 4 'test-sync-router' /etc/traefik/dynamic/routers.yml"

# Check if secondary Traefik loaded it
ssh root@192.168.1.111 "curl -sk https://localhost/api/rawdata | jq '.routers.\"test-sync-router@file\"'"

# Clean up
ssh root@192.168.1.110 "sed -i '/test-sync-router/,+5d' /etc/traefik/dynamic/routers.yml"
```

**Test 3: Split-brain prevention**
```bash
# Verify both instances never claim VIP simultaneously
# Monitor both interfaces
watch -n 0.5 'echo "PRIMARY:"; ssh root@192.168.1.110 "ip addr show eth0 | grep 192.168.1.100" || echo "  No VIP"; echo "SECONDARY:"; ssh root@192.168.1.111 "ip addr show eth0 | grep 192.168.1.100" || echo "  No VIP"'

# Trigger various failure scenarios and ensure only one has VIP
```

**Test 4: Backend service routing**
```bash
# Test a few production routes via VIP
curl -sk https://192.168.1.100 -H "Host: grafana.internal.lakehouse.wtf"
curl -sk https://192.168.1.100 -H "Host: uptime-kuma.internal.lakehouse.wtf"
curl -sk https://192.168.1.100 -H "Host: wiki.internal.lakehouse.wtf"

# All should return 200 or redirect to login pages
```

---

## Monitoring & Alerting

### Key Metrics to Monitor

**1. VIP Availability**
- Metric: HTTP response from 192.168.1.100
- Threshold: Alert if down > 10 seconds
- Check interval: 60 seconds

**2. keepalived Service Status**
- Metric: systemctl status keepalived
- Threshold: Alert if inactive
- Check interval: 120 seconds

**3. Traefik Service Status**
- Metric: systemctl status traefik
- Threshold: Alert if inactive
- Check interval: 60 seconds

**4. Configuration Sync Status**
- Metric: lsyncd service + last sync timestamp
- Threshold: Alert if sync > 5 minutes old
- Check interval: 300 seconds

**5. State Changes**
- Metric: keepalived state transitions
- Threshold: Alert on any state change
- Method: Parse /var/log/keepalived-state.log

**6. Health Check Failures**
- Metric: check_traefik.sh failures
- Threshold: Alert on 3+ consecutive failures
- Check interval: Monitored by keepalived every 2 seconds

### Alerting Configuration

**Uptime Kuma Configuration:**
```
Monitor Name: Traefik HA - VIP
Type: HTTP(s)
URL: https://192.168.1.100/api/rawdata
Interval: 60s
Retries: 2
Notification: (your notification method)

Monitor Name: Traefik HA - Primary
Type: HTTP(s)
URL: https://192.168.1.110/api/rawdata
Interval: 120s

Monitor Name: Traefik HA - Secondary
Type: HTTP(s)
URL: https://192.168.1.111/api/rawdata
Interval: 120s
```

### Grafana Dashboard (Optional)

If you want to create a Grafana dashboard:
- Use node_exporter on both Traefik instances
- Monitor CPU, RAM, network traffic
- Create alerts for resource exhaustion
- Track VRRP state via custom metrics

---

## Rollback Procedures

### Complete Rollback to Single Instance

If HA causes issues and you need to quickly revert:

**Step 1: Stop secondary instance**
```bash
ssh root@192.168.1.111 "systemctl stop keepalived traefik"
ssh root@192.168.1.137 "pct stop 111"
```

**Step 2: Stop keepalived on primary**
```bash
ssh root@192.168.1.110 "systemctl stop keepalived"
```

**Step 3: Remove VIP from primary manually (if needed)**
```bash
ssh root@192.168.1.110 "ip addr del 192.168.1.100/24 dev eth0"
```

**Step 4: Update DNS back to primary IP**
```bash
# Update all DNS records from 192.168.1.100 → 192.168.1.110
# (Use your DNS management method)
```

**Step 5: Verify single instance operation**
```bash
curl -k https://192.168.1.110/api/rawdata
```

**Step 6: Disable keepalived on primary**
```bash
ssh root@192.168.1.110 "systemctl disable keepalived"
```

System is now back to original single-instance configuration.

---

## Maintenance Operations

### Common Operations

**1. Graceful Failover for Maintenance**

To perform maintenance on primary without disruption:
```bash
# Stop Traefik on primary (keepalived will trigger failover)
ssh root@192.168.1.110 "systemctl stop traefik"

# Wait for failover (3-5 seconds)
sleep 5

# Verify VIP moved to secondary
ssh root@192.168.1.111 "ip addr show eth0 | grep 192.168.1.100"

# Perform maintenance on primary
ssh root@192.168.1.110
# ... do maintenance ...
# Update packages, restart container, etc.

# When done, start Traefik
systemctl start traefik

# VIP will automatically fail back after health checks pass
```

**2. Upgrading Traefik Version**

Upgrade one instance at a time:
```bash
# Step 1: Upgrade secondary (while primary serves traffic)
ssh root@192.168.1.111 "systemctl stop traefik"
ssh root@192.168.1.111 "apt update && apt install traefik"  # or whatever upgrade method
ssh root@192.168.1.111 "systemctl start traefik"

# Verify secondary is healthy
ssh root@192.168.1.111 "curl -sk https://localhost/api/rawdata"

# Step 2: Failover to secondary
ssh root@192.168.1.110 "systemctl stop traefik"
sleep 5

# Step 3: Upgrade primary (while secondary serves traffic)
ssh root@192.168.1.110 "apt update && apt install traefik"
ssh root@192.168.1.110 "systemctl start traefik"

# Will automatically fail back to primary
```

**3. Updating Static Routes**

Simply edit on primary - automatic sync will handle secondary:
```bash
# Edit on primary only
ssh root@192.168.1.110 "vim /etc/traefik/dynamic/routers.yml"

# lsyncd will sync to secondary within 2-5 seconds
# Secondary will auto-reload Traefik

# Verify route on both:
ssh root@192.168.1.110 "curl -sk https://localhost/api/http/routers"
ssh root@192.168.1.111 "curl -sk https://localhost/api/http/routers"
```

**4. Testing Failover**

Periodically test failover (monthly recommended):
```bash
# Scheduled test during low-traffic period
/home/dev/workspace/traefik-ha-status.sh > /tmp/pre-failover.txt

# Trigger failover
ssh root@192.168.1.110 "systemctl stop traefik"

# Wait and verify
sleep 10
curl -k https://192.168.1.100/api/rawdata

# Restore
ssh root@192.168.1.110 "systemctl start traefik"
sleep 10

# Verify failback
/home/dev/workspace/traefik-ha-status.sh > /tmp/post-failover.txt

# Compare states
diff /tmp/pre-failover.txt /tmp/post-failover.txt
```

**5. Viewing Logs**

```bash
# Traefik logs (primary)
ssh root@192.168.1.110 "tail -f /var/log/traefik/traefik.log"

# keepalived logs
ssh root@192.168.1.110 "tail -f /var/log/syslog | grep keepalived"

# State change history
ssh root@192.168.1.110 "tail -50 /var/log/keepalived-state.log"

# Health check history
ssh root@192.168.1.110 "tail -50 /var/log/keepalived-checks.log"

# Config sync logs
ssh root@192.168.1.110 "tail -f /var/log/lsyncd/lsyncd.log"
```

---

## Resource Requirements

### Per-Instance Resources

**Traefik LXC (110 & 111):**
- CPU: 2 cores
- RAM: 2GB
- Storage: 20GB
- Network: 1 Gbps

**Additional Services:**
- keepalived: ~10MB RAM, negligible CPU
- lsyncd: ~5MB RAM, negligible CPU
- inotify watcher: ~5MB RAM, negligible CPU

**Total per instance:** 2 cores, 2GB RAM, 20GB storage

### Total Cluster Resources

- 4 CPU cores total (2 per instance)
- 4GB RAM total (2GB per instance)
- 40GB storage total (20GB per instance)

---

## Success Criteria

### Phase Completion Criteria

✅ **Phase 1 - Preparation:**
- IPs reserved and documented
- Backup created
- Maintenance window scheduled

✅ **Phase 2 - Secondary Deployment:**
- LXC 111 running
- Traefik healthy on both instances
- Both serving same routes

✅ **Phase 3 - keepalived:**
- VIP active on primary
- Health checks passing
- Automatic failover working

✅ **Phase 4 - Config Sync:**
- lsyncd replicating changes
- Automatic reload on secondary
- Changes sync within 5 seconds

✅ **Phase 5 - Testing:**
- Failover < 5 seconds
- Traffic continues during failover
- Failback automatic

✅ **Phase 6 - DNS Migration:**
- All DNS → VIP
- No access issues
- SSL working

✅ **Phase 7 - Monitoring:**
- Uptime Kuma configured
- Alerts working
- Documentation complete

### Overall Project Success

- ✅ Zero-downtime deployments possible
- ✅ Automatic failover < 5 seconds
- ✅ Configuration stays synchronized
- ✅ Monitoring and alerting active
- ✅ Team trained on operations
- ✅ Documentation complete

---

## Timeline Summary

| Phase | Duration | Tasks |
|-------|----------|-------|
| Phase 1: Preparation | 2-3 hours | IP reservation, backup, planning |
| Phase 2: Secondary Deploy | 2-3 hours | Clone LXC, configure network |
| Phase 3: keepalived | 3-4 hours | Install, configure, test VRRP |
| Phase 4: Config Sync | 2-3 hours | lsyncd, auto-reload |
| Phase 5: Testing | 2-3 hours | Failover tests, validation |
| Phase 6: DNS Migration | 1-2 hours | Update DNS records (phased over 5 days) |
| Phase 7: Monitoring | 2-3 hours | Dashboards, alerts, docs |
| **Total** | **14-21 hours** | **Spread over 2 weeks** |

---

## Risk Assessment

### Identified Risks

**Risk 1: Split-Brain Scenario**
- **Description**: Both instances claim VIP simultaneously
- **Likelihood**: Low
- **Impact**: High
- **Mitigation**: VRRP authentication, proper network configuration
- **Detection**: Monitor both interfaces, alert on dual-VIP

**Risk 2: Configuration Drift**
- **Description**: Secondary config becomes out of sync
- **Likelihood**: Low
- **Impact**: Medium
- **Mitigation**: Automated lsyncd, monitoring sync status
- **Detection**: Config hash comparison, sync age alerts

**Risk 3: SSL Certificate Issues**
- **Description**: Certificates not syncing properly
- **Likelihood**: Low
- **Impact**: High
- **Mitigation**: Include certs in lsyncd, test cert access
- **Detection**: SSL monitoring, cert expiry checks

**Risk 4: Failover Too Aggressive**
- **Description**: Instances flip-flop between MASTER/BACKUP
- **Likelihood**: Medium
- **Impact**: Medium
- **Mitigation**: Proper health check thresholds (fall=2, rise=2)
- **Detection**: Monitor state change frequency

**Risk 5: Resource Exhaustion**
- **Description**: Running two instances strains Proxmox resources
- **Likelihood**: Low
- **Impact**: Medium
- **Mitigation**: 2GB RAM per instance should be sufficient
- **Detection**: Monitor Proxmox host resources

**Risk 6: Network Issues**
- **Description**: VRRP multicast blocked by network
- **Likelihood**: Low
- **Impact**: High
- **Mitigation**: Test VRRP before full deployment
- **Detection**: keepalived logs show communication issues

---

## Support and Troubleshooting

### Common Issues

**Issue 1: VIP doesn't appear on either instance**
```bash
# Check keepalived status
ssh root@192.168.1.110 "systemctl status keepalived"
ssh root@192.168.1.111 "systemctl status keepalived"

# Check logs for errors
ssh root@192.168.1.110 "journalctl -u keepalived -n 50"

# Verify interface name in config is correct (eth0)
ssh root@192.168.1.110 "grep interface /etc/keepalived/keepalived.conf"

# Verify no IP conflicts
ping -c 1 192.168.1.100  # Should respond
arping -I vmbr0 192.168.1.100  # Should show MAC
```

**Issue 2: VIP exists but doesn't respond**
```bash
# Check routing
ssh root@192.168.1.110 "ip route get 192.168.1.100"

# Check firewall
ssh root@192.168.1.110 "iptables -L -n | grep 192.168.1.100"

# Check if Traefik is listening
ssh root@192.168.1.110 "ss -tlnp | grep :443"

# Test locally
ssh root@192.168.1.110 "curl -k https://192.168.1.100/api/rawdata"
```

**Issue 3: Failover not happening**
```bash
# Check health check script
ssh root@192.168.1.110 "/usr/local/bin/check_traefik.sh; echo Exit code: $?"

# Check keepalived is tracking the script
ssh root@192.168.1.110 "grep 'check_traefik' /var/log/syslog | tail -10"

# Verify VRRP priority
ssh root@192.168.1.110 "grep priority /etc/keepalived/keepalived.conf"
ssh root@192.168.1.111 "grep priority /etc/keepalived/keepalived.conf"
# Primary should be higher (200 vs 100)
```

**Issue 4: Configuration not syncing**
```bash
# Check lsyncd status
ssh root@192.168.1.110 "systemctl status lsyncd"

# Check lsyncd logs
ssh root@192.168.1.110 "tail -50 /var/log/lsyncd/lsyncd.log"

# Test SSH connectivity
ssh root@192.168.1.110 "ssh -i /root/.ssh/traefik_sync root@192.168.1.111 echo OK"

# Manual sync test
ssh root@192.168.1.110 "rsync -avz -e 'ssh -i /root/.ssh/traefik_sync' /etc/traefik/ root@192.168.1.111:/etc/traefik/"
```

**Issue 5: Both instances show MASTER state (split-brain)**
```bash
# This is serious - immediately investigate

# Check VRRP communication
ssh root@192.168.1.110 "tcpdump -i eth0 -n proto 112"
# Should see VRRP advertisements

# Verify same VRID and password on both
ssh root@192.168.1.110 "grep -E 'virtual_router_id|auth_pass' /etc/keepalived/keepalived.conf"
ssh root@192.168.1.111 "grep -E 'virtual_router_id|auth_pass' /etc/keepalived/keepalived.conf"

# Check for network isolation
ping -c 3 192.168.1.111  # From primary
ping -c 3 192.168.1.110  # From secondary

# If split-brain detected, stop one instance immediately
ssh root@192.168.1.111 "systemctl stop keepalived"
```

---

## Additional Resources

### Documentation Links
- keepalived: https://www.keepalived.org/
- VRRP Protocol: https://datatracker.ietf.org/doc/html/rfc3768
- lsyncd: https://github.com/lsyncd/lsyncd
- Traefik HA: https://doc.traefik.io/traefik/contributing/building-testing/

### Configuration Files Summary

**Primary (LXC 110):**
- `/etc/keepalived/keepalived.conf` - VRRP configuration (MASTER)
- `/etc/lsyncd/lsyncd.conf.lua` - Config sync to secondary
- `/usr/local/bin/check_traefik.sh` - Health check script
- `/usr/local/bin/keepalived_notify.sh` - State change notifications
- `/etc/traefik/` - Traefik configuration (source of truth)

**Secondary (LXC 111):**
- `/etc/keepalived/keepalived.conf` - VRRP configuration (BACKUP)
- `/etc/systemd/system/traefik-config-watcher.service` - Auto-reload service
- `/usr/local/bin/traefik-config-watcher.sh` - Watch for config changes
- `/usr/local/bin/check_traefik.sh` - Health check script
- `/usr/local/bin/keepalived_notify.sh` - State change notifications
- `/etc/traefik/` - Traefik configuration (synced from primary)

**Workspace:**
- `/home/dev/workspace/docs/traefik/TRAEFIK_HIGH_AVAILABILITY_PLAN.md` - This document
- `/home/dev/workspace/traefik-ha-status.sh` - Status dashboard script
- `/home/dev/workspace/backups/traefik-backup-*.tar.gz` - Configuration backups

---

## Conclusion

This plan provides a comprehensive path to implementing high availability for your Traefik reverse proxy. The active-passive architecture with keepalived offers:

✅ **Reliability** - Automatic failover in < 5 seconds
✅ **Simplicity** - Easy to understand and maintain
✅ **Zero-downtime** - Maintenance without service interruption
✅ **Proven** - Battle-tested technology stack
✅ **Observable** - Full monitoring and alerting
✅ **Recoverable** - Clear rollback procedures

The phased implementation approach minimizes risk and allows for thorough testing at each stage. By following this plan, you'll have a production-ready HA Traefik deployment that provides resilience for all 21+ services currently behind your reverse proxy.

**Next Steps:**
1. Review this plan thoroughly
2. Schedule implementation during low-traffic period
3. Begin with Phase 1 (Preparation)
4. Proceed through phases methodically
5. Test thoroughly at each phase
6. Document any deviations or customizations

**Remember:** Take your time, test thoroughly, and don't rush into DNS migration until you're confident in the failover behavior.

---

**Plan Version:** 1.0
**Created:** 2025-11-09
**Author:** Claude Code
**Target Completion:** Week of 2025-11-11
**Status:** Ready for Implementation
