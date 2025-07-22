#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$SCRIPT_DIR/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-restore-full.log"

usage() {
    cat << 'EOF'
Usage: restore-full.sh [OPTIONS] BACKUP_ID

Perform complete system restoration of GitHub Actions runner

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Backup source location [default: /var/backups/github-runner]
    -t, --target DIR        Target directory for restoration [default: /]
    --restore-path PATH     Specific path to restore to (instead of original location)
    --stop-services         Stop services before restoration
    --start-services        Start services after restoration
    --backup-current        Create safety backup of current state
    --verify-before         Verify backup before restoration
    --verify-after          Verify restoration after completion
    --exclude PATTERN       Exclude files matching pattern from restoration
    --include-only PATTERN  Restore only files matching pattern
    --preserve-permissions  Preserve original file permissions
    --dry-run               Show what would be restored without making changes
    --force                 Force restoration even if services are running
    --rollback-on-failure   Automatically rollback if restoration fails
    -v, --verbose           Verbose restoration output

Examples:
    ./restore-full.sh full-backup-20240115          # Basic full restoration
    ./restore-full.sh --dry-run full-backup-20240115 # Preview restoration
    ./restore-full.sh --stop-services --start-services full-backup-20240115 # With service management
    ./restore-full.sh --backup-current --verify-after full-backup-20240115  # Safe restoration
EOF
}

BACKUP_ID=""
SOURCE_DIR="/var/backups/github-runner"
TARGET_DIR="/"
RESTORE_PATH=""
STOP_SERVICES=false
START_SERVICES=false
BACKUP_CURRENT=false
VERIFY_BEFORE=false
VERIFY_AFTER=false
EXCLUDE_PATTERNS=()
INCLUDE_ONLY=""
PRESERVE_PERMISSIONS=false
DRY_RUN=false
FORCE_RESTORE=false
ROLLBACK_ON_FAILURE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--destination)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --restore-path)
            RESTORE_PATH="$2"
            shift 2
            ;;
        --stop-services)
            STOP_SERVICES=true
            shift
            ;;
        --start-services)
            START_SERVICES=true
            shift
            ;;
        --backup-current)
            BACKUP_CURRENT=true
            shift
            ;;
        --verify-before)
            VERIFY_BEFORE=true
            shift
            ;;
        --verify-after)
            VERIFY_AFTER=true
            shift
            ;;
        --exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        --include-only)
            INCLUDE_ONLY="$2"
            shift 2
            ;;
        --preserve-permissions)
            PRESERVE_PERMISSIONS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE_RESTORE=true
            shift
            ;;
        --rollback-on-failure)
            ROLLBACK_ON_FAILURE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            BACKUP_ID="$1"
            shift
            ;;
    esac
done

if [[ -z "$BACKUP_ID" ]]; then
    log_error "Backup ID is required"
    usage
    exit 1
fi

