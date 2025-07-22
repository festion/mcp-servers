#!/bin/bash

# GitHub Actions Runner Backup - Common Functions
# This file contains shared functions used by all backup and restore scripts

# Global variables for backup operations
BACKUP_TEMP_DIR="/tmp/github-runner-backup"
BACKUP_LOCK_DIR="/var/lock"
BACKUP_PID_FILE="/var/run/github-runner-backup.pid"

# Load backup configuration
load_backup_config() {
    local config_file="${1:-}"
    
    if [[ -z "$config_file" ]]; then
        # Try default locations
        local default_configs=(
            "/etc/github-runner/backup.conf"
            "$HOME/.github-runner-backup.conf"
            "$(dirname "${BASH_SOURCE[0]}")/../config/backup.conf"
        )
        
        for config in "${default_configs[@]}"; do
            if [[ -f "$config" ]]; then
                config_file="$config"
                break
            fi
        done
    fi
    
    if [[ -f "$config_file" ]]; then
        # Source configuration file
        set -a
        source "$config_file"
        set +a
        log_debug "Loaded configuration from: $config_file"
    else
        log_warn "No backup configuration file found, using defaults"
    fi
    
    # Set defaults for any missing configuration
    BACKUP_DESTINATION="${BACKUP_DESTINATION:-/var/backups/github-runner}"
    BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
    BACKUP_COMPRESSION_LEVEL="${BACKUP_COMPRESSION_LEVEL:-6}"
    BACKUP_ENCRYPTION_ENABLED="${BACKUP_ENCRYPTION_ENABLED:-false}"
    BACKUP_REMOTE_ENABLED="${BACKUP_REMOTE_ENABLED:-false}"
    BACKUP_NOTIFICATION_URL="${BACKUP_NOTIFICATION_URL:-}"
    BACKUP_MAX_PARALLEL="${BACKUP_MAX_PARALLEL:-1}"
}

# Validate backup environment
validate_backup_environment() {
    log_debug "Validating backup environment..."
    
    # Check required commands
    local required_commands=("tar" "gzip" "jq" "find" "rsync")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # Check backup destination directory
    if [[ ! -d "$BACKUP_DESTINATION" ]]; then
        log_info "Creating backup destination: $BACKUP_DESTINATION"
        mkdir -p "$BACKUP_DESTINATION" || {
            log_error "Failed to create backup destination"
            exit 1
        }
    fi
    
    if [[ ! -w "$BACKUP_DESTINATION" ]]; then
        log_error "Backup destination is not writable: $BACKUP_DESTINATION"
        exit 1
    fi
    
    # Check available disk space
    local available_space_gb
    available_space_gb=$(df -BG "$BACKUP_DESTINATION" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ "$available_space_gb" -lt 2 ]]; then
        log_error "Insufficient disk space for backup (available: ${available_space_gb}GB, required: 2GB)"
        exit 1
    fi
    
    log_debug "Backup environment validation passed"
}

# Create backup directory with proper structure
create_backup_directory() {
    local destination="$1"
    
    if [[ ! -d "$destination" ]]; then
        mkdir -p "$destination" || {
            log_error "Failed to create backup directory: $destination"
            exit 1
        }
    fi
    
    # Create subdirectories for organization
    local subdirs=("archives" "manifests" "logs" "temp")
    
    for subdir in "${subdirs[@]}"; do
        if [[ ! -d "$destination/$subdir" ]]; then
            mkdir -p "$destination/$subdir" 2>/dev/null || true
        fi
    done
}

# Initialize backup manifest
init_backup_manifest() {
    local manifest_file="$1"
    local backup_id="$2"
    local backup_type="$3"
    local baseline_id="${4:-}"
    
    local manifest_content
    manifest_content=$(cat << EOF
{
    "backup_id": "$backup_id",
    "backup_type": "$backup_type",
    "baseline_id": "$baseline_id",
    "timestamp": $(date +%s),
    "iso_timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "created_by": "$(whoami)",
    "pid": $$,
    "version": "1.0",
    "status": "in_progress",
    "components": {},
    "statistics": {
        "total_files": 0,
        "total_size": 0,
        "compression_ratio": 0,
        "duration_seconds": 0
    },
    "metadata": {
        "runner_version": "",
        "system_info": "$(uname -a)",
        "backup_script_version": "1.0"
    }
}
EOF
)
    
    echo "$manifest_content" > "$manifest_file"
    log_debug "Initialized backup manifest: $manifest_file"
}

