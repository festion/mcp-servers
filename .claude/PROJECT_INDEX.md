# Workspace Integration Index

Generated: 2026-02-03

## Purpose

This is the monorepo workspace containing all homelab infrastructure, automation, and tooling repositories. This index focuses on **integrations between repos**, shared resources, and data flow.

## Repository Map

| Repository | Purpose | Key Integration |
|------------|---------|-----------------|
| **homelab-gitops** | Infrastructure orchestration | Central hub for configs, MCP servers, monitoring |
| **home-assistant-config** | Home automation | Prometheus metrics → Grafana |
| **operations** | Runbooks/procedures | WikiJS sync |
| **proxmox-agent** | VM/container management | Cluster API, remediation webhooks |
| **netbox-agent** | DCIM/IPAM population | Pulls from HA, Proxmox, TrueNAS |
| **dotfiles** | Claude Code configuration | Global hooks, scripts |
| **birdnet-gone** | Bird sound detection | MQTT → Home Assistant |
| **model-catalog** | 3D model management | Standalone service |

## Integration Architecture

```
                         homelab-gitops
                    (Infrastructure Hub)
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
  Home Assistant      Proxmox Cluster         NetBox
        │                    │                    │
        └────────────────────┴────────────────────┘
                             │
                             ▼
                    Prometheus/Grafana
                     (Monitoring)
                             │
                             ▼
                       operations
                    (Documentation)
```

## Shared Resources

### MCP Server Configuration
**Location:** `/home/dev/workspace/.mcp.json`

| Server | Purpose |
|--------|---------|
| filesystem | Workspace file access |
| home-assistant | IoT device control |
| github | Repository management |
| proxmox-mcp | VM/container management |
| truenas | Storage management |

**Token Storage:** `/home/dev/.mcp_tokens/` (not in Git)

### Infrastructure Configs (in homelab-gitops)
```
infrastructure/
├── grafana/        # Dashboards, alerts
├── kea/            # DHCP reservations
├── node-red/       # Automation flows
├── traefik/        # Reverse proxy routes
└── promtail/       # Log shipping
```

## Data Flow

### Home Assistant → Monitoring
```yaml
# HA exposes metrics via prometheus integration
prometheus:
  namespace: homeassistant
  include:
    domains: [sensor, binary_sensor, switch, climate, light]
```
Grafana dashboards in `homelab-gitops/infrastructure/grafana/`

### NetBox Agent Data Sources
```
netbox-agent pulls from:
  ├── home-assistant  (IoT devices)
  ├── proxmox         (VMs, containers)
  ├── truenas         (storage)
  └── network-scanner (discovery)
```

### Operations → WikiJS
Runbooks and docs sync to `wiki.internal.lakehouse.wtf/operations`

## Cross-Repo Decision Matrix

| Task | Repository |
|------|------------|
| Add Grafana alert | homelab-gitops |
| Add Traefik route | homelab-gitops |
| Add DHCP reservation | homelab-gitops |
| Deploy MCP server | homelab-gitops |
| Write documentation | operations |
| Create runbook | operations |
| HA automation | home-assistant-config |
| Cluster monitoring | proxmox-agent |
| Infrastructure inventory | netbox-agent |
| Claude Code config | dotfiles |

## Key Patterns

1. **GitOps**: All infra changes through Git → CI/CD deployment
2. **MCP Protocol**: Standardized AI assistant ↔ service interface
3. **Centralized Monitoring**: Prometheus/Grafana in homelab-gitops
4. **Token Management**: Credentials in `~/.mcp_tokens/`, not in repos

## Entry Points

- **Start new service**: homelab-gitops (Traefik route, monitoring)
- **Debug infrastructure**: operations runbooks, Grafana dashboards
- **Add automation**: home-assistant-config packages
- **Update inventory**: netbox-agent data sources
- **Claude Code setup**: dotfiles setup.sh

## Common Cross-Repo Tasks

### Add a new service
1. Create container/VM (proxmox-agent or manual)
2. Add DHCP reservation (`homelab-gitops/infrastructure/kea/`)
3. Add Traefik route (`homelab-gitops/infrastructure/traefik/`)
4. Add monitoring (`homelab-gitops/infrastructure/grafana/`)
5. Document in `operations/docs/`
6. Update NetBox via netbox-agent

### Debug an issue
1. Check Grafana dashboards (homelab-gitops)
2. Find runbook (operations)
3. Check service logs (promtail → Loki)
4. Use MCP tools for live inspection
