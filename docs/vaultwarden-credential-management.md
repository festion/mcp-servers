# Vaultwarden Homelab Credential Management

## Overview

All homelab container and Proxmox host root passwords have been rotated to unique, strong passwords and stored in Vaultwarden. SSH key authentication has been deployed as the primary access method.

## Quick Access

### Vaultwarden Web UI
- **URL**: https://vault.internal.lakehouse.wtf
- **External**: https://vault.jasonbrunelle.com (if configured)

### Browser Extension Setup
1. Install Bitwarden browser extension
2. Settings → Self-hosted → Server URL: `https://vault.internal.lakehouse.wtf`
3. Login with your account credentials

## Access Methods

### 1. SSH Key Authentication (Recommended)

An ed25519 SSH key pair has been deployed to all containers and Proxmox hosts:

| Property | Value |
|----------|-------|
| Key Name | Homelab Admin SSH Key |
| Vault Location | Homelab/SSH Keys |
| Key Type | ed25519 |
| Comment | claude-homelab-admin@lakehouse.wtf |

**Usage:**
```bash
# Extract private key from Vaultwarden and save locally
bw get notes "Homelab Admin SSH Key" | grep -A100 "Private Key:" | tail -n +2 > ~/.ssh/homelab_admin
chmod 600 ~/.ssh/homelab_admin

# Connect to any system
ssh -i ~/.ssh/homelab_admin root@<IP_ADDRESS>
```

### 2. Password Authentication

Each container/host has a unique 24-character password stored in Vaultwarden.

**CLI Usage:**
```bash
# Login to Vaultwarden CLI
export BW_SESSION=$(bw login your-email@example.com --raw)

# Or unlock if already logged in
export BW_SESSION=$(bw unlock --raw)

# Get a specific password
bw get password "grafana Root"
bw get password "proxmox Root"
bw get password "traefik Root"
```

## Vault Folder Structure

```
Homelab/
├── Infrastructure/
│   ├── Proxmox/
│   │   ├── proxmox Root (192.168.1.137)
│   │   ├── proxmox2 Root (192.168.1.125)
│   │   └── proxmox3 Root (192.168.1.126)
│   ├── Containers/
│   │   └── [41 container credentials]
│   └── Network/
├── Databases/
├── Monitoring/
├── Applications/
├── SSH Keys/
│   └── Homelab Admin SSH Key
└── API Keys/
```

## Container Inventory

### Proxmox Host: proxmox (192.168.1.137)

| VMID | Container Name | IP Address | Vault Entry |
|------|----------------|------------|-------------|
| 101 | grafana | 192.168.1.151 | grafana Root |
| 102 | cloudflared | 192.168.1.100 | cloudflared Root |
| 106 | pairdrop | 192.168.1.97 | pairdrop Root |
| 107 | infisical | 192.168.1.29 | infisical Root |
| 110 | traefik | 192.168.1.101 | traefik Root |
| 117 | hoarder | 192.168.1.102 | hoarder Root |
| 118 | adguard-sync | 192.168.1.225 | adguard-sync Root |
| 119 | pulse | 192.168.1.122 | pulse Root |
| 120 | proxmox-backup-server | 192.168.1.31 | proxmox-backup-server Root |
| 124 | mqtt | 192.168.1.85 | mqtt Root |
| 132 | uptime-kuma | 192.168.1.132 | uptime-kuma Root |
| 134 | kea-dhcp-2 | 192.168.1.134 | kea-dhcp-2 Root |
| 135 | stork-server | 192.168.1.234 | stork-server Root |
| 150 | homepage | 192.168.1.45 | homepage Root |
| 152 | proxmox-agent | 192.168.1.20 | proxmox-agent Root |
| 1400 | netbox-agent | 192.168.1.157 | netbox-agent Root |

### Proxmox Host: proxmox2 (192.168.1.125)

