#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_LEVEL=${LOG_LEVEL:-INFO}
LOG_FILE=${LOG_FILE:-/var/log/github-runner/management.log}

log_level_priority() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        FATAL) echo 4 ;;
        *) echo 1 ;;
    esac
}

should_log() {
    local level="$1"
    local current_priority=$(log_level_priority "$LOG_LEVEL")
    local message_priority=$(log_level_priority "$level")
    
    [[ $message_priority -ge $current_priority ]]
}

log_message() {
    local level="$1"
    local message="$2"
    local color="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    if should_log "$level"; then
        if [[ -t 1 ]]; then
            echo -e "${color}[$timestamp] [$level] [$caller] $message${NC}" >&2
        else
            echo "[$timestamp] [$level] [$caller] $message" >&2
        fi
        
        if [[ -n "$LOG_FILE" ]] && [[ -w "$(dirname "$LOG_FILE")" ]]; then
            echo "[$timestamp] [$level] [$caller] $message" >> "$LOG_FILE"
        fi
    fi
}

log_debug() {
    log_message "DEBUG" "$1" "$CYAN"
}

log_info() {
    log_message "INFO" "$1" "$BLUE"
}

log_success() {
    log_message "INFO" "✓ $1" "$GREEN"
}

log_warn() {
    log_message "WARN" "⚠ $1" "$YELLOW"
}

log_error() {
    log_message "ERROR" "✗ $1" "$RED"
}

log_fatal() {
    log_message "FATAL" "💀 $1" "$PURPLE"
}

setup_logging() {
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            LOG_FILE="/tmp/github-runner-management.log"
            log_warn "Could not create log directory $log_dir, using $LOG_FILE"
        }
    fi
}

log_section() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    local line=$(printf "%*s" $width | tr ' ' '=')
    
    log_info "$line"
    log_info "$(printf "%*s %s %*s" $padding "" "$title" $padding "")"
    log_info "$line"
}

log_command() {
    local cmd="$1"
    log_debug "Executing: $cmd"
    
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        eval "$cmd" 2>&1 | while IFS= read -r line; do
            log_debug "$line"
        done
        return ${PIPESTATUS[0]}
    else
        eval "$cmd" >/dev/null 2>&1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_logging
fi