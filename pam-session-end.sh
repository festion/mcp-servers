#!/bin/bash

# PAM session end hook for auto-reboot
# This script is triggered when a user session ends

LOG_FILE="/var/log/pam-session-end.log"
REBOOT_SCRIPT="/home/dev/workspace/check-and-reboot.sh"

# Log the session end event
echo "$(date '+%Y-%m-%d %H:%M:%S') [PAM-SESSION-END] User: $PAM_USER, Session ended from: ${PAM_RHOST:-local}" >> "$LOG_FILE"

# Count remaining active sessions
session_count=$(loginctl list-sessions --no-legend 2>/dev/null | wc -l)
who_count=$(who | wc -l)

# Use higher count to be safe
if [[ $who_count -gt $session_count ]]; then
    session_count=$who_count
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [PAM-SESSION-END] Remaining sessions: $session_count" >> "$LOG_FILE"

# If no sessions remain, trigger reboot check
if [[ $session_count -eq 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PAM-SESSION-END] No active sessions, triggering reboot check" >> "$LOG_FILE"
    
    # Run reboot check in background to avoid blocking PAM
    nohup "$REBOOT_SCRIPT" >> "$LOG_FILE" 2>&1 &
fi