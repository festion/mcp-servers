# Vaultwarden Service Account - Complete Setup

## Service Account Credentials
- **Email**: `claude-service@lakehouse.wtf`
- **Password**: `VaultServiceAccount2025`
- **Server**: `https://vault.internal.lakehouse.wtf`

## Organization Access
- **Organization**: Homelab
- **Role**: Admin (full privileges)
- **Items accessible**: 36 vault items

## Bitwarden CLI Usage

### Login
```bash
export BW_SESSION=$(bw login claude-service@lakehouse.wtf VaultServiceAccount2025 --raw)
```

### Common Commands
```bash
# List all items
bw list items --session $BW_SESSION

# Get specific item by name
bw get item "Item Name" --session $BW_SESSION

# Create new login item
bw create item '{"type":1,"name":"Service Name","login":{"username":"user","password":"pass"}}' --session $BW_SESSION

# Sync vault
bw sync --session $BW_SESSION
```

## Infrastructure
- **Primary**: LXC 140 (192.168.1.140)
- **Standby**: LXC 141 (192.168.1.141)
- **Database**: PostgreSQL at 192.168.1.123
- **Traefik**: Configured on both 110 and 121

## Admin Panel
- URL: `https://vault.internal.lakehouse.wtf/admin`
- Token: `kbrDUhc23+3DOEFCc3Oy1bF0w1FqsFvBUEoM2ZLx1v5/sL1VsALIO4S8dcS9gCQj`

## SMTP Configuration
- Host: smtp.gmail.com:587 (STARTTLS)
- From: jeremy.ames@gmail.com
- Configured on both primary and standby

## Setup Date
December 2025
