#!/usr/bin/env python3
import json
import sys

# Entities to remove
entities_to_remove = [
    "switch.ab_ble_gateway_pre_release",
    "update.ab_ble_gateway_update",
    "switch.april_brother_ab_ble_gateway_pre_release",
    "update.april_brother_ab_ble_gateway_update"
]

# Read the entity registry
with open('/config/.storage/core.entity_registry', 'r') as f:
    registry = json.load(f)

# Count entities before filtering
original_count = len(registry['data']['entities'])

# Filter out entities with the specified IDs
registry['data']['entities'] = [
    entity for entity in registry['data']['entities']
    if entity.get('entity_id') not in entities_to_remove
]

# Count entities after filtering
new_count = len(registry['data']['entities'])
removed = original_count - new_count

# Write the cleaned registry to a new file
with open('/config/cleanup_backup_20250521/cleaned_entity_registry.json', 'w') as f:
    json.dump(registry, f, indent=2)

print(f"Processed entity registry:")
print(f"Original entities: {original_count}")
print(f"Entities removed: {removed}")
print(f"Remaining entities: {new_count}")
print(f"Removed entity IDs: {', '.join(entities_to_remove)}")
print()
print("Cleaned registry saved to: /config/cleanup_backup_20250521/cleaned_entity_registry.json")
print("To apply changes, copy this file to /config/.storage/core.entity_registry")
print("IMPORTANT: Restart Home Assistant after applying these changes")