#!/bin/bash
# Entity Registry Fix Script for Home Assistant
# This script will fix entity registry conflicts by:
# 1. Backing up the current entity registry
# 2. Stopping Home Assistant
# 3. Updating the entity registry to remove duplicate entities
# 4. Starting Home Assistant

echo "Creating backup of entity registry..."
cp /config/.storage/core.entity_registry /config/.storage/core.entity_registry.backup.$(date +%Y%m%d%H%M%S)

echo "Finding Home Assistant service name..."
if [ -f "/etc/systemd/system/homeassistant.service" ]; then
  SERVICE_NAME="homeassistant"
elif [ -f "/etc/systemd/system/home-assistant.service" ]; then
  SERVICE_NAME="home-assistant"
elif [ -f "/etc/systemd/system/home-assistant@homeassistant.service" ]; then
  SERVICE_NAME="home-assistant@homeassistant"
else
  echo "Home Assistant service not found. Please restart manually after running this script."
  SERVICE_NAME=""
fi

# Stop Home Assistant if service was found
if [ ! -z "$SERVICE_NAME" ]; then
  echo "Stopping Home Assistant..."
  systemctl stop $SERVICE_NAME
fi

# Fix entity registry
echo "Fixing entity registry conflicts..."

# Use jq to remove the duplicated entries if jq is installed
if command -v jq >/dev/null 2>&1; then
  # Create a temporary file
  jq '(.entities[] | select(.entity_id == "input_boolean.curatron_drying_active" or .entity_id == "input_number.curatron_drying_threshold" or .entity_id == "input_datetime.last_fertigation_time")) as $items | (.deleted_entities += [$items]) | (.entities -= [$items])' /config/.storage/core.entity_registry > /config/.storage/core.entity_registry.new
  
  # Check if jq command was successful
  if [ $? -eq 0 ]; then
    mv /config/.storage/core.entity_registry.new /config/.storage/core.entity_registry
    echo "Entity registry successfully updated with jq."
  else
    echo "Error using jq to update entity registry."
  fi
else
  echo "jq not found. Please install jq or manually edit the entity registry."
  echo "You need to move these entities to the deleted_entities section:"
  echo "- input_boolean.curatron_drying_active"
  echo "- input_number.curatron_drying_threshold"
  echo "- input_datetime.last_fertigation_time"
fi

# Start Home Assistant if service was found
if [ ! -z "$SERVICE_NAME" ]; then
  echo "Starting Home Assistant..."
  systemctl start $SERVICE_NAME
else
  echo "Please restart Home Assistant manually to apply the changes."
fi

echo "Done. Check Home Assistant logs for any errors after restart."