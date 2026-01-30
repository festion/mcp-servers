# Vaultwarden Management Credentials

## Admin Access

**Admin Panel URL**: https://vault.internal.lakehouse.wtf/admin

**Admin Token** (for API and panel login):
```
kbrDUhc23+3DOEFCc3Oy1bF0w1FqsFvBUEoM2ZLx1v5/sL1VsALIO4S8dcS9gCQj
```

## Organization

- **Organization**: Homelab
- **Owner**: jeremy.ames@outlook.com

## SMTP Credentials

- **Host**: smtp.gmail.com
- **Port**: 587
- **Username**: jeremy.ames@gmail.com
- **Password**: ekrklofkaqzqwvzb (Gmail App Password)

## Database

- **Type**: PostgreSQL
- **Host**: 192.168.1.123:5432
- **Database**: vaultwarden
- **Username**: vaultwarden
- **Password**: p7PEF7NgRj3VS3XkGCEeILzTkZzu7i63

## Infrastructure

| Role | LXC | Host | IP |
|------|-----|------|-----|
| Primary | 140 | proxmox2 | 192.168.1.140 |
| Standby | 141 | proxmox3 | 192.168.1.141 |
| Database | 113 | proxmox | 192.168.1.123 |

## Admin API Usage

The admin token can be used for API calls:

```bash
# Get server config
curl -H "Authorization: Bearer kbrDUhc23+3DOEFCc3Oy1bF0w1FqsFvBUEoM2ZLx1v5/sL1VsALIO4S8dcS9gCQj" \
  https://vault.internal.lakehouse.wtf/admin/config

# List users
curl -H "Authorization: Bearer kbrDUhc23+3DOEFCc3Oy1bF0w1FqsFvBUEoM2ZLx1v5/sL1VsALIO4S8dcS9gCQj" \
  https://vault.internal.lakehouse.wtf/admin/users

# Invite user
curl -X POST -H "Authorization: Bearer TOKEN" \
  -d "email=user@example.com" \
  https://vault.internal.lakehouse.wtf/admin/invite
```

## Service Management

```bash
# Restart primary
ssh root@192.168.1.125 "pct exec 140 -- systemctl restart vaultwarden"

# Restart standby  
ssh root@192.168.1.126 "pct exec 141 -- systemctl restart vaultwarden"

# View logs
ssh root@192.168.1.125 "pct exec 140 -- tail -50 /opt/vaultwarden/data/vaultwarden.log"

# Edit config
ssh root@192.168.1.125 "pct exec 140 -- nano /opt/vaultwarden/.env"
```