main() {
    log_section "GitHub Actions Runner - Full System Restoration"
    
    local restore_start_time=$(date +%s)
    local restore_id="restore-$(date +%Y%m%d_%H%M%S)"
    local safety_backup_dir=""
    local restoration_failed=false
    
    log_info "Starting full restoration: $restore_id"
    log_info "Backup ID: $BACKUP_ID"
    log_info "Source: $SOURCE_DIR"
    log_info "Target: $TARGET_DIR"
    
    # Pre-restoration checks
    validate_restoration_environment
    validate_backup_exists "$BACKUP_ID"
    
    if [[ "$VERIFY_BEFORE" == true ]]; then
        verify_backup_before_restore "$BACKUP_ID"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual restoration will be performed"
        preview_restoration "$BACKUP_ID"
        exit 0
    fi
    
    # Pre-restoration safety measures
    if [[ "$BACKUP_CURRENT" == true ]]; then
        safety_backup_dir=$(create_safety_backup "$restore_id")
    fi
    
    if [[ "$STOP_SERVICES" == true ]]; then
        stop_related_services
    fi
    
    # Perform restoration
    log_section "Performing Restoration"
    
    if ! restore_from_backup "$BACKUP_ID" "$restore_id"; then
        restoration_failed=true
        log_error "Restoration failed"
        
        if [[ "$ROLLBACK_ON_FAILURE" == true && -n "$safety_backup_dir" ]]; then
            log_info "Attempting automatic rollback..."
            rollback_from_safety_backup "$safety_backup_dir"
        fi
    fi
    
    # Post-restoration tasks
    if [[ "$restoration_failed" != true ]]; then
        configure_restored_system
        
        if [[ "$PRESERVE_PERMISSIONS" == true ]]; then
            restore_file_permissions
        fi
        
        if [[ "$START_SERVICES" == true ]]; then
            start_related_services
        fi
        
        if [[ "$VERIFY_AFTER" == true ]]; then
            verify_restoration_success "$restore_id"
        fi
        
        cleanup_restoration_artifacts "$restore_id"
        
        local restore_end_time=$(date +%s)
        local restore_duration=$((restore_end_time - restore_start_time))
        
        log_section "Full Restoration Complete"
        log_success "Restoration ID: $restore_id"
        log_info "Duration: $restore_duration seconds"
        log_info "Source backup: $BACKUP_ID"
        
        send_restoration_notification "$restore_id" "success" "$restore_duration"
    else
        log_section "Restoration Failed"
        log_error "Full restoration failed for backup: $BACKUP_ID"
        
        send_restoration_notification "$restore_id" "failed" "0"
        exit 1
    fi
    
    return 0
}

