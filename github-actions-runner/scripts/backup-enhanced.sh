#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-backup.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Backup and recovery for GitHub Actions runner

COMMANDS:
    create              Create a new backup
    list                List available backups
    restore BACKUP_ID   Restore from specific backup
    verify BACKUP_ID    Verify backup integrity
    cleanup             Clean up old backups
    schedule            Set up automated backup schedule

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Backup destination [default: /var/backups/github-runner]
    -c, --compress LEVEL    Compression level 0-9 [default: 6]
    -e, --encrypt           Encrypt backup with GPG
    -k, --key-id KEY        GPG key ID for encryption
    --retention-days DAYS   Retention period [default: 30]
    --exclude PATTERN       Exclude files matching pattern
    --include-logs          Include log files in backup
    --skip-validation       Skip pre-backup validation
    -v, --verbose           Verbose output
    -j, --json              JSON output format

Examples:
    $0 create                           # Create standard backup
    $0 create --encrypt --key-id ABC123 # Encrypted backup
    $0 list --json                      # List backups in JSON
    $0 restore backup-20240115-143022   # Restore specific backup
    $0 cleanup --retention-days 7       # Keep only 7 days
EOF
}

COMMAND=""
DESTINATION="/var/backups/github-runner"
COMPRESSION_LEVEL=6
ENCRYPT=false
GPG_KEY_ID=""
RETENTION_DAYS=30
EXCLUDE_PATTERNS=()
INCLUDE_LOGS=false
SKIP_VALIDATION=false
VERBOSE=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESSION_LEVEL="$2"
            shift 2
            ;;
        -e|--encrypt)
            ENCRYPT=true
            shift
            ;;
        -k|--key-id)
            GPG_KEY_ID="$2"
            shift 2
            ;;
        --retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        --include-logs)
            INCLUDE_LOGS=true
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        create|list|restore|verify|cleanup|schedule)
            COMMAND="$1"
            shift
            # For restore and verify, the next argument is the backup ID
            if [[ "$COMMAND" =~ ^(restore|verify)$ ]] && [[ $# -gt 0 ]]; then
                BACKUP_ID="$1"
                shift
            fi
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    log_error "Command is required"
    usage
    exit 1
fi

if [[ "$COMPRESSION_LEVEL" -lt 0 ]] || [[ "$COMPRESSION_LEVEL" -gt 9 ]]; then
    log_error "Compression level must be between 0 and 9"
    exit 1
fi

load_configuration() {
    local config_file="/etc/github-runner/config.env"
    if [[ ! -f "$config_file" ]]; then
        config_file="$PROJECT_ROOT/config/runner.env"
    fi
    
    if [[ -f "$config_file" ]]; then
        set -a
        source "$config_file"
        set +a
    fi
    
    # Override with environment variables
    DESTINATION="${BACKUP_LOCATION:-$DESTINATION}"
    RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-$RETENTION_DAYS}"
    
    if [[ "${BACKUP_ENABLED:-true}" != "true" ]]; then
        log_warn "Backups are disabled in configuration"
    fi
}

check_prerequisites() {
    log_debug "Checking backup prerequisites..."
    
    # Check required commands
    local required_commands=("tar" "gzip")
    
    if [[ "$ENCRYPT" == true ]]; then
        required_commands+=("gpg")
        
        if [[ -n "$GPG_KEY_ID" ]]; then
            if ! gpg --list-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
                log_error "GPG key not found: $GPG_KEY_ID"
                exit 1
            fi
        else
            log_error "GPG key ID is required for encryption"
            exit 1
        fi
    fi
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # Check destination directory
    if [[ ! -d "$DESTINATION" ]]; then
        log_info "Creating backup destination: $DESTINATION"
        mkdir -p "$DESTINATION"
    fi
    
    if [[ ! -w "$DESTINATION" ]]; then
        log_error "Backup destination is not writable: $DESTINATION"
        exit 1
    fi
    
    # Check disk space
    local required_space_gb=1
    local available_space_gb
    available_space_gb=$(df -BG "$DESTINATION" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ "$available_space_gb" -lt "$required_space_gb" ]]; then
        log_error "Insufficient disk space for backup (available: ${available_space_gb}GB, required: ${required_space_gb}GB)"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

validate_runner_state() {
    if [[ "$SKIP_VALIDATION" == true ]]; then
        log_info "Skipping validation"
        return 0
    fi
    
    log_section "Runner State Validation"
    
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    
    # Check if runner is configured
    if [[ ! -f "$install_path/.runner" ]]; then
        log_error "Runner is not configured at $install_path"
        exit 1
    fi
    
    # Check if runner is registered
    if ! cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
        log_warn "Runner registration check failed"
    fi
    
    # Check for running jobs
    local running_jobs=0
    if [[ -d "$install_path/_work" ]]; then
        running_jobs=$(find "$install_path/_work" -name "*.pid" 2>/dev/null | wc -l)
    fi
    
    if [[ "$running_jobs" -gt 0 ]]; then
        log_warn "$running_jobs job(s) currently running - backup may be inconsistent"
    fi
    
    log_success "Runner state validation completed"
}

create_backup() {
    log_section "Creating Backup"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_id="backup-$timestamp"
    local backup_base="$DESTINATION/$backup_id"
    
    log_info "Backup ID: $backup_id"
    log_info "Destination: $DESTINATION"
    
    validate_runner_state
    
    # Create backup metadata
    local metadata_file="$backup_base.metadata.json"
    local backup_metadata
    backup_metadata=$(cat << EOF
{
    "backup_id": "$backup_id",
    "timestamp": $(date +%s),
    "iso_timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "runner_path": "${INSTALL_PATH:-/opt/github-runner}",
    "compression_level": $COMPRESSION_LEVEL,
    "encrypted": $ENCRYPT,
    "includes_logs": $INCLUDE_LOGS,
    "created_by": "$(whoami)",
    "version": "1.0"
}
EOF
)
    
    echo "$backup_metadata" > "$metadata_file"
    
    # Prepare tar command
    local tar_cmd="tar"
    local tar_options="--create --file=$backup_base.tar"
    
    # Add compression
    if [[ "$COMPRESSION_LEVEL" -gt 0 ]]; then
        tar_options="$tar_options --gzip"
        backup_base="$backup_base.tar.gz"
    fi
    
    # Add verbosity
    if [[ "$VERBOSE" == true ]]; then
        tar_options="$tar_options --verbose"
    fi
    
    # Build exclude patterns
    local exclude_args=()
    
    # Default excludes
    exclude_args+=("--exclude=_work/_temp")
    exclude_args+=("--exclude=_work/*/actions-runner-*")
    exclude_args+=("--exclude=*.pid")
    exclude_args+=("--exclude=*.lock")
    
    # User-specified excludes
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        exclude_args+=("--exclude=$pattern")
    done
    
    # Conditional excludes
    if [[ "$INCLUDE_LOGS" != true ]]; then
        exclude_args+=("--exclude=*.log")
        exclude_args+=("--exclude=logs/*")
    fi
    
    # Backup components
    local backup_items=()
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    
    # Runner installation
    if [[ -d "$install_path" ]]; then
        backup_items+=("$install_path")
        log_info "Including runner installation: $install_path"
    fi
    
    # Configuration files
    if [[ -d "/etc/github-runner" ]]; then
        backup_items+=("/etc/github-runner")
        log_info "Including configuration: /etc/github-runner"
    fi
    
    # Systemd service
    if [[ -f "/etc/systemd/system/github-runner.service" ]]; then
        backup_items+=("/etc/systemd/system/github-runner.service")
        log_info "Including systemd service"
    fi
    
    # Project root (if different from install path)
    if [[ "$PROJECT_ROOT" != "$install_path" ]] && [[ -d "$PROJECT_ROOT" ]]; then
        backup_items+=("$PROJECT_ROOT")
        log_info "Including project root: $PROJECT_ROOT"
    fi
    
    # Log directories
    if [[ "$INCLUDE_LOGS" == true ]]; then
        local log_dirs=("/var/log/github-runner" "$PROJECT_ROOT/logs")
        for log_dir in "${log_dirs[@]}"; do
            if [[ -d "$log_dir" ]]; then
                backup_items+=("$log_dir")
                log_info "Including logs: $log_dir"
            fi
        done
    fi
    
    if [[ ${#backup_items[@]} -eq 0 ]]; then
        log_error "No backup items found"
        exit 1
    fi
    
    # Create the backup
    log_info "Creating backup archive..."
    
    local backup_file="$backup_base"
    if [[ "$COMPRESSION_LEVEL" -gt 0 ]]; then
        backup_file="$backup_base"
    else
        backup_file="$backup_base.tar"
    fi
    
    # Set compression level
    export GZIP="-$COMPRESSION_LEVEL"
    
    if eval "$tar_cmd $tar_options ${exclude_args[*]} ${backup_items[*]}"; then
        log_success "Backup archive created: $backup_file"
    else
        log_error "Failed to create backup archive"
        rm -f "$backup_file" "$metadata_file"
        exit 1
    fi
    
    # Update metadata with file information
    local backup_size
    backup_size=$(du -h "$backup_file" | cut -f1)
    local backup_size_bytes
    backup_size_bytes=$(stat -c%s "$backup_file")
    
    local checksum
    checksum=$(sha256sum "$backup_file" | cut -d' ' -f1)
    
    backup_metadata=$(echo "$backup_metadata" | jq --arg size "$backup_size" --arg size_bytes "$backup_size_bytes" --arg checksum "$checksum" '. + {
        "size": $size,
        "size_bytes": ($size_bytes | tonumber),
        "sha256": $checksum
    }')
    
    echo "$backup_metadata" > "$metadata_file"
    
    # Encrypt if requested
    if [[ "$ENCRYPT" == true ]]; then
        log_info "Encrypting backup..."
        
        local encrypted_file="$backup_file.gpg"
        
        if gpg --encrypt --recipient "$GPG_KEY_ID" --output "$encrypted_file" "$backup_file"; then
            rm -f "$backup_file"
            backup_file="$encrypted_file"
            
            # Update metadata
            backup_metadata=$(echo "$backup_metadata" | jq --arg encrypted_file "$(basename "$encrypted_file")" '. + {
                "encrypted_file": $encrypted_file
            }')
            echo "$backup_metadata" > "$metadata_file"
            
            log_success "Backup encrypted: $backup_file"
        else
            log_error "Failed to encrypt backup"
            rm -f "$backup_file" "$metadata_file" "$encrypted_file"
            exit 1
        fi
    fi
    
    # Create backup manifest
    local manifest_file="$backup_base.manifest"
    cat > "$manifest_file" << EOF
# GitHub Actions Runner Backup Manifest
# Created: $(date)
# Backup ID: $backup_id

Archive: $(basename "$backup_file")
Size: $backup_size
Checksum: $checksum
Encrypted: $ENCRYPT

Components:
$(printf '  %s\n' "${backup_items[@]}")

Excludes:
$(printf '  %s\n' "${exclude_args[@]#--exclude=}")
EOF
    
    # Final verification
    if [[ "$ENCRYPT" == true ]]; then
        # Verify GPG file
        if ! gpg --list-packets "$backup_file" >/dev/null 2>&1; then
            log_error "Backup encryption verification failed"
            exit 1
        fi
    else
        # Verify tar file
        if ! tar -tf "$backup_file" >/dev/null 2>&1; then
            log_error "Backup archive verification failed"
            exit 1
        fi
    fi
    
    log_section "Backup Complete"
    log_success "Backup created successfully"
    log_info "Backup ID: $backup_id"
    log_info "Location: $backup_file"
    log_info "Size: $backup_size"
    log_info "Files: $metadata_file, $manifest_file"
    
    # Send notification if configured
    send_notification "success" "Backup Created" "GitHub Actions runner backup created on $(hostname): $backup_id ($backup_size)"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$backup_metadata" | jq .
    fi
    
    echo "$backup_id"
}

list_backups() {
    log_debug "Listing backups from: $DESTINATION"
    
    if [[ ! -d "$DESTINATION" ]]; then
        if [[ "$JSON_OUTPUT" == true ]]; then
            echo "[]"
        else
            log_info "No backup directory found: $DESTINATION"
        fi
        return 0
    fi
    
    local backups_json="[]"
    local backup_data=""
    
    # Find all metadata files
    while IFS= read -r -d '' metadata_file; do
        if [[ -f "$metadata_file" ]]; then
            local backup_metadata
            backup_metadata=$(cat "$metadata_file" 2>/dev/null || echo "{}")
            
            if validate_json "$backup_metadata"; then
                local backup_id
                backup_id=$(echo "$backup_metadata" | jq -r '.backup_id // "unknown"')
                
                local archive_file=""
                local encrypted_file
                encrypted_file=$(echo "$backup_metadata" | jq -r '.encrypted_file // ""')
                
                if [[ -n "$encrypted_file" ]]; then
                    archive_file="$DESTINATION/$encrypted_file"
                else
                    # Look for tar or tar.gz file
                    for ext in ".tar.gz" ".tar"; do
                        local potential_file="$DESTINATION/$backup_id$ext"
                        if [[ -f "$potential_file" ]]; then
                            archive_file="$potential_file"
                            break
                        fi
                    done
                fi
                
                local exists=false
                local actual_size=""
                if [[ -f "$archive_file" ]]; then
                    exists=true
                    actual_size=$(du -h "$archive_file" | cut -f1)
                fi
                
                local enhanced_metadata
                enhanced_metadata=$(echo "$backup_metadata" | jq --arg exists "$exists" --arg actual_size "$actual_size" --arg archive_path "$archive_file" '. + {
                    "exists": ($exists | test("true")),
                    "actual_size": $actual_size,
                    "archive_path": $archive_path
                }')
                
                if [[ -z "$backup_data" ]]; then
                    backup_data="$enhanced_metadata"
                else
                    backup_data="$backup_data,$enhanced_metadata"
                fi
            fi
        fi
    done < <(find "$DESTINATION" -name "*.metadata.json" -print0 2>/dev/null)
    
    if [[ -n "$backup_data" ]]; then
        backups_json="[$backup_data]"
    fi
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$backups_json" | jq 'sort_by(.timestamp) | reverse'
    else
        local backup_count
        backup_count=$(echo "$backups_json" | jq length)
        
        if [[ "$backup_count" -gt 0 ]]; then
            echo "Available Backups ($backup_count):"
            echo "========================="
            
            echo "$backups_json" | jq -r 'sort_by(.timestamp) | reverse | .[] | 
                "\(.iso_timestamp) \(.backup_id) \(.actual_size // .size) \(if .encrypted then "(encrypted)" else "" end) \(if .exists then "✓" else "✗" end)"' | \
                column -t -N "DATE,BACKUP_ID,SIZE,TYPE,EXISTS"
        else
            log_info "No backups found in: $DESTINATION"
        fi
    fi
}

verify_backup() {
    local backup_id="$1"
    
    log_section "Verifying Backup: $backup_id"
    
    local metadata_file="$DESTINATION/$backup_id.metadata.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        log_error "Backup metadata not found: $metadata_file"
        exit 1
    fi
    
    local backup_metadata
    backup_metadata=$(cat "$metadata_file")
    
    if ! validate_json "$backup_metadata"; then
        log_error "Invalid backup metadata"
        exit 1
    fi
    
    local encrypted_file
    encrypted_file=$(echo "$backup_metadata" | jq -r '.encrypted_file // ""')
    
    local archive_file=""
    if [[ -n "$encrypted_file" ]]; then
        archive_file="$DESTINATION/$encrypted_file"
    else
        # Look for tar or tar.gz file
        for ext in ".tar.gz" ".tar"; do
            local potential_file="$DESTINATION/$backup_id$ext"
            if [[ -f "$potential_file" ]]; then
                archive_file="$potential_file"
                break
            fi
        done
    fi
    
    if [[ ! -f "$archive_file" ]]; then
        log_error "Backup archive not found: $archive_file"
        exit 1
    fi
    
    log_info "Verifying archive: $(basename "$archive_file")"
    
    # Verify checksum if available
    local stored_checksum
    stored_checksum=$(echo "$backup_metadata" | jq -r '.sha256 // ""')
    
    if [[ -n "$stored_checksum" ]]; then
        log_info "Verifying checksum..."
        local current_checksum
        current_checksum=$(sha256sum "$archive_file" | cut -d' ' -f1)
        
        if [[ "$current_checksum" == "$stored_checksum" ]]; then
            log_success "Checksum verification passed"
        else
            log_error "Checksum verification failed"
            log_error "Expected: $stored_checksum"
            log_error "Actual: $current_checksum"
            exit 1
        fi
    else
        log_warn "No checksum available for verification"
    fi
    
    # Verify archive integrity
    local is_encrypted
    is_encrypted=$(echo "$backup_metadata" | jq -r '.encrypted // false')
    
    if [[ "$is_encrypted" == "true" ]]; then
        log_info "Verifying encrypted archive integrity..."
        
        if ! gpg --list-packets "$archive_file" >/dev/null 2>&1; then
            log_error "Encrypted archive integrity check failed"
            exit 1
        fi
        
        log_success "Encrypted archive integrity verified"
        
        # Try to decrypt and verify tar integrity
        log_info "Testing decryption and tar integrity..."
        
        if gpg --decrypt "$archive_file" 2>/dev/null | tar -tf - >/dev/null 2>&1; then
            log_success "Decryption and tar integrity verified"
        else
            log_error "Decryption or tar integrity check failed"
            exit 1
        fi
    else
        log_info "Verifying tar archive integrity..."
        
        if tar -tf "$archive_file" >/dev/null 2>&1; then
            log_success "Tar archive integrity verified"
        else
            log_error "Tar archive integrity check failed"
            exit 1
        fi
    fi
    
    # Verify file count
    log_info "Counting archive contents..."
    
    local file_count
    if [[ "$is_encrypted" == "true" ]]; then
        file_count=$(gpg --decrypt "$archive_file" 2>/dev/null | tar -tf - | wc -l)
    else
        file_count=$(tar -tf "$archive_file" | wc -l)
    fi
    
    log_info "Archive contains $file_count files/directories"
    
    # Show backup details
    local backup_size
    backup_size=$(echo "$backup_metadata" | jq -r '.size // "unknown"')
    local created_date
    created_date=$(echo "$backup_metadata" | jq -r '.iso_timestamp // "unknown"')
    
    log_section "Verification Complete"
    log_success "Backup verification passed"
    log_info "Backup ID: $backup_id"
    log_info "Created: $created_date"
    log_info "Size: $backup_size"
    log_info "Files: $file_count"
    log_info "Encrypted: $is_encrypted"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        local verification_result
        verification_result=$(cat << EOF
{
    "backup_id": "$backup_id",
    "verification_status": "passed",
    "timestamp": "$(date -Iseconds)",
    "archive_file": "$(basename "$archive_file")",
    "file_count": $file_count,
    "checksum_verified": $(if [[ -n "$stored_checksum" ]]; then echo "true"; else echo "false"; fi),
    "integrity_verified": true,
    "metadata": $backup_metadata
}
EOF
)
        echo "$verification_result" | jq .
    fi
}

cleanup_old_backups() {
    log_section "Cleaning Up Old Backups"
    
    if [[ ! -d "$DESTINATION" ]]; then
        log_info "No backup directory found: $DESTINATION"
        return 0
    fi
    
    log_info "Retention period: $RETENTION_DAYS days"
    
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "-$RETENTION_DAYS days" +%s)
    
    local removed_count=0
    local total_size_saved=0
    
    # Find old backups
    while IFS= read -r -d '' metadata_file; do
        if [[ -f "$metadata_file" ]]; then
            local backup_metadata
            backup_metadata=$(cat "$metadata_file" 2>/dev/null || echo "{}")
            
            if validate_json "$backup_metadata"; then
                local backup_timestamp
                backup_timestamp=$(echo "$backup_metadata" | jq -r '.timestamp // 0')
                
                if [[ "$backup_timestamp" -lt "$cutoff_timestamp" ]]; then
                    local backup_id
                    backup_id=$(echo "$backup_metadata" | jq -r '.backup_id // "unknown"')
                    
                    log_info "Removing old backup: $backup_id"
                    
                    # Find and remove all related files
                    local base_pattern="$DESTINATION/$backup_id"
                    local removed_files=()
                    
                    for file_pattern in "$base_pattern"* "$metadata_file"; do
                        if [[ -f "$file_pattern" ]]; then
                            local file_size
                            file_size=$(stat -c%s "$file_pattern" 2>/dev/null || echo "0")
                            total_size_saved=$((total_size_saved + file_size))
                            
                            rm -f "$file_pattern"
                            removed_files+=("$(basename "$file_pattern")")
                        fi
                    done
                    
                    if [[ ${#removed_files[@]} -gt 0 ]]; then
                        log_info "Removed files: ${removed_files[*]}"
                        ((removed_count++))
                    fi
                fi
            fi
        fi
    done < <(find "$DESTINATION" -name "*.metadata.json" -print0 2>/dev/null)
    
    local size_saved_mb=$((total_size_saved / 1024 / 1024))
    
    log_section "Cleanup Complete"
    log_success "Removed $removed_count old backup(s)"
    log_info "Space freed: ${size_saved_mb}MB"
    
    if [[ "$removed_count" -gt 0 ]]; then
        send_notification "info" "Backup Cleanup" "Removed $removed_count old backup(s) from $(hostname), freed ${size_saved_mb}MB"
    fi
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        cat << EOF
{
    "cleanup_timestamp": "$(date -Iseconds)",
    "retention_days": $RETENTION_DAYS,
    "removed_backups": $removed_count,
    "space_freed_mb": $size_saved_mb
}
EOF
    fi
}

restore_backup() {
    local backup_id="$1"
    
    log_section "Restoring Backup: $backup_id"
    
    local metadata_file="$DESTINATION/$backup_id.metadata.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        log_error "Backup metadata not found: $metadata_file"
        exit 1
    fi
    
    local backup_metadata
    backup_metadata=$(cat "$metadata_file")
    
    # Verify backup first
    log_info "Verifying backup before restore..."
    if ! verify_backup "$backup_id" >/dev/null 2>&1; then
        log_error "Backup verification failed, aborting restore"
        exit 1
    fi
    
    log_warn "WARNING: This will overwrite existing runner configuration!"
    log_warn "Make sure to stop the runner service before proceeding."
    
    # Check if service is running
    if systemctl is-active github-runner.service >/dev/null 2>&1; then
        log_error "GitHub runner service is still running"
        log_error "Stop the service first: systemctl stop github-runner"
        exit 1
    fi
    
    # Find archive file
    local encrypted_file
    encrypted_file=$(echo "$backup_metadata" | jq -r '.encrypted_file // ""')
    
    local archive_file=""
    if [[ -n "$encrypted_file" ]]; then
        archive_file="$DESTINATION/$encrypted_file"
    else
        for ext in ".tar.gz" ".tar"; do
            local potential_file="$DESTINATION/$backup_id$ext"
            if [[ -f "$potential_file" ]]; then
                archive_file="$potential_file"
                break
            fi
        done
    fi
    
    if [[ ! -f "$archive_file" ]]; then
        log_error "Backup archive not found"
        exit 1
    fi
    
    # Create restore backup of current state
    local restore_backup_dir="/tmp/github-runner-restore-backup-$(date +%s)"
    mkdir -p "$restore_backup_dir"
    
    log_info "Creating safety backup of current state..."
    
    local current_items=()
    local install_path
    install_path=$(echo "$backup_metadata" | jq -r '.runner_path // "/opt/github-runner"')
    
    if [[ -d "$install_path" ]]; then
        cp -r "$install_path" "$restore_backup_dir/" 2>/dev/null || true
        current_items+=("$install_path")
    fi
    
    if [[ -d "/etc/github-runner" ]]; then
        cp -r "/etc/github-runner" "$restore_backup_dir/" 2>/dev/null || true
        current_items+=("/etc/github-runner")
    fi
    
    if [[ -f "/etc/systemd/system/github-runner.service" ]]; then
        cp "/etc/systemd/system/github-runner.service" "$restore_backup_dir/" 2>/dev/null || true
        current_items+=("/etc/systemd/system/github-runner.service")
    fi
    
    log_info "Safety backup created: $restore_backup_dir"
    
    # Perform restore
    log_info "Extracting backup archive..."
    
    local is_encrypted
    is_encrypted=$(echo "$backup_metadata" | jq -r '.encrypted // false')
    
    if [[ "$is_encrypted" == "true" ]]; then
        log_info "Decrypting and extracting..."
        
        if gpg --decrypt "$archive_file" | tar -xzf - -C /; then
            log_success "Backup restored successfully"
        else
            log_error "Failed to decrypt and extract backup"
            
            # Attempt to restore from safety backup
            log_info "Attempting to restore from safety backup..."
            for item in "${current_items[@]}"; do
                local item_name
                item_name=$(basename "$item")
                if [[ -e "$restore_backup_dir/$item_name" ]]; then
                    cp -r "$restore_backup_dir/$item_name" "$item"
                fi
            done
            
            exit 1
        fi
    else
        log_info "Extracting archive..."
        
        if tar -xzf "$archive_file" -C /; then
            log_success "Backup restored successfully"
        else
            log_error "Failed to extract backup"
            
            # Attempt to restore from safety backup
            log_info "Attempting to restore from safety backup..."
            for item in "${current_items[@]}"; do
                local item_name
                item_name=$(basename "$item")
                if [[ -e "$restore_backup_dir/$item_name" ]]; then
                    cp -r "$restore_backup_dir/$item_name" "$item"
                fi
            done
            
            exit 1
        fi
    fi
    
    # Reload systemd if service file was restored
    if [[ -f "/etc/systemd/system/github-runner.service" ]]; then
        log_info "Reloading systemd configuration..."
        systemctl daemon-reload
    fi
    
    # Set proper permissions
    local user
    user=$(echo "$backup_metadata" | jq -r '.created_by // "github-runner"')
    
    if [[ -d "$install_path" ]]; then
        chown -R "$user:$user" "$install_path" 2>/dev/null || true
        chmod +x "$install_path"/*.sh 2>/dev/null || true
    fi
    
    # Cleanup safety backup
    rm -rf "$restore_backup_dir"
    
    log_section "Restore Complete"
    log_success "Backup restored successfully"
    log_info "Backup ID: $backup_id"
    log_info "Restored to: $install_path"
    log_warn "Remember to start the service: systemctl start github-runner"
    
    send_notification "info" "Backup Restored" "GitHub Actions runner restored from backup $backup_id on $(hostname)"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        cat << EOF
{
    "restore_timestamp": "$(date -Iseconds)",
    "backup_id": "$backup_id",
    "status": "success",
    "restored_path": "$install_path"
}
EOF
    fi
}

setup_backup_schedule() {
    log_section "Setting Up Backup Schedule"
    
    local cron_job="0 2 * * * $SCRIPT_DIR/backup-enhanced.sh create >/dev/null 2>&1"
    local cron_cleanup="0 3 * * 0 $SCRIPT_DIR/backup-enhanced.sh cleanup >/dev/null 2>&1"
    
    # Check if already scheduled
    if crontab -l 2>/dev/null | grep -q "backup-enhanced.sh"; then
        log_warn "Backup schedule already exists"
        
        if [[ -t 0 ]]; then
            read -p "Replace existing schedule? (y/N): " replace_choice
            if [[ ! "$replace_choice" =~ ^[Yy]$ ]]; then
                log_info "Keeping existing schedule"
                return 0
            fi
        else
            log_info "Keeping existing schedule"
            return 0
        fi
    fi
    
    # Add cron jobs
    {
        crontab -l 2>/dev/null | grep -v "backup-enhanced.sh" || true
        echo "# GitHub Actions Runner Backup Schedule"
        echo "$cron_job"
        echo "$cron_cleanup"
    } | crontab -
    
    log_success "Backup schedule configured"
    log_info "Daily backup: 2:00 AM"
    log_info "Weekly cleanup: 3:00 AM (Sunday)"
    
    # Create backup configuration if not exists
    local backup_config="/etc/github-runner/backup.conf"
    if [[ ! -f "$backup_config" ]]; then
        cat > "$backup_config" << EOF
# GitHub Actions Runner Backup Configuration
BACKUP_ENABLED=true
BACKUP_LOCATION=$DESTINATION
BACKUP_RETENTION_DAYS=$RETENTION_DAYS
BACKUP_COMPRESSION_LEVEL=$COMPRESSION_LEVEL
BACKUP_INCLUDE_LOGS=$INCLUDE_LOGS
EOF
        
        chmod 640 "$backup_config"
        log_info "Backup configuration created: $backup_config"
    fi
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        cat << EOF
{
    "schedule_timestamp": "$(date -Iseconds)",
    "backup_time": "02:00",
    "cleanup_time": "03:00 (Sunday)",
    "retention_days": $RETENTION_DAYS,
    "destination": "$DESTINATION"
}
EOF
    fi
}

main() {
    local lock_file="/var/lock/github-runner-backup.lock"
    
    # Skip locking for list and verify commands
    if [[ ! "$COMMAND" =~ ^(list|verify)$ ]]; then
        if ! lock_script "$lock_file" 300; then
            log_error "Another backup operation is in progress"
            exit 1
        fi
        
        trap 'unlock_script "$lock_file"' EXIT
    fi
    
    load_configuration
    check_prerequisites
    
    case "$COMMAND" in
        create)
            create_backup
            ;;
        list)
            list_backups
            ;;
        restore)
            if [[ -z "${BACKUP_ID:-}" ]]; then
                log_error "Backup ID is required for restore command"
                exit 1
            fi
            restore_backup "$BACKUP_ID"
            ;;
        verify)
            if [[ -z "${BACKUP_ID:-}" ]]; then
                log_error "Backup ID is required for verify command"
                exit 1
            fi
            verify_backup "$BACKUP_ID"
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        schedule)
            setup_backup_schedule
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi