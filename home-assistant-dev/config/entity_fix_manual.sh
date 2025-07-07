#!/bin/bash
# Manual Entity Registry Fix Script for Home Assistant

echo "Creating backup of entity registry..."
cp /config/.storage/core.entity_registry /config/.storage/core.entity_registry.backup.$(date +%Y%m%d%H%M%S)

echo "Fixing entity registry conflicts..."
echo "Please manually edit your entity registry to remove these duplicates:"
echo "- input_boolean.curatron_drying_active (keep input_boolean.curatron_drying_active_mode)"
echo "- input_number.curatron_drying_threshold (keep input_number.curatron_drying_threshold_slider)"
echo "- input_datetime.last_fertigation_time (keep input_datetime.last_fertigation_timestamp)"
echo 
echo "To edit the entity registry manually:"
echo "1. Open Home Assistant"
echo "2. Go to Configuration > Entities"
echo "3. Search for each of the above entities"
echo "4. Click on the settings icon for each entity"
echo "5. Click the 'Delete' button at the bottom"
echo "6. Restart Home Assistant after deleting all duplicates"
echo
echo "For safety, a backup of your entity registry has been created at:"
echo "/config/.storage/core.entity_registry.backup.*"