validate_restoration_environment() {
    log_info "Validating restoration environment..."
    
    # Check if running as root (required for system restoration)
    if [[ $EUID -ne 0 && "$TARGET_DIR" == "/" ]]; then
        log_error "Root privileges required for system restoration"
        exit 1
    fi
    
    # Check available disk space
    local available_space_gb
    available_space_gb=$(df -BG "$TARGET_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ "$available_space_gb" -lt 5 ]]; then
        log_error "Insufficient disk space for restoration (available: ${available_space_gb}GB, required: 5GB)"
        exit 1
    fi
    
    # Check if services are running (unless forced)
    if [[ "$FORCE_RESTORE" != true && "$STOP_SERVICES" != true ]]; then
        check_running_services
    fi
    
    # Verify target directory
    if [[ ! -d "$TARGET_DIR" ]]; then
        log_error "Target directory does not exist: $TARGET_DIR"
        exit 1
    fi
    
    log_success "Restoration environment validated"
}

validate_backup_exists() {
    local backup_id="$1"
    
    log_info "Validating backup exists: $backup_id"
    
    local manifest_file="$SOURCE_DIR/$backup_id.manifest.json"
    
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Backup manifest not found: $manifest_file"
        exit 1
    fi
    
    # Validate manifest structure
    if ! jq . "$manifest_file" >/dev/null 2>&1; then
        log_error "Invalid backup manifest format"
        exit 1
    fi
    
    # Check backup type
    local backup_type
    backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file")
    
    if [[ "$backup_type" != "full" ]]; then
        log_warn "Backup type is not 'full' (found: $backup_type)"
        log_warn "This may not restore the complete system"
    fi
    
    # Find and validate archive file
    local archive_file
    archive_file=$(find_backup_archive "$backup_id")
    
    if [[ -z "$archive_file" ]]; then
        log_error "Backup archive not found for: $backup_id"
        exit 1
    fi
    
    log_success "Backup validation completed"
}

find_backup_archive() {
    local backup_id="$1"
    
    local base_path="$SOURCE_DIR/$backup_id"
    
    for ext in ".tar.gz" ".tar" ".zip" ".gpg"; do
        if [[ -f "$base_path$ext" ]]; then
            echo "$base_path$ext"
            return 0
        fi
    done
    
    return 1
}

verify_backup_before_restore() {
    local backup_id="$1"
    
    log_info "Verifying backup integrity before restoration..."
    
    if ! "$SCRIPT_DIR/backup-validate.sh" --destination "$SOURCE_DIR" --deep --checksum "$backup_id"; then
        log_error "Backup verification failed"
        exit 1
    fi
    
    log_success "Backup verification passed"
}

check_running_services() {
    log_info "Checking for running services..."
    
    local running_services=()
    local services_to_check=(
        "github-runner"
        "actions-runner"
        "docker"
    )
    
    for service in "${services_to_check[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            running_services+=("$service")
        fi
    done
    
    if [[ ${#running_services[@]} -gt 0 ]]; then
        log_warn "The following services are running:"
        for service in "${running_services[@]}"; do
            log_warn "  - $service"
        done
        log_warn "Consider stopping services before restoration or use --stop-services"
        
        if [[ "$FORCE_RESTORE" != true ]]; then
            log_error "Use --force to proceed with running services"
            exit 1
        fi
    fi
}

create_safety_backup() {
    local restore_id="$1"
    
    log_info "Creating safety backup of current state..."
    
    local safety_backup_dir="/tmp/safety-backup-$restore_id"
    mkdir -p "$safety_backup_dir"
    
    # Backup critical directories and files
    local items_to_backup=(
        "/opt/github-runner"
        "/opt/actions-runner"
        "/etc/github-runner"
        "/etc/systemd/system/github-runner.service"
        "/etc/systemd/system/actions-runner.service"
    )
    
    for item in "${items_to_backup[@]}"; do
        if [[ -e "$item" ]]; then
            local dest_name=$(echo "$item" | sed 's|/|-|g' | sed 's|^-||')
            
            if [[ -d "$item" ]]; then
                cp -r "$item" "$safety_backup_dir/$dest_name" 2>/dev/null || true
            else
                cp "$item" "$safety_backup_dir/$dest_name" 2>/dev/null || true
            fi
            
            log_debug "Safety backup: $item -> $safety_backup_dir/$dest_name"
        fi
    done
    
    # Create safety backup manifest
    cat > "$safety_backup_dir/safety-manifest.json" << EOF
{
    "safety_backup_id": "safety-backup-$restore_id",
    "created_for_restore": "$restore_id",
    "timestamp": $(date +%s),
    "iso_timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "created_by": "$(whoami)",
    "original_restoration_backup": "$BACKUP_ID"
}
EOF
    
    log_success "Safety backup created: $safety_backup_dir"
    echo "$safety_backup_dir"
}

stop_related_services() {
    log_info "Stopping related services..."
    
    local services_to_stop=(
        "github-runner"
        "actions-runner"
    )
    
    for service in "${services_to_stop[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_info "Stopping service: $service"
            systemctl stop "$service" || log_warn "Failed to stop $service"
        fi
    done
    
    # Wait for services to fully stop
    sleep 3
    
    log_success "Services stopped"
}

restore_from_backup() {
    local backup_id="$1"
    local restore_id="$2"
    
    log_info "Restoring from backup: $backup_id"
    
    local archive_file
    archive_file=$(find_backup_archive "$backup_id")
    
    local manifest_file="$SOURCE_DIR/$backup_id.manifest.json"
    local is_encrypted
    is_encrypted=$(jq -r '.encrypted // false' "$manifest_file" 2>/dev/null)
    
    local temp_extract_dir="/tmp/restore-$restore_id"
    mkdir -p "$temp_extract_dir"
    
    # Extract backup archive
    log_info "Extracting backup archive..."
    
    local extraction_success=false
    
    case "${archive_file##*.}" in
        "gz"|"tgz")
            if tar -xzf "$archive_file" -C "$temp_extract_dir" 2>/dev/null; then
                extraction_success=true
            fi
            ;;
        "tar")
            if tar -xf "$archive_file" -C "$temp_extract_dir" 2>/dev/null; then
                extraction_success=true
            fi
            ;;
        "zip")
            if unzip -q "$archive_file" -d "$temp_extract_dir" 2>/dev/null; then
                extraction_success=true
            fi
            ;;
        "gpg")
            if [[ "$is_encrypted" == "true" ]]; then
                if gpg --decrypt "$archive_file" 2>/dev/null | tar -xz -C "$temp_extract_dir" 2>/dev/null; then
                    extraction_success=true
                fi
            else
                log_error "Backup is not marked as encrypted but has .gpg extension"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported archive format: ${archive_file##*.}"
            return 1
            ;;
    esac
    
    if [[ "$extraction_success" != true ]]; then
        log_error "Failed to extract backup archive"
        rm -rf "$temp_extract_dir"
        return 1
    fi
    
    log_success "Backup extracted successfully"
    
    # Restore extracted content
    restore_extracted_content "$temp_extract_dir" "$restore_id"
    local restore_result=$?
    
    # Cleanup
    rm -rf "$temp_extract_dir"
    
    return $restore_result
}

restore_extracted_content() {
    local extract_dir="$1"
    local restore_id="$2"
    
    log_info "Restoring extracted content..."
    
    # Restore different components
    restore_runner_installation "$extract_dir"
    restore_configuration_files "$extract_dir"
    restore_persistent_data "$extract_dir"
    restore_security_credentials "$extract_dir"
    restore_monitoring_configuration "$extract_dir"
    
    return 0
}

restore_runner_installation() {
    local extract_dir="$1"
    
    log_info "Restoring runner installation..."
    
    local installation_dir="$extract_dir/installation"
    
    if [[ ! -d "$installation_dir" ]]; then
        log_warn "No installation directory found in backup"
        return 0
    fi
    
    # Restore to appropriate installation paths
    local install_targets=(
        "/opt/github-runner"
        "/opt/actions-runner"
    )
    
    for source_item in "$installation_dir"/*; do
        if [[ -d "$source_item" ]]; then
            local item_name=$(basename "$source_item")
            
            # Determine target path
            local target_path=""
            case "$item_name" in
                "github-runner"|"actions-runner")
                    target_path="/opt/$item_name"
                    ;;
                "runner")
                    # Generic runner - try to determine correct path
                    if [[ -d "/opt/github-runner" ]]; then
                        target_path="/opt/github-runner"
                    else
                        target_path="/opt/actions-runner"
                    fi
                    ;;
                *)
                    # Use first available target
                    target_path="/opt/$item_name"
                    ;;
            esac
            
            if should_restore_path "$target_path"; then
                log_info "Restoring installation: $source_item -> $target_path"
                
                # Create parent directory if needed
                mkdir -p "$(dirname "$target_path")"
                
                # Remove existing installation
                if [[ -d "$target_path" ]]; then
                    rm -rf "$target_path"
                fi
                
                # Copy restored installation
                cp -r "$source_item" "$target_path"
                
                # Set appropriate ownership
                chown -R runner:runner "$target_path" 2>/dev/null || true
                
                # Make scripts executable
                find "$target_path" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
            fi
        fi
    done
    
    log_success "Runner installation restored"
}

restore_configuration_files() {
    local extract_dir="$1"
    
    log_info "Restoring configuration files..."
    
    local config_dir="$extract_dir/configuration"
    
    if [[ ! -d "$config_dir" ]]; then
        log_warn "No configuration directory found in backup"
        return 0
    fi
    
    # Restore configuration files
    for config_file in "$config_dir"/*; do
        if [[ -f "$config_file" ]]; then
            local file_name=$(basename "$config_file")
            local target_path=""
            
            # Determine original path from encoded filename
            case "$file_name" in
                *"etc-github-runner"*)
                    target_path="/etc/github-runner/$(echo "$file_name" | sed 's/.*etc-github-runner-//')"
                    ;;
                *"etc-systemd-system"*)
                    target_path="/etc/systemd/system/$(echo "$file_name" | sed 's/.*etc-systemd-system-//')"
                    ;;
                *"docker-compose.yml")
                    target_path="$PROJECT_ROOT/docker-compose.yml"
                    ;;
                *".env")
                    target_path="$PROJECT_ROOT/.env"
                    ;;
                *)
                    # Skip unknown configuration files
                    continue
                    ;;
            esac
            
            if should_restore_path "$target_path"; then
                log_debug "Restoring config: $config_file -> $target_path"
                
                # Create parent directory if needed
                mkdir -p "$(dirname "$target_path")"
                
                # Copy configuration file
                cp "$config_file" "$target_path"
                
                # Set appropriate permissions
                if [[ "$target_path" =~ \.(credentials|token)$ ]]; then
                    chmod 600 "$target_path"
                else
                    chmod 644 "$target_path"
                fi
            fi
        fi
    done
    
    log_success "Configuration files restored"
}

restore_persistent_data() {
    local extract_dir="$1"
    
    log_info "Restoring persistent data..."
    
    local data_dir="$extract_dir/data"
    
    if [[ ! -d "$data_dir" ]]; then
        log_warn "No data directory found in backup"
        return 0
    fi
    
    # Restore data directories
    for data_item in "$data_dir"/*; do
        if [[ -d "$data_item" ]]; then
            local item_name=$(basename "$data_item")
            local target_path=""
            
            case "$item_name" in
                "_work")
                    target_path="/opt/github-runner/_work"
                    ;;
                "data")
                    target_path="$PROJECT_ROOT/data"
                    ;;
                *)
                    target_path="/var/lib/github-runner/$item_name"
                    ;;
            esac
            
            if should_restore_path "$target_path"; then
                log_debug "Restoring data: $data_item -> $target_path"
                
                # Create parent directory if needed
                mkdir -p "$(dirname "$target_path")"
                
                # Copy data directory
                cp -r "$data_item" "$target_path"
                
                # Set appropriate ownership
                chown -R runner:runner "$target_path" 2>/dev/null || true
            fi
        fi
    done
    
    log_success "Persistent data restored"
}

restore_security_credentials() {
    local extract_dir="$1"
    
    log_info "Restoring security credentials..."
    
    local security_dir="$extract_dir/security"
    
    if [[ ! -d "$security_dir" ]]; then
        log_warn "No security directory found in backup"
        return 0
    fi
    
    # Restore security files
    for security_file in "$security_dir"/*; do
        if [[ -f "$security_file" ]]; then
            local file_name=$(basename "$security_file")
            local target_path=""
            
            # Determine original path from encoded filename
            case "$file_name" in
                *"opt-github-runner-.credentials")
                    target_path="/opt/github-runner/.credentials"
                    ;;
                *"opt-github-runner-.runner")
                    target_path="/opt/github-runner/.runner"
                    ;;
                *"etc-github-runner-token")
                    target_path="/etc/github-runner/token"
                    ;;
                *".github_token")
                    target_path="$HOME/.github_token"
                    ;;
                *)
                    # Skip unknown security files
                    continue
                    ;;
            esac
            
            if should_restore_path "$target_path"; then
                log_debug "Restoring security: $security_file -> $target_path"
                
                # Create parent directory if needed
                mkdir -p "$(dirname "$target_path")"
                
                # Copy security file
                cp "$security_file" "$target_path"
                
                # Set secure permissions
                chmod 600 "$target_path"
                chown root:root "$target_path" 2>/dev/null || true
            fi
        fi
    done
    
    log_success "Security credentials restored"
}

restore_monitoring_configuration() {
    local extract_dir="$1"
    
    log_info "Restoring monitoring configuration..."
    
    local monitoring_dir="$extract_dir/monitoring"
    
    if [[ ! -d "$monitoring_dir" ]]; then
        log_warn "No monitoring directory found in backup"
        return 0
    fi
    
    # Restore monitoring files
    for monitoring_item in "$monitoring_dir"/*; do
        if [[ -e "$monitoring_item" ]]; then
            local item_name=$(basename "$monitoring_item")
            local target_path="$PROJECT_ROOT/monitoring/$item_name"
            
            if should_restore_path "$target_path"; then
                log_debug "Restoring monitoring: $monitoring_item -> $target_path"
                
                # Create parent directory if needed
                mkdir -p "$(dirname "$target_path")"
                
                # Copy monitoring item
                if [[ -d "$monitoring_item" ]]; then
                    cp -r "$monitoring_item" "$target_path"
                else
                    cp "$monitoring_item" "$target_path"
                fi
                
                chmod 644 "$target_path" 2>/dev/null || true
            fi
        fi
    done
    
    log_success "Monitoring configuration restored"
}

should_restore_path() {
    local path="$1"
    
    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$path" == $pattern ]]; then
            log_debug "Excluding path: $path (matches $pattern)"
            return 1
        fi
    done
    
    # Check include-only pattern
    if [[ -n "$INCLUDE_ONLY" ]]; then
        if [[ ! "$path" == $INCLUDE_ONLY ]]; then
            log_debug "Skipping path: $path (doesn't match include pattern)"
            return 1
        fi
    fi
    
    # Check custom restore path
    if [[ -n "$RESTORE_PATH" ]]; then
        # Modify path to use custom restore location
        # This is a simplified implementation
        return 0
    fi
    
    return 0
}

configure_restored_system() {
    log_info "Configuring restored system..."
    
    # Reload systemd if service files were restored
    if [[ -f "/etc/systemd/system/github-runner.service" ]]; then
        systemctl daemon-reload
        log_info "Systemd configuration reloaded"
    fi
    
    # Update file ownership for runner directories
    local runner_dirs=(
        "/opt/github-runner"
        "/opt/actions-runner"
        "/var/lib/github-runner"
    )
    
    for runner_dir in "${runner_dirs[@]}"; do
        if [[ -d "$runner_dir" ]]; then
            chown -R runner:runner "$runner_dir" 2>/dev/null || true
        fi
    done
    
    # Update permissions for executable files
    find /opt/github-runner /opt/actions-runner -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    log_success "System configuration updated"
}

restore_file_permissions() {
    log_info "Restoring file permissions..."
    
    # Set standard permissions for common file types
    
    # Configuration files
    find /etc/github-runner -type f -name "*.conf" -exec chmod 644 {} \; 2>/dev/null || true
    find /etc/github-runner -type f -name "*.yml" -exec chmod 644 {} \; 2>/dev/null || true
    
    # Credential files
    find /opt/github-runner /opt/actions-runner -name ".credentials" -exec chmod 600 {} \; 2>/dev/null || true
    find /opt/github-runner /opt/actions-runner -name ".runner" -exec chmod 600 {} \; 2>/dev/null || true
    
    # Executable files
    find /opt/github-runner /opt/actions-runner -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find /opt/github-runner /opt/actions-runner -name "run.sh" -exec chmod +x {} \; 2>/dev/null || true
    find /opt/github-runner /opt/actions-runner -name "config.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    # Directory permissions
    find /opt/github-runner /opt/actions-runner -type d -exec chmod 755 {} \; 2>/dev/null || true
    
    log_success "File permissions restored"
}

start_related_services() {
    log_info "Starting related services..."
    
    local services_to_start=(
        "github-runner"
        "actions-runner"
    )
    
    for service in "${services_to_start[@]}"; do
        if [[ -f "/etc/systemd/system/$service.service" ]]; then
            log_info "Starting service: $service"
            systemctl start "$service" || log_warn "Failed to start $service"
            
            # Wait and check service status
            sleep 2
            if systemctl is-active "$service" >/dev/null 2>&1; then
                log_success "Service started successfully: $service"
            else
                log_warn "Service may have failed to start: $service"
            fi
        fi
    done
}

verify_restoration_success() {
    local restore_id="$1"
    
    log_info "Verifying restoration success..."
    
    local verification_errors=0
    
    # Check if critical files exist
    local critical_files=(
        "/opt/github-runner/.runner"
        "/opt/github-runner/run.sh"
        "/etc/systemd/system/github-runner.service"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_warn "Critical file missing after restoration: $file"
            ((verification_errors++))
        fi
    done
    
    # Check service status
    if systemctl is-enabled github-runner >/dev/null 2>&1; then
        log_debug "GitHub runner service is enabled"
    else
        log_warn "GitHub runner service is not enabled"
        ((verification_errors++))
    fi
    
    # Check runner configuration
    if [[ -f "/opt/github-runner/.runner" ]]; then
        if jq . "/opt/github-runner/.runner" >/dev/null 2>&1; then
            log_debug "Runner configuration is valid JSON"
        else
            log_warn "Runner configuration is not valid JSON"
            ((verification_errors++))
        fi
    fi
    
    if [[ "$verification_errors" -eq 0 ]]; then
        log_success "Restoration verification passed"
        return 0
    else
        log_warn "Restoration verification found $verification_errors issue(s)"
        return 1
    fi
}

rollback_from_safety_backup() {
    local safety_backup_dir="$1"
    
    log_info "Rolling back from safety backup: $safety_backup_dir"
    
    if [[ ! -d "$safety_backup_dir" ]]; then
        log_error "Safety backup directory not found: $safety_backup_dir"
        return 1
    fi
    
    # Restore from safety backup
    for backup_item in "$safety_backup_dir"/*; do
        if [[ -e "$backup_item" && "$(basename "$backup_item")" != "safety-manifest.json" ]]; then
            local item_name=$(basename "$backup_item")
            local target_path=$(echo "$item_name" | sed 's|-|/|g' | sed 's|^|/|')
            
            log_info "Rolling back: $backup_item -> $target_path"
            
            # Remove current (failed) version
            if [[ -e "$target_path" ]]; then
                rm -rf "$target_path"
            fi
            
            # Restore from safety backup
            if [[ -d "$backup_item" ]]; then
                cp -r "$backup_item" "$target_path"
            else
                cp "$backup_item" "$target_path"
            fi
        fi
    done
    
    log_success "Rollback completed"
}

cleanup_restoration_artifacts() {
    local restore_id="$1"
    
    log_info "Cleaning up restoration artifacts..."
    
    # Remove temporary files
    rm -rf "/tmp/restore-$restore_id"* 2>/dev/null || true
    rm -rf "/tmp/safety-backup-$restore_id"* 2>/dev/null || true
    
    log_success "Cleanup completed"
}

preview_restoration() {
    local backup_id="$1"
    
    log_section "Full Restoration Preview"
    
    echo "Restoration details:"
    echo "===================="
    echo "Backup ID: $backup_id"
    echo "Source: $SOURCE_DIR"
    echo "Target: $TARGET_DIR"
    echo "Stop Services: $STOP_SERVICES"
    echo "Start Services: $START_SERVICES"
    echo "Create Safety Backup: $BACKUP_CURRENT"
    echo "Verify Before: $VERIFY_BEFORE"
    echo "Verify After: $VERIFY_AFTER"
    echo "Preserve Permissions: $PRESERVE_PERMISSIONS"
    echo "Rollback on Failure: $ROLLBACK_ON_FAILURE"
    echo
    
    # Show what would be restored
    local archive_file
    archive_file=$(find_backup_archive "$backup_id")
    
    echo "Archive to restore: $(basename "$archive_file")"
    echo
    
    echo "Components that would be restored:"
    echo "=================================="
    
    # Preview archive contents
    case "${archive_file##*.}" in
        "gz"|"tgz")
            tar -tzf "$archive_file" | head -20
            ;;
        "tar")
            tar -tf "$archive_file" | head -20
            ;;
        "zip")
            unzip -l "$archive_file" | head -20
            ;;
        "gpg")
            echo "Encrypted archive - cannot preview contents without decryption"
            ;;
    esac
    
    echo
    echo "... (showing first 20 files)"
}

send_restoration_notification() {
    local restore_id="$1"
    local status="$2"
    local duration="$3"
    
    # Send notification if webhook URL is configured
    local webhook_url="${BACKUP_NOTIFICATION_URL:-}"
    
    if [[ -n "$webhook_url" ]]; then
        curl -X POST "$webhook_url" \
             -H "Content-Type: application/json" \
             -d "{
                 \"type\": \"full_restoration\",
                 \"status\": \"$status\",
                 \"restore_id\": \"$restore_id\",
                 \"backup_id\": \"$BACKUP_ID\",
                 \"duration_seconds\": $duration,
                 \"hostname\": \"$(hostname)\",
                 \"timestamp\": \"$(date -Iseconds)\"
             }" \
             2>/dev/null || true
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi