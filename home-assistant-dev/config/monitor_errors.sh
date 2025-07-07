#\!/bin/bash
# Home Assistant Error Monitoring Script
# Usage: ./monitor_errors.sh [hours_back]

HOURS_BACK=${1:-24}
LOG_FILE='/config/home-assistant.log'

echo "=== Home Assistant Error Monitor ==="
echo "Monitoring errors from last $HOURS_BACK hours"
echo "Generated: $(date)"
echo

# Template errors (should be zero after fix)
echo "1. Template DateTime Errors:"
grep -c "can't subtract offset-naive and offset-aware" $LOG_FILE || echo "0 errors found"
echo

# Tuya device errors
echo "2. Tuya Device Connection Errors:"
grep "Failed to fetch device status" $LOG_FILE  < /dev/null |  tail -5
echo

# Tuya API authentication errors
echo "3. Tuya API Authentication Errors:"
grep -c "sign invalid" $LOG_FILE || echo "0 errors found"
echo

# Chromecast connection errors
echo "4. Chromecast Connection Errors:"
grep "Failed to connect to service.*googlecast" $LOG_FILE | tail -3
echo

# Overall error count
echo "5. Total Error Summary:"
echo "ERROR entries: $(grep -c 'ERROR' $LOG_FILE)"
echo "CRITICAL entries: $(grep -c 'CRITICAL' $LOG_FILE)"
echo "Exception entries: $(grep -c 'Exception' $LOG_FILE)"
echo "Failed entries: $(grep -c 'Failed' $LOG_FILE)"

