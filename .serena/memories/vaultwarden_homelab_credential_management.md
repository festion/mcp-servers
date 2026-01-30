# Vaultwarden Homelab Credential Management

## Overview
All homelab container and Proxmox host root passwords have been rotated to unique, strong passwords and stored in Vaultwarden.

## Access Methods

### 1. SSH Key Authentication (Recommended)
An ed25519 SSH key pair has been deployed to all containers and Proxmox hosts:
- **Key name**: `Homelab Admin SSH Key`
- **Location in Vault**: `Homelab/SSH Keys`
- **Comment**: `claude-homelab-admin@lakehouse.wtf`

To use:
```bash
# Get the private key from Vaultwarden
bw get notes "Homelab Admin SSH Key" | grep -A100 "Private Key:" | tail -n +2 > ~/.ssh/homelab_admin
chmod 600 ~/.ssh/homelab_admin
ssh -i ~/.ssh/homelab_admin root@<IP>
```

### 2. Password Authentication
Each container/host has a unique 24-character password stored in Vaultwarden.

To retrieve a password:
```bash
# Login to Vaultwarden CLI
export BW_SESSION=$(bw login claude-service@lakehouse.wtf --raw)
# Or unlock if already logged in
export BW_SESSION=$(bw unlock --raw)

# Get a specific password
bw get password "grafana Root"
bw get password "proxmox Root"
```

## Vault Structure

```
Homelab/
├── Infrastructure/
│   ├── Proxmox/
│   │   ├── proxmox Root (192.168.1.137)
│   │   ├── proxmox2 Root (192.168.1.125)
│   │   └── proxmox3 Root (192.168.1.126)
│   ├── Containers/
│   │   ├── grafana Root (192.168.1.151)
│   │   ├── traefik Root (192.168.1.101)
│   │   ├── ... (all 41 containers)
│   │   └── developmentenvironment Root (192.168.1.239)
│   └── Network/
├── Databases/
├── Monitoring/
├── Applications/
├── SSH Keys/
│   └── Homelab Admin SSH Key
└── API Keys/
```

## Container Inventory

### proxmox (192.168.1.137)
| VMID | Name | IP |
|------|------|-----|
| 101 | grafana | 192.168.1.151 |
| 102 | cloudflared | 192.168.1.100 |
| 106 | pairdrop | 192.168.1.97 |
| 107 | infisical | 192.168.1.29 |
| 110 | traefik | 192.168.1.101 |
| 117 | hoarder | 192.168.1.102 |
| 118 | adguard-sync | 192.168.1.225 |
| 119 | pulse | 192.168.1.122 |
| 120 | proxmox-backup-server | 192.168.1.31 |
| 124 | mqtt | 192.168.1.85 |
| 132 | uptime-kuma | 192.168.1.132 |
| 134 | kea-dhcp-2 | 192.168.1.134 |
| 135 | stork-server | 192.168.1.234 |
| 150 | homepage | 192.168.1.45 |
| 152 | proxmox-agent | 192.168.1.20 |
| 1400 | netbox-agent | 192.168.1.157 |

### proxmox2 (192.168.1.125)
| VMID | Name | IP |
|------|------|-----|
| 100 | influxdb | 192.168.1.74 |
| 103 | watchyourlan | 192.168.1.195 |
| 104 | myspeed | 192.168.1.152 |
| 108 | tandoor | 192.168.1.108 |
| 113 | postgresql | 192.168.1.123 |
| 115 | memos | 192.168.1.144 |
| 116 | adguard-2 | 192.168.1.224 |
| 121 | traefik-2 | 192.168.1.103 |
| 123 | gitopsdashboard | 192.168.1.136 |
| 125 | zwave-js-ui | 192.168.1.141 |
| 128 | developmentenvironment | 192.168.1.239 |
| 131 | netbox | 192.168.1.138 |
| 140 | vaultwarden | 192.168.1.140 |
| 1260 | vikunja | 192.168.1.143 |

### proxmox3 (192.168.1.126)
| VMID | Name | IP |
|------|------|-----|
| 109 | esphome | 192.168.1.169 |
| 111 | OmadaController | 192.168.1.47 |
| 112 | wikijs | 192.168.1.135 |
| 122 | zigbee2mqtt | 192.168.1.228 |
| 127 | proxmox-datacenter-manager | 192.168.1.41 |
| 130 | mqtt-prod | 192.168.1.148 |
| 133 | kea-dhcp-1 | 192.168.1.133 |
| 141 | vaultwarden-standby | 192.168.1.141 |
| 1250 | adguard | 192.168.1.253 |
| 1300 | wikijs-integration | 192.168.1.154 |
| 2000 | github-runner | 192.168.1.182 |

## Password Rotation Procedure

To rotate all passwords again:

```bash
# 1. Login to Vaultwarden
export BW_SESSION=$(bw login claude-service@lakehouse.wtf --raw)

# 2. For each container, use pct exec to change password
NEW_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
ssh -i ~/.ssh/homelab_admin root@<PROXMOX_HOST> "pct exec <VMID> -- bash -c 'echo \"root:$NEW_PASS\" | chpasswd'"

# 3. Update the item in Vaultwarden
bw get item "<container> Root" | jq ".login.password = \"$NEW_PASS\"" | bw encode | bw edit item <ITEM_ID>
```

## Service Account
- **Email**: claude-service@lakehouse.wtf
- **Server**: https://vault.internal.lakehouse.wtf
- Credentials stored in memory: `vaultwarden_service_account`

## Security Notes
- All passwords are unique 24-character strings with letters and numbers
- SSH key authentication is preferred over password auth
- The old shared password `redflower805` is no longer valid on any system
- Vaultwarden HA: Primary on proxmox2 (192.168.1.140), Standby on proxmox3 (192.168.1.141)
