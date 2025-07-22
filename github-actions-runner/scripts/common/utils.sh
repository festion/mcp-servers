#!/bin/bash

get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
}

get_project_root() {
    local script_dir
    script_dir=$(get_script_dir)
    echo "$(dirname "$script_dir")"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

require_user() {
    local required_user="$1"
    local current_user=$(whoami)
    
    if [[ "$current_user" != "$required_user" ]]; then
        log_error "This script must be run as user: $required_user (current: $current_user)"
        exit 1
    fi
}

check_command() {
    local cmd="$1"
    local package="$2"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [[ -n "$package" ]]; then
            log_error "$cmd is not installed. Install it with: apt-get install $package"
        else
            log_error "$cmd is not available"
        fi
        return 1
    fi
    return 0
}

wait_for_service() {
    local service="$1"
    local max_wait="${2:-30}"
    local count=0
    
    log_info "Waiting for service $service to be ready..."
    
    while [[ $count -lt $max_wait ]]; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_success "Service $service is ready"
            return 0
        fi
        
        sleep 1
        ((count++))
        
        if [[ $((count % 5)) -eq 0 ]]; then
            log_info "Still waiting for $service... ($count/$max_wait)"
        fi
    done
    
    log_error "Service $service failed to start within $max_wait seconds"
    return 1
}

get_service_status() {
    local service="$1"
    
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo "active"
    elif systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "inactive"
    else
        echo "disabled"
    fi
}

format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size=$bytes
    
    while [[ $size -gt 1024 && $unit -lt ${#units[@]} ]]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "${size}${units[$unit]}"
}

get_system_info() {
    cat << EOF
{
    "hostname": "$(hostname)",
    "os": "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)",
    "uptime": "$(uptime -p 2>/dev/null || echo 'Unknown')",
    "load_average": "$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//' || echo 'Unknown')",
    "memory_total": "$(free -h | awk '/^Mem:/ {print $2}')",
    "memory_used": "$(free -h | awk '/^Mem:/ {print $3}')",
    "memory_available": "$(free -h | awk '/^Mem:/ {print $7}')",
    "disk_usage": "$(df -h / | awk 'NR==2 {print $5}')",
    "timestamp": "$(date -Iseconds)"
}
EOF
}

validate_json() {
    local json_string="$1"
    
    if echo "$json_string" | jq . >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

lock_script() {
    local lock_file="$1"
    local timeout="${2:-300}"
    
    if [[ -z "$lock_file" ]]; then
        log_error "Lock file path is required"
        return 1
    fi
    
    local lock_dir
    lock_dir="$(dirname "$lock_file")"
    mkdir -p "$lock_dir" 2>/dev/null || {
        log_error "Cannot create lock directory: $lock_dir"
        return 1
    }
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        if (set -C; echo $$ > "$lock_file") 2>/dev/null; then
            log_debug "Acquired lock: $lock_file"
            return 0
        fi
        
        if [[ -f "$lock_file" ]]; then
            local lock_pid
            lock_pid=$(cat "$lock_file" 2>/dev/null)
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                log_warn "Removing stale lock file: $lock_file"
                rm -f "$lock_file"
                continue
            fi
        fi
        
        sleep 1
        ((count++))
    done
    
    log_error "Failed to acquire lock after $timeout seconds: $lock_file"
    return 1
}

unlock_script() {
    local lock_file="$1"
    
    if [[ -f "$lock_file" ]]; then
        rm -f "$lock_file"
        log_debug "Released lock: $lock_file"
    fi
}

send_notification() {
    local level="$1"
    local title="$2"
    local message="$3"
    local webhook_url="${WEBHOOK_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_debug "No webhook URL configured, skipping notification"
        return 0
    fi
    
    local color
    case "$level" in
        success|info) color="good" ;;
        warning) color="warning" ;;
        error|critical) color="danger" ;;
        *) color="#808080" ;;
    esac
    
    local payload
    payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "$title",
            "text": "$message",
            "footer": "GitHub Actions Runner - $(hostname)",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    if validate_json "$payload"; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$webhook_url" >/dev/null 2>&1 || {
            log_warn "Failed to send notification"
        }
    else
        log_error "Invalid notification payload"
    fi
}

retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local cmd=("$@")
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: ${cmd[*]}"
        
        if "${cmd[@]}"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Command failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts: ${cmd[*]}"
    return 1
}

backup_file() {
    local file="$1"
    local backup_dir="${2:-$(dirname "$file")}"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    local backup_name
    backup_name="$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
    local backup_path="$backup_dir/$backup_name"
    
    mkdir -p "$backup_dir"
    
    if cp "$file" "$backup_path"; then
        log_success "Backed up $file to $backup_path"
        echo "$backup_path"
        return 0
    else
        log_error "Failed to backup $file"
        return 1
    fi
}

restore_file() {
    local backup_path="$1"
    local original_path="$2"
    
    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup file not found: $backup_path"
        return 1
    fi
    
    if cp "$backup_path" "$original_path"; then
        log_success "Restored $original_path from $backup_path"
        return 0
    else
        log_error "Failed to restore $original_path"
        return 1
    fi
}

cleanup_old_files() {
    local directory="$1"
    local pattern="$2"
    local days="${3:-30}"
    
    if [[ ! -d "$directory" ]]; then
        log_warn "Directory not found: $directory"
        return 1
    fi
    
    local found_files
    found_files=$(find "$directory" -name "$pattern" -type f -mtime +$days 2>/dev/null)
    
    if [[ -n "$found_files" ]]; then
        echo "$found_files" | while IFS= read -r file; do
            if rm -f "$file"; then
                log_debug "Removed old file: $file"
            else
                log_warn "Failed to remove: $file"
            fi
        done
        
        local count
        count=$(echo "$found_files" | wc -l)
        log_success "Cleaned up $count old files from $directory"
    else
        log_debug "No old files found in $directory matching $pattern"
    fi
}

check_disk_space() {
    local path="${1:-.}"
    local threshold="${2:-90}"
    
    local usage
    usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $usage -gt $threshold ]]; then
        log_error "Disk usage is ${usage}% (threshold: ${threshold}%) for $path"
        return 1
    else
        log_debug "Disk usage is ${usage}% for $path"
        return 0
    fi
}

check_memory_usage() {
    local threshold="${1:-90}"
    
    local usage
    usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [[ $usage -gt $threshold ]]; then
        log_error "Memory usage is ${usage}% (threshold: ${threshold}%)"
        return 1
    else
        log_debug "Memory usage is ${usage}%"
        return 0
    fi
}

trap_cleanup() {
    local cleanup_function="$1"
    shift
    local signals=("$@")
    
    if [[ ${#signals[@]} -eq 0 ]]; then
        signals=("EXIT" "INT" "TERM")
    fi
    
    for signal in "${signals[@]}"; do
        trap "$cleanup_function" "$signal"
    done
}