#!/bin/bash

# Temporary file for processing
TEMP_FILE="/config/cleanup_backup_20250521/temp_entity_registry"
BACKUP_FILE="/config/cleanup_backup_20250521/core.entity_registry.bak"
OUTPUT_FILE="/config/cleanup_backup_20250521/cleaned_entity_registry"
SOURCE_FILE="/config/.storage/core.entity_registry"

# Make backup
cp "$SOURCE_FILE" "$BACKUP_FILE"
echo "Created backup at: $BACKUP_FILE"

# Use grep to filter out unwanted entities
cat "$SOURCE_FILE" | grep -v "switch.ab_ble_gateway_pre_release" | \
                    grep -v "update.ab_ble_gateway_update" | \
                    grep -v "switch.april_brother_ab_ble_gateway_pre_release" | \
                    grep -v "update.april_brother_ab_ble_gateway_update" > "$TEMP_FILE"

# Ensure the JSON is still valid - this is a rough check by replacing any removed commas
sed -i 's/,\s*}/}/g' "$TEMP_FILE"
sed -i 's/,\s*]/]/g' "$TEMP_FILE"

# Move to final output
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Cleaned registry saved to: $OUTPUT_FILE"
echo
echo "To apply changes, run the following commands:"
echo "cp \"$OUTPUT_FILE\" \"$SOURCE_FILE\""
echo "Then restart Home Assistant using the UI or CLI"