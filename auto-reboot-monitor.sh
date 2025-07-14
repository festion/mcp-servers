#!/bin/bash

# Auto-reboot monitor script for development environment
# Reboots the system when the last user session logs out

SCRIPT_NAME="auto-reboot-monitor"
LOG_FILE="/var/log/auto-reboot-monitor.log"
LOCK_FILE="/var/run/auto-reboot-monitor.lock"
CHECK_INTERVAL=30  # Check every 30 seconds
GRACE_PERIOD=60    # Wait 60 seconds after last session ends before reboot

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$SCRIPT_NAME] $1" | tee -a "$LOG_FILE"
}

# Check if script is already running
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_message "ERROR: Another instance is already running (PID: $pid)"
            exit 1
        else
            log_message "WARN: Stale lock file found, removing"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Cleanup function
cleanup() {
    log_message "INFO: Cleaning up and exiting"
    rm -f "$LOCK_FILE"
    exit 0
}

# Count active user sessions
count_active_sessions() {
    # Count real user sessions (exclude system processes)
    local session_count=0
    
    # Method 1: Use loginctl to count active sessions
    session_count=$(loginctl list-sessions --no-legend 2>/dev/null | wc -l)
    
    # Method 2: Alternative using who command for verification
    local who_count=$(who | wc -l)
    
    # Method 3: Check for active SSH connections
    local ssh_count=$(ss -tn state established '( sport = :ssh or dport = :ssh )' 2>/dev/null | grep -v "State" | wc -l)
    
    log_message "DEBUG: Sessions - loginctl: $session_count, who: $who_count, ssh: $ssh_count"
    
    # Use the highest count to be safe
    if [[ $who_count -gt $session_count ]]; then
        session_count=$who_count
    fi
    
    echo $session_count
}

# Check if system should reboot
should_reboot() {
    local sessions=$(count_active_sessions)
    
    if [[ $sessions -eq 0 ]]; then
        log_message "INFO: No active sessions detected"
        return 0
    else
        log_message "INFO: $sessions active session(s) detected"
        return 1
    fi
}

# Perform reboot with logging
perform_reboot() {
    log_message "WARNING: Initiating system reboot - no active sessions for $GRACE_PERIOD seconds"
    
    # Final check before reboot
    local final_sessions=$(count_active_sessions)
    if [[ $final_sessions -gt 0 ]]; then
        log_message "INFO: Sessions detected during final check, canceling reboot"
        return 1
    fi
    
    # Log system state before reboot
    log_message "INFO: System state before reboot:"
    log_message "INFO: Uptime: $(uptime)"
    log_message "INFO: Load average: $(cat /proc/loadavg)"
    log_message "INFO: Memory usage: $(free -h | grep Mem)"
    
    # Broadcast warning to any remaining sessions
    wall "System will reboot in 10 seconds due to no active user sessions" 2>/dev/null
    sleep 10
    
    # Final final check
    final_sessions=$(count_active_sessions)
    if [[ $final_sessions -gt 0 ]]; then
        log_message "INFO: Last-second session detected, canceling reboot"
        return 1
    fi
    
    log_message "INFO: Executing reboot now"
    sync
    /sbin/reboot
}

# Main monitoring loop
main() {
    log_message "INFO: Starting auto-reboot monitor (PID: $$)"
    log_message "INFO: Check interval: ${CHECK_INTERVAL}s, Grace period: ${GRACE_PERIOD}s"
    
    local no_session_start=0
    local grace_period_active=false
    
    trap cleanup SIGTERM SIGINT
    
    while true; do
        if should_reboot; then
            if [[ $grace_period_active == false ]]; then
                log_message "INFO: Starting grace period - no sessions detected"
                no_session_start=$(date +%s)
                grace_period_active=true
            else
                local current_time=$(date +%s)
                local elapsed=$((current_time - no_session_start))
                
                if [[ $elapsed -ge $GRACE_PERIOD ]]; then
                    perform_reboot
                    # If reboot was canceled, reset grace period
                    grace_period_active=false
                else
                    log_message "INFO: Grace period active - ${elapsed}/${GRACE_PERIOD} seconds elapsed"
                fi
            fi
        else
            if [[ $grace_period_active == true ]]; then
                log_message "INFO: Sessions detected, canceling grace period"
                grace_period_active=false
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root" >&2
        exit 1
    fi
    
    # Handle command line arguments
    case "${1:-}" in
        "start")
            check_lock
            main
            ;;
        "stop")
            if [[ -f "$LOCK_FILE" ]]; then
                local pid=$(cat "$LOCK_FILE" 2>/dev/null)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    kill -TERM "$pid"
                    echo "Stopped auto-reboot monitor (PID: $pid)"
                else
                    echo "No running instance found"
                fi
            else
                echo "No lock file found"
            fi
            ;;
        "status")
            if [[ -f "$LOCK_FILE" ]]; then
                local pid=$(cat "$LOCK_FILE" 2>/dev/null)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    echo "Auto-reboot monitor is running (PID: $pid)"
                    echo "Active sessions: $(count_active_sessions)"
                else
                    echo "Auto-reboot monitor is not running (stale lock file)"
                fi
            else
                echo "Auto-reboot monitor is not running"
            fi
            ;;
        "test")
            echo "Testing session detection..."
            echo "Active sessions: $(count_active_sessions)"
            echo "Current users:"
            who
            echo "Loginctl sessions:"
            loginctl list-sessions
            ;;
        *)
            echo "Usage: $0 {start|stop|status|test}"
            echo "  start  - Start the auto-reboot monitor"
            echo "  stop   - Stop the auto-reboot monitor"
            echo "  status - Show monitor status"
            echo "  test   - Test session detection"
            exit 1
            ;;
    esac
fi