# Update backup manifest with component information
update_backup_manifest() {
    local manifest_file="$1"
    local component="$2"
    local path="$3"
    local size="$4"
    
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Manifest file not found: $manifest_file"
        return 1
    fi
    
    local temp_manifest="/tmp/manifest_update_$$.json"
    
    jq --arg component "$component" --arg path "$path" --arg size "$size" '
        .components[$component] += [{
            "path": $path,
            "size": $size,
            "timestamp": now
        }]
    ' "$manifest_file" > "$temp_manifest"
    
    mv "$temp_manifest" "$manifest_file"
}

# Finalize backup manifest
finalize_backup_manifest() {
    local manifest_file="$1"
    local backup_id="$2"
    
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Manifest file not found: $manifest_file"
        return 1
    fi
    
    local temp_manifest="/tmp/manifest_final_$$.json"
    local end_timestamp=$(date +%s)
    local start_timestamp
    start_timestamp=$(jq -r '.timestamp' "$manifest_file")
    local duration=$((end_timestamp - start_timestamp))
    
    # Calculate total statistics
    local total_files=0
    local total_size=0
    
    # Count files and size from components
    while IFS= read -r component_data; do
        if [[ -n "$component_data" ]]; then
            local component_files
            component_files=$(echo "$component_data" | jq 'length')
            total_files=$((total_files + component_files))
            
            local component_size
            component_size=$(echo "$component_data" | jq '[.[].size | tonumber] | add // 0')
            total_size=$((total_size + component_size))
        fi
    done < <(jq -r '.components[]' "$manifest_file" 2>/dev/null)
    
    # Get archive file size if it exists
    local archive_size=0
    for ext in ".tar.gz" ".tar" ".zip" ".gpg"; do
        local archive_file="$BACKUP_DESTINATION/$backup_id$ext"
        if [[ -f "$archive_file" ]]; then
            archive_size=$(stat -c%s "$archive_file" 2>/dev/null || echo "0")
            break
        fi
    done
    
    # Calculate compression ratio
    local compression_ratio=0
    if [[ "$total_size" -gt 0 && "$archive_size" -gt 0 ]]; then
        compression_ratio=$(echo "scale=2; $archive_size * 100 / $total_size" | bc 2>/dev/null || echo "0")
    fi
    
    jq --argjson end_timestamp "$end_timestamp" \
       --argjson duration "$duration" \
       --argjson total_files "$total_files" \
       --argjson total_size "$total_size" \
       --argjson archive_size "$archive_size" \
       --argjson compression_ratio "$compression_ratio" '
        .status = "completed" |
        .end_timestamp = $end_timestamp |
        .statistics.duration_seconds = $duration |
        .statistics.total_files = $total_files |
        .statistics.total_size = $total_size |
        .statistics.archive_size = $archive_size |
        .statistics.compression_ratio = $compression_ratio
    ' "$manifest_file" > "$temp_manifest"
    
    mv "$temp_manifest" "$manifest_file"
    log_debug "Finalized backup manifest: $manifest_file"
}

