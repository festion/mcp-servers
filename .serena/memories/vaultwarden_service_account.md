# Vaultwarden Service Account (Claude)

## Service Account Credentials

- **Email**: `claude-service@lakehouse.wtf`
- **Password**: `VaultServiceAccount2025`
- **Server**: `https://vault.internal.lakehouse.wtf`

## Bitwarden CLI Usage

```bash
# Login and get session
export BW_SESSION=$(bw login claude-service@lakehouse.wtf VaultServiceAccount2025 --raw)

# Or if already logged in, just unlock
export BW_SESSION=$(bw unlock VaultServiceAccount2025 --raw)

# Sync vault
bw sync

# List all items
bw list items

# Get specific item by name
bw get item "Item Name"

# Get password for an item
bw get password "Item Name"

# Create a login item
echo '{"type":1,"name":"Service Name","login":{"username":"user","password":"pass"}}' | bw encode | bw create item

# Create a secure note
echo '{"type":2,"name":"Note Name","secureNote":{"type":0},"notes":"content here"}' | bw encode | bw create item
```

## Quick Access Script

Save as `~/.local/bin/vw`:

```bash
#!/bin/bash
export BW_SESSION=$(bw unlock VaultServiceAccount2025 --raw 2>/dev/null || bw login claude-service@lakehouse.wtf VaultServiceAccount2025 --raw)

case "$1" in
  get) bw get password "$2" ;;
  list) bw list items --pretty ;;
  sync) bw sync ;;
  *) echo "Usage: vw {get|list|sync} [name]" ;;
esac
```

## Organization Access

To access the Homelab organization's shared items, the service account needs to be invited to the organization by jeremy.ames@outlook.com (the owner).

## Notes

- This account can store secrets that Claude needs across sessions
- Session tokens expire; use `bw unlock` to get a new session
