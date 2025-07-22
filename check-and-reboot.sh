#!/bin/bash

# Final reboot check script - triggered by PAM session end
# Waits a grace period then reboots if no sessions remain

GRACE_PERIOD=30  # 30 second grace period
LOG_FILE="/var/log/pam-session-end.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REBOOT-CHECK] $1" >> "$LOG_FILE"
}

count_sessions() {
    local session_count=$(loginctl list-sessions --no-legend 2>/dev/null | wc -l)
    local who_count=$(who | wc -l)
    
    if [[ $who_count -gt $session_count ]]; then
        session_count=$who_count
    fi
    
    echo $session_count
}

log_message "Starting reboot check with ${GRACE_PERIOD}s grace period"

# Wait grace period
sleep $GRACE_PERIOD

# Final check
final_sessions=$(count_sessions)
if [[ $final_sessions -eq 0 ]]; then
    log_message "No sessions after grace period, initiating reboot"
    
    # Log system state
    log_message "System uptime: $(uptime)"
    log_message "Memory usage: $(free -h | grep Mem)"
    
    # Broadcast warning
    wall "System rebooting in 10 seconds - no active user sessions" 2>/dev/null
    sleep 10
    
    # Final final check
    if [[ $(count_sessions) -eq 0 ]]; then
        log_message "Executing reboot now"
        sync
        /sbin/reboot
    else
        log_message "Last-second session detected, canceling reboot"
    fi
else
    log_message "Sessions detected during grace period ($final_sessions), canceling reboot"
fi