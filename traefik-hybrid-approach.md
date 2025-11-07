# Traefik Hybrid Configuration Guide

Your Traefik setup now uses a **hybrid approach**:
- **Static YAML files** for production services (recommended)
- **Proxmox plugin labels** for dev/testing containers (optional)

## ✅ New Static Routes Added

Successfully added routes for these services:

| Service | URL | Backend | Status |
|---------|-----|---------|--------|
| Grafana | https://grafana.internal.lakehouse.wtf | 192.168.1.140:3000 | ✅ Working |
| Hoarder | https://hoarder.internal.lakehouse.wtf | 192.168.1.102:3000 | ✅ Working |
| Memos | https://memos.internal.lakehouse.wtf | 192.168.1.144:9030 | ✅ Working |
| GitOps Dashboard | https://gitops.internal.lakehouse.wtf | 192.168.1.136:3070 | ✅ Working |

### How Static Routes Work

**Configuration Files:**
- `/etc/traefik/dynamic/routers.yml` - Route definitions (which domain goes where)
- `/etc/traefik/dynamic/services.yml` - Backend service definitions (IP:port)

**Advantages:**
1. ✅ Git version control
2. ✅ Works even if Proxmox API is down
3. ✅ Complex middlewares (IP whitelisting, custom headers)
4. ✅ Path-based routing and advanced rules
5. ✅ Predictable and stable

**When to Use:**
- Production services
- Services requiring complex routing rules
- Services with custom middleware chains
- Long-running stable services

---

## 🔧 Using Proxmox Plugin Labels (Dev/Testing)

The Proxmox provider plugin automatically discovers containers with `traefik.enable=true` labels.

### How to Enable Plugin Auto-Discovery

**Step 1: Add labels to container config**

```bash
# Edit container config
pct set <VMID> -description "$(cat <<'LABELS'
traefik.enable=true
traefik.http.routers.myservice.rule=Host(`myservice.internal.lakehouse.wtf`)
traefik.http.routers.myservice.entrypoints=websecure
traefik.http.routers.myservice.tls.certresolver=cloudflare
traefik.http.services.myservice.loadbalancer.server.port=8080
LABELS
)"
```

**Step 2: Restart container**

```bash
pct restart <VMID>
```

The plugin polls Proxmox every 30 seconds and will automatically create the route!

### Label Format

The plugin reads labels from the container's **description** field in Proxmox.

**Required Labels:**
```
traefik.enable=true
traefik.http.routers.<name>.rule=Host(`domain.internal.lakehouse.wtf`)
traefik.http.services.<name>.loadbalancer.server.port=<PORT>
```

**Optional Labels:**
```
traefik.http.routers.<name>.entrypoints=websecure
traefik.http.routers.<name>.tls.certresolver=cloudflare
traefik.http.routers.<name>.middlewares=secure-headers
```

### Complete Example: Dev Container with Auto-Discovery

```bash
# Create a test container (example using a simple nginx)
pct create 9999 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname test-app \
  --memory 512 \
  --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.250/24,gw=192.168.1.1 \
  --unprivileged 1

# Add Traefik labels to description
pct set 9999 -description "$(cat <<'LABELS'
Test application with Traefik auto-discovery

traefik.enable=true
traefik.http.routers.testapp.rule=Host(`testapp.internal.lakehouse.wtf`)
traefik.http.routers.testapp.entrypoints=websecure
traefik.http.routers.testapp.tls.certresolver=cloudflare
traefik.http.services.testapp.loadbalancer.server.port=80
LABELS
)"

# Start the container
pct start 9999

# Install nginx inside container
pct exec 9999 -- bash -c "apt update && apt install -y nginx"

# Wait 30 seconds for plugin to discover it
sleep 35

# Test the route
curl -k https://testapp.internal.lakehouse.wtf
```

### Viewing Discovered Routes

Check if the plugin discovered your container:

```bash
# View Traefik logs
tail -f /var/log/traefik/traefik.log | grep -E 'plugin|proxmox'

# Check Traefik dashboard
# https://traefik.internal.lakehouse.wtf
```

---

## 📊 When to Use Each Approach

### Use Static YAML Files When:
- ✅ Production services
- ✅ Need complex middleware chains
- ✅ Need path-based routing (`/api`, `/admin`, etc.)
- ✅ Want version control and GitOps
- ✅ Need weighted load balancing
- ✅ Service has been stable for weeks/months

### Use Proxmox Plugin Labels When:
- ✅ Quick testing of new services
- ✅ Development containers that change frequently
- ✅ Temporary services (demos, experiments)
- ✅ Simple routing rules (just a hostname)
- ✅ Want automatic cleanup when container is deleted
- ✅ Prototyping before creating static config

---

## 🔄 Migration Path

**From Plugin → Static (When service becomes production):**

1. Test service works with plugin labels
2. Create static YAML config based on working labels
3. Commit YAML to Git
4. Remove plugin labels from container
5. Restart Traefik to load static config

**From Static → Plugin (For dev/testing):**

1. Copy routing rules from YAML
2. Convert to label format
3. Add to container description
4. Wait for plugin discovery (~30s)
5. Optionally remove static YAML

---

## 📝 Current Configuration Summary

**Proxmox Plugin Status:**
- ✅ Installed and working
- ✅ Polling interval: 30 seconds
- ✅ Connected to: proxmox.internal.lakehouse.wtf
- ✅ Discovering all LXC containers across cluster
- ⚠️ Currently all containers show `traefik.enable=false`

**Static Routes (Production):**
- 21 services configured via static YAML files
- All routes use TLS with Cloudflare certificates
- Custom middlewares for security and headers
- Health checks enabled on most services

**Recommendation:**
Keep static YAML for all existing production services. Use plugin labels only for:
- New containers you're testing
- Temporary dev environments
- Services you want to quickly prototype

---

## 🆘 Troubleshooting

### Plugin Not Discovering Container

1. Check container has `traefik.enable=true` in description:
   ```bash
   pct config <VMID> | grep -A 10 description
   ```

2. Check Traefik logs for errors:
   ```bash
   tail -f /var/log/traefik/traefik.log | grep -i "vmid <VMID>"
   ```

3. Verify plugin is running:
   ```bash
   tail -f /var/log/traefik/traefik.log | grep proxmox-provider
   ```

### Route Works But Returns 503

- ✅ Route is configured correctly
- ❌ Backend service is not responding
- Check if service is running inside container
- Verify the port number is correct
- Check container firewall rules

### Route Not Working via HTTPS

1. Check DNS resolution:
   ```bash
   nslookup myservice.internal.lakehouse.wtf
   ```

2. Test with Host header:
   ```bash
   curl -k -H "Host: myservice.internal.lakehouse.wtf" https://192.168.1.110
   ```

3. Check route is loaded:
   ```bash
   curl -k https://traefik.internal.lakehouse.wtf/api/http/routers | jq
   ```

---

## 🎯 Next Steps

1. **Test your new routes:**
   - https://grafana.internal.lakehouse.wtf
   - https://hoarder.internal.lakehouse.wtf
   - https://memos.internal.lakehouse.wtf
   - https://gitops.internal.lakehouse.wtf

2. **Try creating a dev container with plugin labels**
   - Use the example above
   - Experiment with different services
   - See automatic discovery in action

3. **Decide on your workflow:**
   - Production: Static YAML (what you have now)
   - Development: Plugin labels for quick testing
   - Document your patterns for team consistency

