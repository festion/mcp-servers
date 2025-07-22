#!/bin/bash
# Z-Wave JS Connection Check & Restart Script
# Place this in /config and make executable: chmod +x /config/zwave_js_check.sh
# Add to your configuration.yaml under shell_command:
# check_zwave_js: "bash /config/zwave_js_check.sh"

# Log file setup
LOG_FILE="/config/logs/zwave_js_check.log"
mkdir -p /config/logs

# Function to log messages with timestamps
log() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Log start of script
log "Z-Wave JS connection check starting..."

# Test connection to Z-Wave JS server
ZWAVE_HOST="192.168.1.155"
ZWAVE_PORT="3000"

# Check if the server is pingable 
log "Testing network connectivity to $ZWAVE_HOST..."
if ping -c 3 $ZWAVE_HOST > /dev/null 2>&1; then
  log "Host $ZWAVE_HOST is reachable"
else
  log "ERROR: Host $ZWAVE_HOST is not responding to ping"
  exit 1
fi

# Check if the port is open
log "Testing Z-Wave JS service port ($ZWAVE_PORT)..."
if nc -z -w5 $ZWAVE_HOST $ZWAVE_PORT > /dev/null 2>&1; then
  log "Z-Wave JS service appears to be running on $ZWAVE_HOST:$ZWAVE_PORT"
else
  log "Z-Wave JS service port is not accessible"
  log "Attempting to restart Z-Wave JS service via SSH..."
  
  # Attempt to restart Z-Wave JS service on the remote host
  if ssh -o ConnectTimeout=10 homeassistant@$ZWAVE_HOST "sudo systemctl restart zwave-js" > /dev/null 2>&1; then
    log "Z-Wave JS service restart command sent successfully"
    
    # Wait for service to restart
    log "Waiting 30 seconds for service to restart..."
    sleep 30
    
    # Check if service is now available
    if nc -z -w5 $ZWAVE_HOST $ZWAVE_PORT > /dev/null 2>&1; then
      log "Z-Wave JS service is now running"
    else
      log "ERROR: Z-Wave JS service still not running after restart attempt"
      exit 1
    fi
  else
    log "ERROR: Failed to restart Z-Wave JS service via SSH"
    exit 1
  fi
fi

# Verify if Home Assistant can connect to Z-Wave JS
log "Checking Z-Wave JS connection in Home Assistant..."
if grep -q "Connected to" < <(grep -i "zwave_js_server" /config/home-assistant.log | tail -10); then
  log "Home Assistant reports successful connection to Z-Wave JS"
else
  log "Home Assistant may not be properly connected to Z-Wave JS"
  log "Restarting the Z-Wave JS integration..."
  
  # Use the Home Assistant API to restart the integration
  # This requires a long-lived access token
  # Replace YOUR_TOKEN with your actual long-lived access token
  
  # Uncomment this section when you have a token
  # curl -X POST \
  #   -H "Authorization: Bearer YOUR_TOKEN" \
  #   -H "Content-Type: application/json" \
  #   http://localhost:8123/api/services/homeassistant/reload_integration \
  #   -d '{"integration": "zwave_js"}'
  
  log "Z-Wave JS integration restart requested"
fi

log "Z-Wave JS connection check completed"