# Create backup archive
create_backup_archive() {
    local backup_id="$1"
    local compression_level="${2:-6}"
    
    log_info "Creating backup archive for: $backup_id"
    
    local temp_dir="/tmp/$backup_id"
    local archive_file="$BACKUP_DESTINATION/$backup_id.tar.gz"
    
    if [[ ! -d "$temp_dir" ]]; then
        log_error "Temporary backup directory not found: $temp_dir"
        return 1
    fi
    
    cd "$temp_dir"
    
    # Set compression level
    export GZIP="-$compression_level"
    
    # Create archive
    if tar -czf "$archive_file" .; then
        log_success "Backup archive created: $archive_file"
        
        # Calculate and store checksum
        local checksum
        checksum=$(sha256sum "$archive_file" | cut -d' ' -f1)
        echo "$checksum" > "$archive_file.sha256"
        
        # Get archive size for logging
        local archive_size
        archive_size=$(du -h "$archive_file" | cut -f1)
        log_info "Archive size: $archive_size"
        
    else
        log_error "Failed to create backup archive"
        return 1
    fi
    
    # Cleanup temporary directory
    rm -rf "$temp_dir"
    
    return 0
}

# Encrypt backup archive
encrypt_backup_archive() {
    local backup_id="$1"
    local gpg_key_id="${2:-$BACKUP_ENCRYPTION_KEY_ID}"
    
    if [[ -z "$gpg_key_id" ]]; then
        log_error "GPG key ID not specified for encryption"
        return 1
    fi
    
    log_info "Encrypting backup archive: $backup_id"
    
    local archive_file="$BACKUP_DESTINATION/$backup_id.tar.gz"
    local encrypted_file="$BACKUP_DESTINATION/$backup_id.tar.gz.gpg"
    
    if [[ ! -f "$archive_file" ]]; then
        log_error "Archive file not found for encryption: $archive_file"
        return 1
    fi
    
    # Check if GPG key exists
    if ! gpg --list-keys "$gpg_key_id" >/dev/null 2>&1; then
        log_error "GPG key not found: $gpg_key_id"
        return 1
    fi
    
    # Encrypt the archive
    if gpg --encrypt --recipient "$gpg_key_id" --output "$encrypted_file" "$archive_file"; then
        log_success "Backup encrypted: $encrypted_file"
        
        # Remove unencrypted archive
        rm -f "$archive_file"
        rm -f "$archive_file.sha256"
        
        # Create checksum for encrypted file
        local encrypted_checksum
        encrypted_checksum=$(sha256sum "$encrypted_file" | cut -d' ' -f1)
        echo "$encrypted_checksum" > "$encrypted_file.sha256"
        
    else
        log_error "Failed to encrypt backup archive"
        return 1
    fi
    
    return 0
}

# Sync backup to remote storage
sync_to_remote_storage() {
    local backup_id="$1"
    
    if [[ "$BACKUP_REMOTE_ENABLED" != "true" ]]; then
        log_debug "Remote backup is disabled"
        return 0
    fi
    
    local remote_destination="${BACKUP_REMOTE_DESTINATION:-}"
    
    if [[ -z "$remote_destination" ]]; then
        log_error "Remote backup destination not configured"
        return 1
    fi
    
    log_info "Syncing backup to remote storage: $backup_id"
    
    # Find backup files to sync
    local backup_files=()
    local base_pattern="$BACKUP_DESTINATION/$backup_id"
    
    for file_pattern in "$base_pattern"*; do
        if [[ -f "$file_pattern" ]]; then
            backup_files+=("$file_pattern")
        fi
    done
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        log_error "No backup files found to sync"
        return 1
    fi
    
    # Sync files to remote destination
    for backup_file in "${backup_files[@]}"; do
        local file_name=$(basename "$backup_file")
        
        case "$remote_destination" in
            s3://*)
                # AWS S3 sync
                if command -v aws >/dev/null 2>&1; then
                    aws s3 cp "$backup_file" "$remote_destination/$file_name"
                else
                    log_error "AWS CLI not available for S3 sync"
                    return 1
                fi
                ;;
            rsync://*)
                # Rsync sync
                rsync -av "$backup_file" "$remote_destination/"
                ;;
            *)
                # Generic remote copy (assumes SSH/SCP)
                scp "$backup_file" "$remote_destination/"
                ;;
        esac
        
        log_debug "Synced to remote: $file_name"
    done
    
    log_success "Remote sync completed"
    return 0
}

