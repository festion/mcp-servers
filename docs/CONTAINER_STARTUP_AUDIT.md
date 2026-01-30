# Container Startup Configuration Audit
## Date: 2025-11-23

### Issues Found

#### 1. Containers Missing OnBoot=1 (Won't Auto-Start on Node Reboot)

| VMID | Name | Node | Current OnBoot | Should Be | Reason |
|------|------|------|----------------|-----------|--------|
| 108 | tandoor | proxmox2 | 0 | 1 | Recipe manager - should be available |
| 118 | adguard-sync | proxmox | not set | 1 | DNS sync utility - critical |
| 129 | gitops-qa | proxmox | not set | 0 | QA environment - manual start OK |
| 131 | netbox | proxmox2 | 0 (HA disabled) | 1 | Network documentation - should be available |
| 150 | homepage | proxmox | not set | 1 | Dashboard - should be available |
| 1160 | debian | proxmox2 | 0 | 0 | Template/test - manual start OK |
| 1260 | vikunja | proxmox2 | 0 | 1 | Task manager - should be available |
| 1300 | wikijs-integration | proxmox3 | not set | 1 | Integration service - should run |
| 1400 | netbox-agent | proxmox | not set | 1 | Automation agent - should run |

#### 2. Containers Missing Startup Order (No Dependencies)

| VMID | Name | Startup | Issue |
|------|------|---------|-------|
| 107 | infisical | none | Should start after 116/1250 (DNS) |
| 118 | adguard-sync | none | Should start AFTER 116 & 1250 |
| 120 | proxmox-backup-server | none | Should start early (order=1) |
| 127 | proxmox-datacenter-manager | none | Should start after 116/1250 (DNS) |
| 129 | gitops-qa | none | Manual start OK |
| 132 | uptime-kuma | none | Should start after 110/121 (Traefik) |
| 133 | kea-dhcp-1 | none | CRITICAL - should be order=1 |
| 134 | kea-dhcp-2 | none | CRITICAL - should be order=1 |
| 135 | stork-server | none | Should start after 133/134 (DHCP) |
| 150 | homepage | none | Should start after 110/121 (Traefik) |
| 152 | proxmox-agent | none | Should start early (order=2) |
| 1300 | wikijs-integration | none | Should start after 112 (WikiJS) |
| 1400 | netbox-agent | none | Should start after 131 (NetBox) |

### Optimal Startup Order Design

#### Priority Levels

**Level 1 - Infrastructure (order=1-2)**: Must start first
- DNS (AdGuard)
- DHCP (Kea)
- Backup Server

**Level 2 - Core Services (order=3-5)**: Core infrastructure
- Reverse Proxy (Traefik)
- Network Management (Omada)
- Databases

**Level 3 - Applications (order=10-30)**: Regular services
- Monitoring, dashboards, etc.

**Level 4 - Integration/Agents (order=40-60)**: Dependent services
- Agents, sync utilities

### Recommended Startup Order

```
Order 1: Critical Infrastructure
- 113: PostgreSQL (database)
- 133: Kea DHCP Primary
- 134: Kea DHCP Secondary
- 120: Proxmox Backup Server

Order 2: DNS & Core Network
- 1250: AdGuard Primary DNS
- 116: AdGuard Secondary DNS
- 152: Proxmox Agent

Order 3: Reverse Proxy & Core Services
- 110: Traefik Primary
- 121: Traefik Secondary
- 130: MQTT Production
- 106: Pairdrop
- 117: Hoarder
- 2000: GitHub Runner

Order 4: Databases & Storage
- 100: InfluxDB

Order 5: Network Management
- 111: Omada Controller
- 101: Grafana
- 102: Cloudflared

Order 7: Monitoring & Tools
- 103: WatchYourLAN
- 107: Infisical

Order 8: Applications
- 104: MySpeed

Order 10: DHCP Monitoring
- 135: Stork Server

Order 12: Recipe Manager
- 108: Tandoor

Order 15: Documentation
- 112: WikiJS
- 131: NetBox

Order 17: Task Management
- 115: Memos
- 1260: Vikunja

Order 20: Smart Home
- 122: Zigbee2MQTT
- 124: MQTT (backup)
- 125: Z-Wave JS UI

Order 25: DNS Sync (AFTER DNS is stable)
- 118: AdGuard Sync

Order 30: Integration Services
- 127: Proxmox Datacenter Manager
- 1300: WikiJS Integration

Order 35: Home Automation
- 109: ESPHome

Order 40: Dashboards
- 123: GitOps Dashboard
- 132: Uptime Kuma
- 150: Homepage

Order 50: Automation Agents
- 1400: NetBox Agent

Order 60: Development
- 128: Development Environment

Order 99: Optional Services
- 119: Pulse
- 129: GitOps QA
```

### HA Resource Conflicts

Some containers are HA-managed but also have onboot=1. HA should handle startup, not onboot:

| VMID | Name | HA | OnBoot | Issue |
|------|------|-------|--------|-------|
| 100 | influxdb | YES | 1 | HA controls startup |
| 110 | traefik | YES | 1 | HA controls startup |
| 113 | postgresql | YES (disabled) | 1 | OK - manually controlled |
| 116 | adguard-2 | YES | 1 | HA controls startup |
| 121 | traefik-2 | YES | 1 | HA controls startup |
| 122 | zigbee2mqtt | YES | 1 | HA controls startup |
| 130 | mqtt-prod | YES | 1 | HA controls startup |
| 131 | netbox | YES (disabled) | 0 | Should be 1 when not HA |
| 133 | kea-dhcp-1 | YES | 1 | HA controls startup |
| 134 | kea-dhcp-2 | YES | 1 | HA controls startup |
| 1250 | adguard | YES | 1 | HA controls startup |

**Note**: For HA resources, onboot=1 is actually fine as a fallback, but startup order is ignored by HA.

### Critical Services Without Proper Startup

**CRITICAL - Missing startup order**:
- 133 (Kea DHCP Primary) - NO startup order but HA-managed
- 134 (Kea DHCP Secondary) - NO startup order but HA-managed
- 120 (Proxmox Backup Server) - NO startup order

**Important - Should auto-start**:
- 118 (adguard-sync) - Not set to onboot
- 131 (netbox) - Set to onboot=0 (disabled HA)
- 132 (uptime-kuma) - Has onboot but no startup order
- 150 (homepage) - Not set to onboot

### Delay Settings Review

Most containers use 20-30 second delays which is reasonable. Notable:
- 113 (PostgreSQL): 60s delay - Good for database
- 111 (Omada): 45s delay - Good for network controller
- 109 (ESPHome): 30s delay - Good for IoT
- 130 (MQTT): No delay specified - Should add 20s

### Next Steps

1. Fix missing onboot settings (9 containers)
2. Add startup orders to all containers (14 missing)
3. Optimize existing startup orders for dependencies
4. Test startup sequence
5. Document final configuration
