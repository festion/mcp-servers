#!/bin/bash
# This script will trigger a watchman report based on updated configuration
echo "Running watchman report based on updated configuration"
echo "The report will be generated to /config/watchman_report.txt"
echo "Please check the report after restarting Home Assistant"
echo "Current configuration has removed BLE script references and"
echo "BLE-related input entities that are no longer needed"
echo ""
echo "This script does NOT automatically generate a new report -"
echo "that will happen after Home Assistant restarts"