# Cleanup old backups
cleanup_old_backups() {
    local retention_days="${1:-$BACKUP_RETENTION_DAYS}"
    
    log_info "Cleaning up backups older than $retention_days days..."
    
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "-$retention_days days" +%s)
    
    local removed_count=0
    local total_size_freed=0
    
    # Find and remove old backups
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local backup_timestamp
            backup_timestamp=$(jq -r '.timestamp // 0' "$manifest_file" 2>/dev/null)
            
            if [[ "$backup_timestamp" -lt "$cutoff_timestamp" ]]; then
                local backup_id
                backup_id=$(jq -r '.backup_id // "unknown"' "$manifest_file" 2>/dev/null)
                
                log_debug "Removing old backup: $backup_id"
                
                # Remove all related files
                local base_pattern="$BACKUP_DESTINATION/$backup_id"
                local removed_files=()
                
                for file_pattern in "$base_pattern"*; do
                    if [[ -f "$file_pattern" ]]; then
                        local file_size
                        file_size=$(stat -c%s "$file_pattern" 2>/dev/null || echo "0")
                        total_size_freed=$((total_size_freed + file_size))
                        
                        rm -f "$file_pattern"
                        removed_files+=("$(basename "$file_pattern")")
                    fi
                done
                
                if [[ ${#removed_files[@]} -gt 0 ]]; then
                    ((removed_count++))
                    log_debug "Removed files: ${removed_files[*]}"
                fi
            fi
        fi
    done < <(find "$BACKUP_DESTINATION" -name "*.manifest.json" -print0 2>/dev/null)
    
    local size_freed_mb=$((total_size_freed / 1024 / 1024))
    
    log_info "Cleanup completed: removed $removed_count backup(s), freed ${size_freed_mb}MB"
    
    return 0
}

# Send backup notification
send_backup_notification() {
    local backup_type="$1"
    local backup_id="$2"
    local status="$3"
    local additional_info="${4:-}"
    
    local webhook_url="${BACKUP_NOTIFICATION_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_debug "No notification URL configured"
        return 0
    fi
    
    log_debug "Sending backup notification..."
    
    local notification_data
    notification_data=$(cat << EOF
{
    "type": "$backup_type",
    "backup_id": "$backup_id",
    "status": "$status",
    "hostname": "$(hostname)",
    "timestamp": "$(date -Iseconds)",
    "additional_info": "$additional_info"
}
EOF
)
    
    # Send notification
    if curl -f -s -X POST "$webhook_url" \
         -H "Content-Type: application/json" \
         -d "$notification_data" >/dev/null 2>&1; then
        log_debug "Notification sent successfully"
    else
        log_warn "Failed to send notification"
    fi
    
    return 0
}

# Check runner status before backup
check_runner_status() {
    log_debug "Checking runner status..."
    
    local runner_services=("github-runner" "actions-runner")
    local running_services=()
    
    for service in "${runner_services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            running_services+=("$service")
        fi
    done
    
    if [[ ${#running_services[@]} -gt 0 ]]; then
        log_warn "The following runner services are active:"
        for service in "${running_services[@]}"; do
            log_warn "  - $service"
        done
        log_warn "Backup may capture inconsistent state during active job execution"
    else
        log_debug "No active runner services detected"
    fi
    
    # Check for running jobs
    local job_processes
    job_processes=$(pgrep -f "_work" 2>/dev/null | wc -l)
    
    if [[ "$job_processes" -gt 0 ]]; then
        log_warn "$job_processes job process(es) detected - backup may be inconsistent"
    fi
    
    return 0
}

# Validate JSON format
validate_json() {
    local json_string="$1"
    
    echo "$json_string" | jq . >/dev/null 2>&1
    return $?
}

# Lock management for backup operations
acquire_backup_lock() {
    local lock_file="${1:-$BACKUP_PID_FILE}"
    local timeout="${2:-300}"
    
    local start_time=$(date +%s)
    
    while [[ -f "$lock_file" ]]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ "$elapsed" -ge "$timeout" ]]; then
            log_error "Failed to acquire backup lock after ${timeout}s"
            return 1
        fi
        
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")
        
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            log_warn "Removing stale lock file: $lock_file"
            rm -f "$lock_file"
            break
        fi
        
        log_debug "Waiting for backup lock to be released..."
        sleep 5
    done
    
    # Create lock file
    echo $$ > "$lock_file"
    log_debug "Acquired backup lock: $lock_file"
    
    return 0
}

# Release backup lock
release_backup_lock() {
    local lock_file="${1:-$BACKUP_PID_FILE}"
    
    if [[ -f "$lock_file" ]]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")
        
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$lock_file"
            log_debug "Released backup lock: $lock_file"
        else
            log_warn "Lock file belongs to different process: $lock_pid"
        fi
    fi
}

# Environment variables backup
backup_environment_variables() {
    local temp_dir="$1"
    
    local env_file="$temp_dir/environment-variables.txt"
    
    # Export environment variables related to runner
    env | grep -E "(GITHUB|RUNNER|ACTIONS)" | sort > "$env_file" 2>/dev/null || true
    
    # Export system environment
    {
        echo "# System Information"
        echo "HOSTNAME=$(hostname)"
        echo "USER=$(whoami)"
        echo "PWD=$(pwd)"
        echo "PATH=$PATH"
        echo "HOME=$HOME"
        echo ""
        echo "# Runtime Information"
        echo "BACKUP_TIMESTAMP=$(date +%s)"
        echo "BACKUP_ISO_TIMESTAMP=$(date -Iseconds)"
        echo "SYSTEM_UPTIME=$(uptime)"
    } >> "$env_file"
    
    log_debug "Environment variables backed up to: $env_file"
}

# Database state backup (if applicable)
backup_database_state() {
    local temp_dir="$1"
    
    # Check for common databases used by runners
    local db_file="$temp_dir/database-state.txt"
    
    {
        echo "# Database State Backup"
        echo "# Generated: $(date)"
        echo ""
        
        # Check for SQLite databases
        find /opt/github-runner /opt/actions-runner -name "*.db" -o -name "*.sqlite" 2>/dev/null | while read -r db_file_found; do
            echo "SQLite Database: $db_file_found"
            echo "Size: $(stat -c%s "$db_file_found" 2>/dev/null || echo "unknown")"
            echo "Modified: $(stat -c%y "$db_file_found" 2>/dev/null || echo "unknown")"
            echo ""
        done
        
        # Check for PostgreSQL/MySQL connections (if configured)
        if command -v systemctl >/dev/null 2>&1; then
            for db_service in postgresql mysql mariadb; do
                if systemctl is-active "$db_service" >/dev/null 2>&1; then
                    echo "Active database service: $db_service"
                fi
            done
        fi
        
    } > "$db_file"
    
    log_debug "Database state backed up to: $db_file"
}

# SSH keys backup
backup_ssh_keys() {
    local temp_dir="$1"
    
    local ssh_dir="$temp_dir/ssh"
    mkdir -p "$ssh_dir"
    
    # Backup SSH keys for runner user
    local ssh_paths=(
        "$HOME/.ssh"
        "/opt/github-runner/.ssh"
        "/opt/actions-runner/.ssh"
        "/home/runner/.ssh"
    )
    
    for ssh_path in "${ssh_paths[@]}"; do
        if [[ -d "$ssh_path" ]]; then
            local dest_name=$(echo "$ssh_path" | sed 's|/|-|g' | sed 's|^-||')
            cp -r "$ssh_path" "$ssh_dir/$dest_name" 2>/dev/null || true
            
            # Secure permissions
            find "$ssh_dir/$dest_name" -type f -exec chmod 600 {} \; 2>/dev/null || true
            
            log_debug "SSH keys backed up: $ssh_path"
        fi
    done
}

# TLS certificates backup
backup_tls_certificates() {
    local temp_dir="$1"
    
    local certs_dir="$temp_dir/certificates"
    mkdir -p "$certs_dir"
    
    # Common certificate locations
    local cert_paths=(
        "$PROJECT_ROOT/security/certs"
        "$PROJECT_ROOT/nginx/ssl"
        "/etc/ssl/certs/github-runner"
        "/etc/letsencrypt"
    )
    
    for cert_path in "${cert_paths[@]}"; do
        if [[ -d "$cert_path" ]]; then
            local dest_name=$(echo "$cert_path" | sed 's|/|-|g' | sed 's|^-||')
            cp -r "$cert_path" "$certs_dir/$dest_name" 2>/dev/null || true
            
            log_debug "Certificates backed up: $cert_path"
        fi
    done
}

# Journal logs backup
backup_journal_logs() {
    local temp_dir="$1"
    
    local logs_dir="$temp_dir/journal"
    mkdir -p "$logs_dir"
    
    # Export systemd journal logs for runner services
    local services=("github-runner" "actions-runner")
    
    for service in "${services[@]}"; do
        if systemctl list-units --type=service | grep -q "$service"; then
            journalctl -u "$service" --since "7 days ago" > "$logs_dir/$service.log" 2>/dev/null || true
            log_debug "Journal logs backed up for: $service"
        fi
    done
    
    # Export kernel and system logs related to runners
    journalctl --since "24 hours ago" | grep -E "(runner|github|actions)" > "$logs_dir/system.log" 2>/dev/null || true
}

# Performance data backup
backup_performance_data() {
    local temp_dir="$1"
    
    local perf_dir="$temp_dir/performance"
    mkdir -p "$perf_dir"
    
    # System performance data
    {
        echo "# System Performance Data"
        echo "# Generated: $(date)"
        echo ""
        
        echo "## CPU Information"
        cat /proc/cpuinfo | grep -E "(processor|model name|cpu MHz)" || true
        echo ""
        
        echo "## Memory Information"
        cat /proc/meminfo || true
        echo ""
        
        echo "## Load Average"
        uptime || true
        echo ""
        
        echo "## Disk Usage"
        df -h || true
        echo ""
        
        echo "## Network Statistics"
        cat /proc/net/dev || true
        echo ""
        
    } > "$perf_dir/system-performance.txt"
    
    # Process information
    ps aux | grep -E "(runner|github)" > "$perf_dir/runner-processes.txt" 2>/dev/null || true
    
    log_debug "Performance data backed up to: $perf_dir"
}

# Cleanup function for emergency exit
cleanup_on_exit() {
    local exit_code=$?
    
    # Release backup lock
    release_backup_lock
    
    # Cleanup temporary files
    rm -rf "$BACKUP_TEMP_DIR"* 2>/dev/null || true
    
    # Log exit status
    if [[ "$exit_code" -ne 0 ]]; then
        log_error "Backup operation failed with exit code: $exit_code"
    fi
    
    exit $exit_code
}

# Set up exit trap
trap cleanup_on_exit EXIT INT TERM

# Utility function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Utility function to get human readable file size
get_human_size() {
    local size_bytes="$1"
    
    if command_exists numfmt; then
        numfmt --to=iec-i --suffix=B --format="%.1f" "$size_bytes"
    else
        # Fallback calculation
        local units=("B" "KB" "MB" "GB" "TB")
        local size=$size_bytes
        local unit_index=0
        
        while [[ $size -gt 1024 && $unit_index -lt 4 ]]; do
            size=$((size / 1024))
            ((unit_index++))
        done
        
        echo "${size}${units[$unit_index]}"
    fi
}

# Export functions for use in other scripts
export -f load_backup_config
export -f validate_backup_environment
export -f create_backup_directory
export -f init_backup_manifest
export -f update_backup_manifest
export -f finalize_backup_manifest
export -f create_backup_archive
export -f encrypt_backup_archive
export -f sync_to_remote_storage
export -f cleanup_old_backups
export -f send_backup_notification
export -f check_runner_status
export -f validate_json
export -f acquire_backup_lock
export -f release_backup_lock
export -f backup_environment_variables
export -f backup_database_state
export -f backup_ssh_keys
export -f backup_tls_certificates
export -f backup_journal_logs
export -f backup_performance_data
export -f command_exists
export -f get_human_size