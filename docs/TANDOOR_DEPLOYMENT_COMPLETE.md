# Tandoor Recipes Deployment - COMPLETE ✅

**Date:** 2025-11-19
**LXC ID:** 108
**Original IP:** 192.168.1.57 (conflicted)
**New IP:** 192.168.1.108
**MAC Address:** bc:24:11:c6:97:b1
**Proxmox Node:** 192.168.1.125
**Installation Method:** [Proxmox Community Scripts](https://community-scripts.github.io/ProxmoxVE/scripts?id=tandoor)

---

## Deployment Summary

Tandoor Recipes has been successfully deployed and configured with full infrastructure integration.

**Access URL:** https://tandoor.internal.lakehouse.wtf

---

## Infrastructure Configuration

### 1. Container Details

```yaml
LXC ID: 108
Hostname: tandoor
IP Address: 192.168.1.108/24
Gateway: 192.168.1.1
MAC Address: bc:24:11:c6:97:b1
Resources:
  CPU: 2 cores
  RAM: 2048 MB
  Disk: 20 GB
OS: Debian 12 (Bookworm)
```

### 2. Network Configuration

#### DHCP Reservation
- **Primary Kea Server:** 192.168.1.133 ✅
- **Secondary Kea Server:** 192.168.1.134 ✅
- **Reservation:** bc:24:11:c6:97:b1 → 192.168.1.108 (hostname: tandoor)

#### Traefik Reverse Proxy
- **Domain:** tandoor.internal.lakehouse.wtf
- **Backend:** http://192.168.1.108:8002
- **TLS:** Cloudflare wildcard certificate (*.internal.lakehouse.wtf)
- **Health Check:** / (30s interval, 5s timeout)
- **Middleware:** esphome-iframe-headers

### 3. Service Configuration

#### Application
- **Framework:** Django (Tandoor Recipes)
- **Web Server:** nginx → gunicorn
- **Port:** 8002 (default from community script)
- **Service:** gunicorn_tandoor.service

#### System Updates Applied
```
Upgraded 14 packages including:
- PostgreSQL 16.10 → 16.11
- OpenSSL 3.0.17-1~deb12u2 → 3.0.17-1~deb12u3
- bind9-libs 1:9.18.33 → 1:9.18.41
- linux-libc-dev 6.1.153 → 6.1.158
```

---

## Issues Encountered and Resolved

### Issue 1: IP Address Conflict
**Problem:** Original IP 192.168.1.57 was in use by a Samsung device

**Resolution:**
1. Changed container IP from 192.168.1.57 to 192.168.1.108
2. Updated Proxmox container network configuration
3. Restarted networking service
4. Created DHCP reservation for new IP

**Commands Used:**
```bash
ssh root@192.168.1.125 "pct set 108 -net0 name=eth0,bridge=vmbr0,gw=192.168.1.1,hwaddr=BC:24:11:C6:97:B1,ip=192.168.1.108/24,type=veth"
ssh root@192.168.1.125 "pct exec 108 -- systemctl restart networking"
```

### Issue 2: Wrong Port Configuration
**Problem:** Initially configured Traefik to use port 80, but Tandoor community script uses port 8002

**Root Cause:**
- Assumed standard HTTP port
- Didn't check community script defaults
- Created incorrect nginx reverse proxy configuration

**Resolution:**
1. Discovered via web search that community script uses port 8002
2. Verified with `ss -tlnp | grep :8002`
3. Updated Traefik service configuration:
   ```yaml
   url: http://192.168.1.108:8002  # Changed from :80
   ```
4. Removed custom nginx site configuration (not needed)
5. Restored default nginx config
6. Restarted Traefik

**Key Lesson:** Always check community script documentation for default ports and configuration before making assumptions.

### Issue 3: SSH Connectivity
**Problem:** SSH connection refused after IP change

**Resolution:**
- SSH service was running but needed time to bind to new IP
- Added SSH key via Proxmox pct exec
- Connection worked after waiting for network restart to complete

---

## Validation Results

### Infrastructure Checks ✅

- [x] Container running and accessible
- [x] SSH access configured with public key
- [x] DHCP reservation active on both Kea servers
- [x] Traefik router configured correctly
- [x] Traefik service backend pointing to port 8002
- [x] DNS resolution working
- [x] TLS certificate applied (Cloudflare wildcard)

### Service Checks ✅

- [x] gunicorn_tandoor.service running
- [x] nginx listening on port 8002
- [x] Service responds to local HTTP requests
- [x] Service responds via Traefik HTTPS
- [x] Health check endpoint responding (302 → /search/)
- [x] Login page loads correctly

### Test Results

```bash
# Direct access test
$ curl -I http://192.168.1.108:8002
HTTP/1.1 302 Found
Server: nginx/1.22.1
Location: /search/

# HTTPS via Traefik test
$ curl -kL -I https://tandoor.internal.lakehouse.wtf
HTTP/2 302
content-type: text/html; charset=utf-8
location: /search/
x-frame-options: DENY
```

---

## Monitoring and Dashboard Integration

### Uptime Kuma
**Status:** ⚠️ Manual configuration required

To add Tandoor monitoring:
1. Navigate to https://uptime.internal.lakehouse.wtf
2. Add New Monitor
   - Type: HTTP(s)
   - Name: Tandoor Recipes (Production)
   - URL: https://tandoor.internal.lakehouse.wtf
   - Interval: 60 seconds
   - Expected Status: 302 (redirects to /search/)

### Homepage Dashboard
**Status:** ⚠️ Manual configuration required

To add Tandoor to Homepage:
1. Edit `/home/homepage/homepage/config/services.yaml` on LXC 150
2. Add entry:
   ```yaml
   - Tandoor Recipes:
       icon: tandoor
       href: https://tandoor.internal.lakehouse.wtf
       description: Recipe manager and meal planner
   ```
3. Restart Homepage service

---

## Access Information

### Web Interface
- **URL:** https://tandoor.internal.lakehouse.wtf
- **Default Login:** Follow on-screen instructions to create admin user

### SSH Access
```bash
ssh root@192.168.1.108
```

### Container Management
```bash
# Via Proxmox node
ssh root@192.168.1.125 "pct list | grep 108"
ssh root@192.168.1.125 "pct status 108"
ssh root@192.168.1.125 "pct exec 108 -- COMMAND"
```

### Service Management
```bash
# Check service status
ssh root@192.168.1.108 "systemctl status gunicorn_tandoor"

# Restart service
ssh root@192.168.1.108 "systemctl restart gunicorn_tandoor"

# View logs
ssh root@192.168.1.108 "journalctl -u gunicorn_tandoor -f"
```

---

## Configuration Files

### Kea DHCP
```
Primary: /etc/kea/kea-dhcp4.conf on 192.168.1.133
Secondary: /etc/kea/kea-dhcp4.conf on 192.168.1.134
```

### Traefik
```
Router: /etc/traefik/dynamic/routers.yml on 192.168.1.110
Service: /etc/traefik/dynamic/services.yml on 192.168.1.110
```

### Tandoor Application
```
Application Root: /opt/tandoor
Environment: /opt/tandoor/.env
Service File: /etc/systemd/system/gunicorn_tandoor.service
Nginx Config: /etc/nginx/nginx.conf (default)
```

---

## Maintenance

### Update Tandoor
```bash
# Via community script update
ssh root@192.168.1.108
# Run the installation command again or type 'update' in LXC console
```

### Backup Strategy
- Container included in Proxmox backup schedule
- Database: PostgreSQL at localhost:5432
- Media files: /opt/tandoor/mediafiles/
- Static files: /opt/tandoor/staticfiles/

### Recovery Procedure
1. Restore LXC from Proxmox backup
2. Verify IP configuration matches DHCP reservation
3. Verify Traefik configuration intact
4. Test service accessibility

---

## Lessons Learned

### For Future Deployments

1. **Always check community script documentation** for default ports and configuration
   - Don't assume standard ports (80, 8080, etc.)
   - Review script source on GitHub if documentation unclear

2. **Verify port before configuring reverse proxy**
   ```bash
   ss -tlnp | grep LISTEN
   ```

3. **Test direct access before configuring Traefik**
   ```bash
   curl -I http://IP:PORT
   ```

4. **Check for IP conflicts before assigning**
   ```bash
   ping -c 2 TARGET_IP
   arp -a | grep TARGET_IP
   ```

5. **Document original configuration** before making changes
   - Take backups of config files
   - Note original settings

6. **Use incremental testing**
   - Test service locally first
   - Then test via reverse proxy
   - Finally test via HTTPS/domain

---

## Related Documentation

- [LXC Service Deployment SOP](./LXC_SERVICE_DEPLOYMENT_SOP.md)
- [Traefik Setup Complete](../TRAEFIK_SETUP_COMPLETE.md)
- [Kea DHCP Migration](../.serena/memories/kea_dhcp_migration_from_adguard_complete.md)

---

## Quick Reference

```bash
# Service Status
systemctl status gunicorn_tandoor

# View Logs
journalctl -u gunicorn_tandoor -f

# Restart Service
systemctl restart gunicorn_tandoor

# Test Local Access
curl -I http://localhost:8002

# Test External Access
curl -kL -I https://tandoor.internal.lakehouse.wtf

# Container Console
pct enter 108  # From Proxmox node 192.168.1.125
```

---

**Deployment Completed By:** Claude Code AI Assistant
**Deployment Status:** ✅ PRODUCTION READY
**Next Steps:** Manual configuration of Uptime Kuma monitoring and Homepage dashboard entry