| VMID | Container Name | IP Address | Vault Entry |
|------|----------------|------------|-------------|
| 100 | influxdb | 192.168.1.74 | influxdb Root |
| 103 | watchyourlan | 192.168.1.195 | watchyourlan Root |
| 104 | myspeed | 192.168.1.152 | myspeed Root |
| 108 | tandoor | 192.168.1.108 | tandoor Root |
| 113 | postgresql | 192.168.1.123 | postgresql Root |
| 115 | memos | 192.168.1.144 | memos Root |
| 116 | adguard-2 | 192.168.1.224 | adguard-2 Root |
| 121 | traefik-2 | 192.168.1.103 | traefik-2 Root |
| 123 | gitopsdashboard | 192.168.1.136 | gitopsdashboard Root |
| 125 | zwave-js-ui | 192.168.1.141 | zwave-js-ui Root |
| 128 | developmentenvironment | 192.168.1.239 | developmentenvironment Root |
| 131 | netbox | 192.168.1.138 | netbox Root |
| 140 | vaultwarden | 192.168.1.140 | vaultwarden Root |
| 1260 | vikunja | 192.168.1.143 | vikunja Root |

### Proxmox Host: proxmox3 (192.168.1.126)

| VMID | Container Name | IP Address | Vault Entry |
|------|----------------|------------|-------------|
| 109 | esphome | 192.168.1.169 | esphome Root |
| 111 | OmadaController | 192.168.1.47 | OmadaController Root |
| 112 | wikijs | 192.168.1.135 | wikijs Root |
| 122 | zigbee2mqtt | 192.168.1.228 | zigbee2mqtt Root |
| 127 | proxmox-datacenter-manager | 192.168.1.41 | proxmox-datacenter-manager Root |
| 130 | mqtt-prod | 192.168.1.148 | mqtt-prod Root |
| 133 | kea-dhcp-1 | 192.168.1.133 | kea-dhcp-1 Root |
| 141 | vaultwarden-standby | 192.168.1.141 | vaultwarden-standby Root |
| 1250 | adguard | 192.168.1.253 | adguard Root |
| 1300 | wikijs-integration | 192.168.1.154 | wikijs-integration Root |
| 2000 | github-runner | 192.168.1.182 | github-runner Root |

## Password Rotation Procedure

### Rotate a Single Container Password

```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)

# 2. Change password via Proxmox host
ssh -i ~/.ssh/homelab_admin root@<PROXMOX_HOST_IP> \
    "pct exec <VMID> -- bash -c 'echo \"root:$NEW_PASS\" | chpasswd'"

# 3. Update in Vaultwarden
ITEM_ID=$(bw list items --search "<container> Root" | jq -r '.[0].id')
bw get item $ITEM_ID | jq ".login.password = \"$NEW_PASS\"" | bw encode | bw edit item $ITEM_ID

# 4. Sync
bw sync
```

### Rotate All Container Passwords (Batch)

```bash
#!/bin/bash
# rotate-all-passwords.sh

CONTAINERS=(
    "192.168.1.137:101:grafana"
    "192.168.1.137:102:cloudflared"
    # ... add all containers
)

for entry in "${CONTAINERS[@]}"; do
    HOST_IP="${entry%%:*}"
    REST="${entry#*:}"
    VMID="${REST%%:*}"
    NAME="${REST#*:}"
    
    NEW_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    
    ssh -i ~/.ssh/homelab_admin root@$HOST_IP \
        "pct exec $VMID -- bash -c 'echo \"root:$NEW_PASS\" | chpasswd'"
    
    # Update Vaultwarden...
done
```

## High Availability

### Vaultwarden HA Setup

| Role | Container | IP | Host |
|------|-----------|-----|------|
| Primary | vaultwarden | 192.168.1.140 | proxmox2 |
| Standby | vaultwarden-standby | 192.168.1.141 | proxmox3 |

### Backup Recommendations

1. **Vaultwarden Data**: Regularly backup `/opt/vaultwarden/data/`
2. **SSH Keys**: Store backup copy in secure offline location
3. **Export Vault**: Periodically export encrypted backup from web UI

## Security Best Practices

1. **Use SSH keys** over passwords when possible
2. **Rotate passwords** quarterly or after any security incident
3. **Enable 2FA** on Vaultwarden account
4. **Limit access** - only share credentials as needed
5. **Audit access** - review who has access periodically

## Service Account (Claude Automation)

| Property | Value |
|----------|-------|
| Email | claude-service@lakehouse.wtf |
| Purpose | Automated credential management |
| Server | https://vault.internal.lakehouse.wtf |

---

*Last Updated: December 2025*
*Total Credentials: 45 (41 containers + 3 Proxmox hosts + 1 SSH key)*
