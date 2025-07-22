#!/bin/bash
# Home Assistant Config Directory Cleanup Script
# This script helps clean up orphaned or unused files in your HA config directory
# Created by Claude on $(date +%Y-%m-%d)

# Set the backup directory where we'll move files instead of deleting them
BACKUP_DIR="/config/cleanup_backup_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "=== Home Assistant Configuration Cleanup ==="
echo "Backing up files to: $BACKUP_DIR"
echo

# Function to backup files instead of deleting them
backup_file() {
  local src="$1"
  local rel_path="${src#/config/}"
  local dest_dir="$BACKUP_DIR/$(dirname "$rel_path")"
  
  mkdir -p "$dest_dir"
  mv "$src" "$dest_dir/"
  echo "Moved: $src → $dest_dir/"
}

# 1. Corrupted Database Files
echo "=== Cleaning up corrupted database files ==="
for db_file in /config/backup_db/home-assistant_v2.db.corrupt.* /config/home-assistant_v2.db.corrupt.*; do
  if [ -f "$db_file" ]; then
    backup_file "$db_file"
  fi
done
echo

# 2. Old Zigbee2MQTT Logs
echo "=== Cleaning up old Zigbee2MQTT logs ==="
# Keep logs from the last 14 days, backup the rest
find /config/zigbee2mqtt/log -type d -name "2025-*" -mtime +14 | while read log_dir; do
  backup_file "$log_dir"
done
echo

# 3. Empty log files
echo "=== Removing empty log files ==="
find /config -name "*.log*" -size 0 | while read empty_log; do
  rm "$empty_log"
  echo "Removed empty log: $empty_log"
done
echo

# 4. ESPHome archive and backups
echo "=== Cleaning up ESPHome archive files ==="
if [ -d "/config/esphome/archive" ]; then
  backup_file "/config/esphome/archive"
fi

for esp_backup in /config/esphome/*.backup; do
  if [ -f "$esp_backup" ]; then
    backup_file "$esp_backup"
  fi
done
echo

# 5. Configuration backup cache
echo "=== Cleaning up configuration backups ==="
if [ -d "/config/backup_cache" ]; then
  backup_file "/config/backup_cache"
fi
echo

# 6. Potentially orphaned configuration files
echo "=== Checking for orphaned configuration files ==="
config_files=(
  "/config/govee_learning.yaml"
  "/config/dashboard_card.yaml" 
  "/config/scrape_configs.yaml"
)

for config_file in "${config_files[@]}"; do
  if [ -f "$config_file" ]; then
    echo "Potentially orphaned: $config_file"
    echo "Please verify these files are not needed before removal."
    # Uncomment the line below after verification
    # backup_file "$config_file"
  fi
done
echo

# 7. Clean up references to ab_ble_gateway integration
echo "=== Cleaning up references to ab_ble_gateway integration ==="
echo "Searching for references in YAML and JSON files..."
grep -r "ab_ble_gateway" /config --include="*.yaml" --include="*.json" 2>/dev/null | while read -r ref; do
  file=$(echo "$ref" | cut -d: -f1)
  echo "Found reference in: $file"
done

# 8. Check .storage directory for UI references
echo "Checking .storage directory for references..."
if [ -d "/config/.storage" ]; then
  for file in /config/.storage/lovelace* /config/.storage/frontend.user_interface_options /config/.storage/core.entity_registry; do
    if [ -f "$file" ] && grep -q "ab_ble_gateway" "$file"; then
      echo "Found reference in $file"
      # Make a backup
      cp "$file" "$BACKUP_DIR/$(basename "$file")"
      echo "Created backup at $BACKUP_DIR/$(basename "$file")"
      
      # For entity registry, we need to be careful
      if [[ "$file" == *"entity_registry"* ]]; then
        echo "Entity registry contains references to ab_ble_gateway"
        echo "Please restart Home Assistant after cleanup to rebuild the entity registry"
      fi
    fi
  done
else
  echo "No .storage directory found."
fi

# 9. Remove BLE device discovery temp files
if [ -f "/config/bluetooth_discoveries.json" ]; then
  echo "Found BLE discovery cache file. Creating backup and moving..."
  backup_file "/config/bluetooth_discoveries.json"
fi

echo "=== Cleanup Summary ==="
echo "All files have been backed up to: $BACKUP_DIR"
echo "Please verify the backed up files before permanently deleting them."
echo "After verification, you can remove the backup directory with:"
echo "rm -rf $BACKUP_DIR"
echo 
echo "IMPORTANT: After running this script, please:"
echo "1. Clear your browser cache for any device accessing Home Assistant"
echo "2. Restart Home Assistant"
echo "3. Check for any remaining references to 'ab_ble_gateway'"
echo
echo "Done!"