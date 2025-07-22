#!/bin/bash
# Hydroponics Diagnostic Script
# Run this to check hydroponics sensors and system status

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOGFILE="/config/logs/hydroponics_diagnostic_$(date +"%Y%m%d_%H%M%S").log"

# Create log directory if it doesn't exist
mkdir -p /config/logs

# Start log file
echo "HYDROPONICS DIAGNOSTIC REPORT" > $LOGFILE
echo "============================" >> $LOGFILE
echo "Generated: $TIMESTAMP" >> $LOGFILE
echo "" >> $LOGFILE

# Check feed pump status
echo "FEED PUMP STATUS:" >> $LOGFILE
grep -i "tp_link_smart_plug_c82e_feed_pump" /config/home-assistant.log | tail -10 >> $LOGFILE
echo "" >> $LOGFILE

# Check water level sensor
echo "WATER LEVEL SENSOR STATUS:" >> $LOGFILE
grep -i "wroommicrousb_reservoir_current_volume" /config/home-assistant.log | tail -10 >> $LOGFILE
echo "" >> $LOGFILE

# Check temperature sensor
echo "TEMPERATURE SENSOR STATUS:" >> $LOGFILE
grep -i "wroommicrousb_reservoir_water_temp" /config/home-assistant.log | tail -10 >> $LOGFILE
echo "" >> $LOGFILE

# Check fertigation logs
echo "RECENT FERTIGATION EVENTS:" >> $LOGFILE
grep -i "fertigation" /config/home-assistant.log | tail -20 >> $LOGFILE
echo "" >> $LOGFILE

# Check for errors
echo "HYDROPONICS-RELATED ERRORS:" >> $LOGFILE
grep -i -E "(error|warning|failed|unavailable)" /config/home-assistant.log | grep -i -E "(hydroponics|fertigation|reservoir|pump)" | tail -20 >> $LOGFILE
echo "" >> $LOGFILE

# Check automations
echo "HYDROPONICS AUTOMATION STATUS:" >> $LOGFILE
grep -i "hydroponics_management_system" /config/home-assistant.log | tail -20 >> $LOGFILE
echo "" >> $LOGFILE

# Create a diagnostic notification in Home Assistant
curl -X POST \
  -H "Authorization: Bearer $(cat /config/secrets.yaml | grep http_token | cut -d':' -f2 | tr -d ' ')" \
  -H "Content-Type: application/json" \
  -d '{"title":"Hydroponics Diagnostic Complete","message":"Diagnostic log created at '"$LOGFILE"'","notification_id":"hydro_diagnostic"}' \
  http://supervisor/core/api/services/persistent_notification/create

echo "Diagnostic complete. Results saved to $LOGFILE"
chmod +x /config/hydroponics_diagnostic.sh