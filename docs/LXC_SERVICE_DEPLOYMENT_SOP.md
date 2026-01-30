# LXC Service Deployment - Standard Operating Procedure

**Version:** 1.0
**Last Updated:** 2025-11-19
**Maintained By:** Infrastructure Team
**Purpose:** Standardized procedure for deploying services in LXC containers to production

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Deployment Steps](#deployment-steps)
5. [Post-Deployment Validation](#post-deployment-validation)
6. [Troubleshooting](#troubleshooting)
7. [Rollback Procedures](#rollback-procedures)
8. [References](#references)

---

## Overview

This SOP provides a standardized approach to deploying services in LXC containers within the Proxmox HA cluster. Following this procedure ensures consistency, reliability, and proper integration with existing infrastructure components.

### Scope

This SOP covers:
- LXC container configuration
- Network configuration (DHCP, DNS, routing)
- Reverse proxy setup (Traefik)
- Monitoring integration (Uptime Kuma)
- Dashboard integration (Homepage)

### Infrastructure Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **Proxmox Cluster** | 192.168.1.137, 192.168.1.125, 192.168.1.126 | Container hosts |
| **Kea DHCP (Primary)** | 192.168.1.133 | DHCP reservations |
| **Kea DHCP (Secondary)** | 192.168.1.134 | DHCP HA failover |
| **Traefik** | LXC 110 @ 192.168.1.110 | Reverse proxy/TLS termination |
| **Uptime Kuma** | LXC 132 @ 192.168.1.132 | Service monitoring |
| **Homepage** | LXC 150 @ 192.168.1.45 | Service dashboard |

---

## Prerequisites

### Required Information

Before starting deployment, gather:

- [ ] Service name (e.g., `tandoor`, `grafana`)
- [ ] Desired LXC ID (check available IDs)
- [ ] Target IP address (verify not in use)
- [ ] Service listening port(s)
- [ ] Resource requirements (CPU, RAM, disk)
- [ ] Application-specific dependencies
- [ ] SSL certificate requirements

### Required Access

- [ ] Root SSH access to Proxmox nodes
- [ ] SSH access to infrastructure services (Traefik, DHCP, etc.)
- [ ] Access to service source code/installation packages
- [ ] GitHub/Git repository access (if applicable)

### Tools Required

```bash
# Verify you have access to these tools
ssh root@192.168.1.137 "echo 'Proxmox node 1 OK'"
ssh root@192.168.1.125 "echo 'Proxmox node 2 OK'"
ssh root@192.168.1.126 "echo 'Proxmox node 3 OK'"
ssh root@192.168.1.133 "echo 'Kea Primary OK'"
ssh root@192.168.1.110 "echo 'Traefik OK'"
```

---

## Pre-Deployment Checklist

### 1. IP Address Planning

```bash
# Check if IP is in use
ping -c 2 192.168.1.XXX

# Check for IP conflicts in DHCP leases
ssh root@192.168.1.133 "grep '192.168.1.XXX' /etc/kea/kea-dhcp4.conf"

# Check for DNS conflicts
ssh root@192.168.1.110 "grep '192.168.1.XXX' /etc/traefik/dynamic/*.yml"
```

### 2. LXC ID Selection

```bash
# List existing containers on all nodes
for node in 192.168.1.137 192.168.1.125 192.168.1.126; do
  echo "=== Node $node ==="
  ssh root@$node "pct list"
done

# Verify specific ID is available
LXC_ID=XXX
for node in 192.168.1.137 192.168.1.125 192.168.1.126; do
  ssh root@$node "pct list | grep -w $LXC_ID" && echo "ID $LXC_ID in use on $node"
done
```

### 3. Resource Planning

Document resource allocation:
- **CPU cores:** X cores
- **RAM:** X GB
- **Disk:** X GB
- **Network:** bridged to vmbr0
- **Backup schedule:** Daily/Weekly

---

## Deployment Steps

### Step 1: Container Creation and Base Configuration

#### 1.1 Create LXC Container

```bash
# Option 1: Create via Proxmox Web UI
# - Select appropriate node based on resource availability
# - Choose Debian/Ubuntu template
# - Configure resources as planned

# Option 2: Create via CLI (example for Debian 12)
NODE="192.168.1.XXX"  # Select node
LXC_ID="XXX"
HOSTNAME="service-name"
IP="192.168.1.XXX"
GATEWAY="192.168.1.1"

ssh root@$NODE "pct create $LXC_ID local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname $HOSTNAME \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=$IP/24,gw=$GATEWAY \
  --onboot 1 \
  --unprivileged 1"

# Start the container
ssh root@$NODE "pct start $LXC_ID"
```

#### 1.2 Configure SSH Access

```bash
# Get your SSH public key
cat ~/.ssh/id_rsa.pub

# Deploy SSH key to container
ssh root@$NODE "pct exec $LXC_ID -- bash -c '
  apt-get update && apt-get install -y openssh-server
  systemctl enable ssh
  systemctl start ssh
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  echo \"YOUR_SSH_PUBLIC_KEY\" > ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo \"SSH key deployed\"
'"

# Add host to known_hosts and test connection
ssh-keyscan -H $IP >> ~/.ssh/known_hosts
ssh root@$IP "hostname && echo 'SSH connection successful'"
```

#### 1.3 Initial System Configuration

```bash
# Update system packages
ssh root@$IP "apt-get update && apt-get upgrade -y && apt-get autoremove -y"

# Set timezone (if needed)
ssh root@$IP "timedatectl set-timezone America/Chicago"

# Install common utilities
ssh root@$IP "apt-get install -y curl wget git vim htop net-tools dnsutils"
```

---

### Step 2: Network Infrastructure Configuration

#### 2.1 Create DHCP Reservation

```bash
SERVICE_NAME="service-name"
IP_ADDRESS="192.168.1.XXX"
MAC_ADDRESS="XX:XX:XX:XX:XX:XX"  # Get from: pct config $LXC_ID | grep hwaddr

# Download current Kea config
scp root@192.168.1.133:/etc/kea/kea-dhcp4.conf /tmp/kea-dhcp4.conf

# Create Python script to add reservation
python3 << 'EOFPYTHON'
import json
import sys

# Read the config
with open('/tmp/kea-dhcp4.conf', 'r') as f:
    config = json.load(f)

# Find the 192.168.1.0/24 subnet
for subnet in config['Dhcp4']['subnet4']:
    if subnet['subnet'] == '192.168.1.0/24':
        if 'reservations' not in subnet:
            subnet['reservations'] = []

        # Check if already exists
        exists = False
        for res in subnet['reservations']:
            if res.get('hw-address') == 'MAC_ADDRESS':
                exists = True
                print(f"Reservation already exists: {res}")
                break

        if not exists:
            new_res = {
                "hw-address": "MAC_ADDRESS",
                "ip-address": "IP_ADDRESS",
                "hostname": "SERVICE_NAME"
            }

            # Insert at beginning of reservations array
            subnet['reservations'].insert(0, new_res)
            print(f"Added new reservation: {new_res}")

            # Save the updated config
            with open('/tmp/kea-dhcp4-updated.conf', 'w') as f:
                json.dump(config, f, indent=2)
            print("Config saved to /tmp/kea-dhcp4-updated.conf")
        break
EOFPYTHON

# Replace placeholders in the updated config
sed -i "s/MAC_ADDRESS/$MAC_ADDRESS/g" /tmp/kea-dhcp4-updated.conf
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" /tmp/kea-dhcp4-updated.conf
sed -i "s/SERVICE_NAME/$SERVICE_NAME/g" /tmp/kea-dhcp4-updated.conf

# Upload to both Kea servers
scp /tmp/kea-dhcp4-updated.conf root@192.168.1.133:/etc/kea/kea-dhcp4.conf
scp /tmp/kea-dhcp4-updated.conf root@192.168.1.134:/etc/kea/kea-dhcp4.conf

# Reload Kea on both servers
ssh root@192.168.1.133 "systemctl reload isc-kea-dhcp4-server"
ssh root@192.168.1.134 "systemctl reload isc-kea-dhcp4-server"

# Verify reservation
ssh root@192.168.1.133 "grep -A3 '$MAC_ADDRESS' /etc/kea/kea-dhcp4.conf"
```

#### 2.2 Configure DNS Rewrites (AdGuard)

**Prerequisites:**
- Service uses `*.internal.lakehouse.wtf` domain
- AdGuard DNS servers handle local DNS resolution

```bash
SERVICE_NAME="service-name"
DOMAIN="$SERVICE_NAME.internal.lakehouse.wtf"
TRAEFIK_IP="192.168.1.110"

# Backup AdGuard configurations
ssh root@192.168.1.253 "cp /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/AdGuardHome.yaml.backup-\$(date +%Y%m%d)"
ssh root@192.168.1.224 "cp /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/AdGuardHome.yaml.backup-\$(date +%Y%m%d)"

# Add DNS rewrite to primary AdGuard
ssh root@192.168.1.253 "sed -i '/rewrites:/a\\    - domain: $DOMAIN\\n      answer: $TRAEFIK_IP\\n      enabled: true' /opt/AdGuardHome/AdGuardHome.yaml"

# Add DNS rewrite to secondary AdGuard
ssh root@192.168.1.224 "sed -i '/rewrites:/a\\    - domain: $DOMAIN\\n      answer: $TRAEFIK_IP\\n      enabled: true' /opt/AdGuardHome/AdGuardHome.yaml"

# Restart AdGuard services
ssh root@192.168.1.253 "systemctl restart AdGuardHome"
ssh root@192.168.1.224 "systemctl restart AdGuardHome"

# Wait for services to restart
sleep 3

# Verify DNS resolution
dig +short $DOMAIN
# Expected: 192.168.1.110

# Test from both DNS servers
dig +short @192.168.1.253 $DOMAIN
dig +short @192.168.1.224 $DOMAIN
```

#### 2.3 Configure Traefik Reverse Proxy

**Prerequisites:**
- Service must be listening on HTTP (HTTPS termination handled by Traefik)
- Determine service health check endpoint

```bash
SERVICE_NAME="service-name"
DOMAIN="$SERVICE_NAME.internal.lakehouse.wtf"
BACKEND_IP="192.168.1.XXX"
BACKEND_PORT="80"  # or 8080, 3000, etc.
HEALTH_PATH="/"    # or /health, /api/health, etc.

# Add router configuration
ssh root@192.168.1.110 "cat >> /etc/traefik/dynamic/routers.yml << EOF
    ${SERVICE_NAME}-router:
      rule: Host(\\\`${DOMAIN}\\\`)
      service: ${SERVICE_NAME}-service
      entryPoints:
      - websecure
      middlewares:
      - esphome-iframe-headers
      tls:
        certResolver: cloudflare
        domains:
        - main: '*.internal.lakehouse.wtf'
EOF
echo 'Router configuration added'"

# Add service configuration
ssh root@192.168.1.110 "cat >> /etc/traefik/dynamic/services.yml << EOF
    ${SERVICE_NAME}-service:
      loadBalancer:
        servers:
        - url: http://${BACKEND_IP}:${BACKEND_PORT}
        healthCheck:
          path: ${HEALTH_PATH}
          interval: 30s
          timeout: 5s
EOF
echo 'Service configuration added'"

# Restart Traefik to apply changes
ssh root@192.168.1.110 "systemctl restart traefik"

# Wait for Traefik to restart
sleep 3

# Test the service
curl -k -I https://${DOMAIN}
```

---

### Step 3: Service Installation and Configuration

**Note:** This section is application-specific. Document the steps for your particular service.

#### 3.1 General Service Installation Pattern

```bash
# Example for a typical web application

# 1. Install runtime dependencies (Node.js, Python, etc.)
ssh root@$IP "apt-get install -y python3 python3-pip python3-venv"

# 2. Create service user (optional but recommended)
ssh root@$IP "useradd -r -s /bin/bash -d /opt/$SERVICE_NAME $SERVICE_NAME"

# 3. Clone/download application
ssh root@$IP "cd /opt && git clone https://github.com/user/repo.git $SERVICE_NAME"

# 4. Install dependencies
ssh root@$IP "cd /opt/$SERVICE_NAME && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"

# 5. Create environment/config files
ssh root@$IP "cat > /opt/$SERVICE_NAME/.env << 'EOFENV'
DATABASE_URL=...
SECRET_KEY=...
ALLOWED_HOSTS=$DOMAIN,$IP
EOFENV"

# 6. Initialize database (if applicable)
ssh root@$IP "cd /opt/$SERVICE_NAME && source venv/bin/activate && python manage.py migrate"

# 7. Create systemd service
ssh root@$IP "cat > /etc/systemd/system/$SERVICE_NAME.service << 'EOFSVC'
[Unit]
Description=$SERVICE_NAME Service
After=network.target

[Service]
Type=simple
User=$SERVICE_NAME
WorkingDirectory=/opt/$SERVICE_NAME
ExecStart=/opt/$SERVICE_NAME/venv/bin/gunicorn --bind 0.0.0.0:8000 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFSVC"

# 8. Enable and start service
ssh root@$IP "systemctl daemon-reload && systemctl enable $SERVICE_NAME && systemctl start $SERVICE_NAME"

# 9. Verify service status
ssh root@$IP "systemctl status $SERVICE_NAME"
```

#### 3.2 Configure Web Server (if needed)

For services using nginx as a reverse proxy:

```bash
# Install nginx
ssh root@$IP "apt-get install -y nginx"

# Create nginx site config
ssh root@$IP "cat > /etc/nginx/sites-available/$SERVICE_NAME << 'EOFNGINX'
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    client_max_body_size 128M;

    # Static files
    location /static/ {
        alias /opt/$SERVICE_NAME/static/;
    }

    # Media files
    location /media/ {
        alias /opt/$SERVICE_NAME/media/;
    }

    # Proxy to application
    location / {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:8000;
    }
}
EOFNGINX"

# Enable site and remove default
ssh root@$IP "ln -sf /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/$SERVICE_NAME"
ssh root@$IP "rm -f /etc/nginx/sites-enabled/default"

# Test and reload nginx
ssh root@$IP "nginx -t && systemctl reload nginx"
```

---

### Step 4: Monitoring and Dashboard Integration

#### 4.1 Add to Uptime Kuma

**Note:** Uptime Kuma doesn't have a good CLI API, so this must be done via Web UI.

1. Navigate to https://uptime.internal.lakehouse.wtf
2. Click "Add New Monitor"
3. Configure monitor:
   - **Monitor Type:** HTTP(s)
   - **Friendly Name:** `Service Name (Production)`
   - **URL:** `https://service-name.internal.lakehouse.wtf`
   - **Heartbeat Interval:** 60 seconds
   - **Retries:** 3
   - **HTTP Method:** GET
   - **Expected Status Code:** 200
   - **Notification:** Select appropriate notification groups
4. Click "Save"

#### 4.2 Add to Homepage Dashboard

```bash
SERVICE_NAME="service-name"
SERVICE_DISPLAY_NAME="Service Name"
SERVICE_DESCRIPTION="Brief description of service"
SERVICE_URL="https://$SERVICE_NAME.internal.lakehouse.wtf"
ICON_NAME="service-icon"  # See https://gethomepage.dev/latest/configs/service-widgets/

# Get current Homepage config
ssh root@192.168.1.137 "pct exec 150 -- cat /home/homepage/homepage/config/services.yaml" > /tmp/homepage-services.yaml

# Add service entry (manual edit or script)
# Edit /tmp/homepage-services.yaml to add:
cat >> /tmp/homepage-services.yaml << EOF

    - $SERVICE_DISPLAY_NAME:
        icon: $ICON_NAME
        href: $SERVICE_URL
        description: $SERVICE_DESCRIPTION
        widget:
          type: customapi
          url: $SERVICE_URL/api/status
          method: GET
EOF

# Upload updated config
scp /tmp/homepage-services.yaml root@192.168.1.137:/tmp/homepage-services.yaml
ssh root@192.168.1.137 "pct exec 150 -- cp /tmp/homepage-services.yaml /home/homepage/homepage/config/services.yaml"

# Restart Homepage to apply changes
ssh root@192.168.1.137 "pct exec 150 -- systemctl restart homepage"
```

---

## Post-Deployment Validation

### Validation Checklist

Complete this checklist after deployment:

#### Infrastructure Validation

- [ ] **Container Status**
  ```bash
  ssh root@$NODE "pct list | grep $LXC_ID"
  ssh root@$NODE "pct status $LXC_ID"
  ```

- [ ] **SSH Access**
  ```bash
  ssh root@$IP "hostname && uptime"
  ```

- [ ] **Network Connectivity**
  ```bash
  ssh root@$IP "ping -c 3 8.8.8.8"
  ssh root@$IP "ping -c 3 google.com"
  ```

- [ ] **DHCP Reservation**
  ```bash
  ssh root@192.168.1.133 "grep -A3 '$MAC_ADDRESS' /etc/kea/kea-dhcp4.conf"
  ```

- [ ] **Traefik Routing**
  ```bash
  curl -k -I https://$DOMAIN | head -5
  ```

- [ ] **DNS Resolution**
  ```bash
  nslookup $DOMAIN 192.168.1.1
  ```

#### Service Validation

- [ ] **Service Running**
  ```bash
  ssh root@$IP "systemctl status $SERVICE_NAME"
  ```

- [ ] **Service Listening on Port**
  ```bash
  ssh root@$IP "ss -tlnp | grep :$BACKEND_PORT"
  ```

- [ ] **Local Service Response**
  ```bash
  ssh root@$IP "curl -I http://localhost:$BACKEND_PORT"
  ```

- [ ] **External HTTPS Access**
  ```bash
  curl -k https://$DOMAIN
  ```

- [ ] **Health Check Endpoint**
  ```bash
  curl -k https://$DOMAIN$HEALTH_PATH
  ```

#### Monitoring Validation

- [ ] **Uptime Kuma Monitor Added**
  - Check https://uptime.internal.lakehouse.wtf

- [ ] **Homepage Entry Added**
  - Check https://homepage.internal.lakehouse.wtf (or appropriate URL)

- [ ] **Service Logs Clean**
  ```bash
  ssh root@$IP "journalctl -u $SERVICE_NAME -n 50 --no-pager"
  ```

#### Documentation

- [ ] Service documented in inventory
- [ ] Credentials stored securely (if applicable)
- [ ] Backup plan configured
- [ ] Recovery procedures documented

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: SSH Connection Refused

```bash
# Symptoms
ssh root@$IP
# ssh: connect to host X.X.X.X port 22: Connection refused

# Diagnosis
ssh root@$NODE "pct exec $LXC_ID -- systemctl status ssh"

# Solution 1: SSH not installed
ssh root@$NODE "pct exec $LXC_ID -- apt-get install -y openssh-server"

# Solution 2: SSH not started
ssh root@$NODE "pct exec $LXC_ID -- systemctl enable ssh && systemctl start ssh"

# Solution 3: Firewall blocking
ssh root@$NODE "pct exec $LXC_ID -- iptables -L -n | grep 22"
```

#### Issue: IP Conflict

```bash
# Symptoms
ping $IP
# Shows wrong hostname or device

# Diagnosis
arp -a | grep $IP
for host in 192.168.1.{1..254}; do
  ping -c 1 -W 1 $host &>/dev/null && echo "$host is up"
done

# Solution: Change to different IP
# Update container config
ssh root@$NODE "pct set $LXC_ID -net0 name=eth0,bridge=vmbr0,gw=192.168.1.1,hwaddr=$MAC,ip=$NEW_IP/24,type=veth"
ssh root@$NODE "pct exec $LXC_ID -- systemctl restart networking"
```

#### Issue: Traefik 502 Bad Gateway

```bash
# Symptoms
curl -k https://$DOMAIN
# HTTP/2 502

# Diagnosis 1: Service not running
ssh root@$IP "systemctl status $SERVICE_NAME"

# Diagnosis 2: Service not listening
ssh root@$IP "ss -tlnp | grep :$BACKEND_PORT"

# Diagnosis 3: Wrong backend IP/port
ssh root@192.168.1.110 "grep -A5 '$SERVICE_NAME-service' /etc/traefik/dynamic/services.yml"

# Diagnosis 4: Health check failing
curl -k http://$BACKEND_IP:$BACKEND_PORT$HEALTH_PATH

# Solution: Check Traefik logs
ssh root@192.168.1.110 "journalctl -u traefik -n 50 --no-pager"
```

#### Issue: Service Hanging/Not Responding

```bash
# Diagnosis 1: Check process status
ssh root@$IP "ps aux | grep $SERVICE_NAME"

# Diagnosis 2: Check resource usage
ssh root@$IP "top -bn1 | head -20"

# Diagnosis 3: Check application logs
ssh root@$IP "journalctl -u $SERVICE_NAME -n 100 --no-pager"
ssh root@$IP "tail -50 /opt/$SERVICE_NAME/logs/*.log"

# Diagnosis 4: Check database connectivity (if applicable)
ssh root@$IP "cd /opt/$SERVICE_NAME && source venv/bin/activate && python -c 'import django; django.setup(); from django.db import connection; connection.ensure_connection(); print(\"DB OK\")'"

# Solution 1: Restart service
ssh root@$IP "systemctl restart $SERVICE_NAME"

# Solution 2: Check environment variables
ssh root@$IP "cat /opt/$SERVICE_NAME/.env"
ssh root@$IP "systemctl show $SERVICE_NAME | grep Environment"
```

#### Issue: DHCP Reservation Not Working

```bash
# Diagnosis 1: Verify reservation exists
ssh root@192.168.1.133 "grep -A3 '$MAC_ADDRESS' /etc/kea/kea-dhcp4.conf"

# Diagnosis 2: Check Kea service status
ssh root@192.168.1.133 "systemctl status isc-kea-dhcp4-server"

# Diagnosis 3: Check Kea logs
ssh root@192.168.1.133 "journalctl -u isc-kea-dhcp4-server -n 50 --no-pager"

# Solution 1: Reload Kea
ssh root@192.168.1.133 "systemctl reload isc-kea-dhcp4-server"

# Solution 2: Restart container networking
ssh root@$NODE "pct exec $LXC_ID -- systemctl restart networking"

# Solution 3: Force DHCP renewal
ssh root@$NODE "pct exec $LXC_ID -- dhclient -r && dhclient eth0"
```

#### Issue: Certificate/TLS Errors

```bash
# Diagnosis
curl -vk https://$DOMAIN 2>&1 | grep -i "certificate\|ssl\|tls"

# Check Traefik TLS configuration
ssh root@192.168.1.110 "grep -A10 'tls:' /etc/traefik/dynamic/routers.yml | grep -A10 '$SERVICE_NAME'"

# Check Traefik certificate resolver
ssh root@192.168.1.110 "cat /etc/traefik/traefik.yml | grep -A20 certificatesResolvers"

# Solution: Verify wildcard cert covers service
# Ensure service uses *.internal.lakehouse.wtf domain
```

---

## Rollback Procedures

### Container Rollback

If deployment fails and rollback is needed:

```bash
# Option 1: Stop and destroy container
ssh root@$NODE "pct stop $LXC_ID"
ssh root@$NODE "pct destroy $LXC_ID"

# Option 2: Restore from backup (if backup exists)
ssh root@$NODE "pct restore $LXC_ID /path/to/backup.tar.gz"

# Clean up DHCP reservation
ssh root@192.168.1.133 "cp /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.rollback"
# Manually edit to remove reservation, then:
ssh root@192.168.1.133 "systemctl reload isc-kea-dhcp4-server"

# Clean up Traefik configuration
ssh root@192.168.1.110 "cp /etc/traefik/dynamic/routers.yml /etc/traefik/dynamic/routers.yml.rollback"
ssh root@192.168.1.110 "cp /etc/traefik/dynamic/services.yml /etc/traefik/dynamic/services.yml.rollback"
# Manually edit to remove service entries, then:
ssh root@192.168.1.110 "systemctl restart traefik"
```

### Service Rollback

If service needs to be rolled back to previous version:

```bash
# Stop service
ssh root@$IP "systemctl stop $SERVICE_NAME"

# Restore previous version (git example)
ssh root@$IP "cd /opt/$SERVICE_NAME && git checkout <previous-commit-hash>"

# Restore database (if schema changed)
ssh root@$IP "cd /opt/$SERVICE_NAME && source venv/bin/activate && python manage.py migrate <previous-migration>"

# Restart service
ssh root@$IP "systemctl start $SERVICE_NAME"
```

---

## References

### Infrastructure Documentation

- **Proxmox Cluster:** 3-node HA cluster at 192.168.1.137, 192.168.1.125, 192.168.1.126
- **Kea DHCP HA:** Primary at 192.168.1.133, Secondary at 192.168.1.134
  - Config location: `/etc/kea/kea-dhcp4.conf`
  - Service: `isc-kea-dhcp4-server`
- **Traefik:** LXC 110 at 192.168.1.110
  - Config: `/etc/traefik/traefik.yml` (static), `/etc/traefik/dynamic/*.yml` (dynamic)
  - Service: `traefik.service`
- **Uptime Kuma:** LXC 132 at 192.168.1.132
  - Web UI: https://uptime.internal.lakehouse.wtf
- **Homepage:** LXC 150 at 192.168.1.45
  - Config: `/home/homepage/homepage/config/services.yaml`

### Related Documentation

- [Traefik Setup Complete](../TRAEFIK_SETUP_COMPLETE.md)
- [Proxmox HA Cluster Audit](../PROXMOX_HA_CLUSTER_AUDIT_REPORT.md)
- [Kea DHCP Migration](../.serena/memories/kea_dhcp_migration_from_adguard_complete.md)

### External Resources

- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kea DHCP Documentation](https://kea.readthedocs.io/)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-19 | Infrastructure Team | Initial SOP creation based on Tandoor deployment |

---

## Appendix A: Quick Reference Commands

### Find Container Location
```bash
for node in 192.168.1.137 192.168.1.125 192.168.1.126; do
  ssh root@$node "pct list | grep -w $LXC_ID" && echo "Found on $node" && break
done
```

### Check Container Status
```bash
ssh root@$NODE "pct status $LXC_ID"
ssh root@$NODE "pct config $LXC_ID"
```

### Execute Command in Container
```bash
ssh root@$NODE "pct exec $LXC_ID -- COMMAND"
```

### View Service Logs
```bash
ssh root@$IP "journalctl -u $SERVICE_NAME -f"
```

### Test Service Health
```bash
curl -k https://$DOMAIN$HEALTH_PATH
```

### Restart All Critical Services
```bash
# Restart application
ssh root@$IP "systemctl restart $SERVICE_NAME"

# Restart nginx (if applicable)
ssh root@$IP "systemctl restart nginx"

# Restart Traefik
ssh root@192.168.1.110 "systemctl restart traefik"
```

---

## Appendix B: Service Deployment Template

Use this template for documenting new service deployments:

```markdown
# [Service Name] Deployment

**Date:** YYYY-MM-DD
**LXC ID:** XXX
**IP Address:** 192.168.1.XXX
**MAC Address:** XX:XX:XX:XX:XX:XX
**Node:** 192.168.1.XXX

## Service Details
- **Purpose:** [Brief description]
- **Port:** XXXX
- **Domain:** service.internal.lakehouse.wtf
- **Health Check:** /path/to/health

## Resources
- **CPU:** X cores
- **RAM:** X GB
- **Disk:** X GB

## Special Configuration
[Any service-specific configuration notes]

## Deployment Notes
[Any issues encountered or special steps taken]

## Validation Results
- [ ] Service accessible via HTTPS
- [ ] Health check passing
- [ ] Added to Uptime Kuma
- [ ] Added to Homepage
- [ ] DHCP reservation active

## Rollback Plan
[Service-specific rollback instructions]
```

---

**End of SOP**
