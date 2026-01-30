# QUICK ACTION GUIDE - TOP PRIORITY FIXES

## 🔴 CRITICAL - DO THESE FIRST

### 1. Enable HA for Traefik (5 minutes)
```bash
ssh root@192.168.1.137
ha-manager add ct:110 --state started --max_relocate 2 --max_restart 3
ha-manager status | grep 110
```

### 2. Enable HA for Home Assistant (5 minutes)
```bash
ssh root@192.168.1.137
ha-manager add vm:114 --state started --max_relocate 2 --max_restart 3
ha-manager status | grep 114
```

### 3. Enable HA for DHCP Servers (5 minutes)
```bash
ssh root@192.168.1.137
ha-manager add ct:133 --state started --max_relocate 2 --max_restart 3
ha-manager add ct:134 --state started --max_relocate 2 --max_restart 3
```

---

## 🟡 HIGH PRIORITY - PLAN FOR THIS WEEK

### 4. Rebalance Containers from proxmox to proxmox2

**Candidates to migrate (non-critical, not HA):**
- cloudflared (102) - 0.5 GB
- pairdrop (106) - 0.5 GB
- grafana (101) - 0.5 GB
- mqtt (124) - 0.5 GB
- traefik-2 (121) - 2 GB
- uptime-kuma (132) - 2 GB

**Migration commands:**
```bash
# Example for cloudflared (102)
pct migrate 102 proxmox2 --online

# Repeat for each container
```

**Target state:**
- proxmox: 11 containers (down from 17)
- proxmox2: 15 containers (up from 10)
- proxmox3: 10 containers (unchanged)

---

## 📋 VALIDATION CHECKLIST

After enabling HA:
- [ ] Run `ha-manager status` - verify all services show "started"
- [ ] Test failover: `ha-manager migrate ct:110 proxmox2`
- [ ] Verify services still accessible via web
- [ ] Check logs: `journalctl -u pve-ha-lrm -f`

After rebalancing:
- [ ] Verify all migrated containers running
- [ ] Check resource usage on each node
- [ ] Test network connectivity from migrated containers
- [ ] Update documentation with new locations

---

## 📊 EXPECTED RESULTS

### Before:
- Traefik: SPOF, no HA
- Home Assistant: SPOF, no HA
- proxmox: 17 containers (overloaded)
- DHCP: No redundancy

### After:
- Traefik: HA enabled, auto-failover ✅
- Home Assistant: HA enabled, auto-failover ✅
- proxmox: 11 containers (balanced) ✅
- DHCP: HA enabled, redundant ✅

### Risk Reduction:
- Critical SPOFs: 4 → 1 (only TrueNAS remains)
- Node overload risk: HIGH → LOW
- Service availability: 95% → 99.9%

