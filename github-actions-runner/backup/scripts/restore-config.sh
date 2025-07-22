#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$SCRIPT_DIR/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-restore-config.log"

usage() {
    cat << 'EOF'
Usage: restore-config.sh [OPTIONS] BACKUP_ID

Restore configuration files from GitHub Actions runner backup

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Backup source location [default: /var/backups/github-runner]
    -t, --target DIR        Target directory for restoration [default: /]
    --config-only           Restore only configuration files
    --env-only              Restore only environment files
    --secrets-only          Restore only credential files
    --exclude PATTERN       Exclude files matching pattern
    --backup-current        Create safety backup of current config
    --verify-syntax         Verify configuration syntax after restore
    --reload-services       Reload services after configuration restore
    --dry-run               Show what would be restored without making changes
    --force                 Force restoration even if files exist
    -v, --verbose           Verbose restoration output

Examples:
    ./restore-config.sh config-backup-20240115     # Restore all configuration
    ./restore-config.sh --config-only backup-123   # Restore only config files
    ./restore-config.sh --dry-run backup-123       # Preview restoration
    ./restore-config.sh --reload-services backup-123  # Restore and reload services
EOF
}

BACKUP_ID=""
SOURCE_DIR="/var/backups/github-runner"
TARGET_DIR="/"
CONFIG_ONLY=false
ENV_ONLY=false
SECRETS_ONLY=false
EXCLUDE_PATTERNS=()
BACKUP_CURRENT=false
VERIFY_SYNTAX=false
RELOAD_SERVICES=false
DRY_RUN=false
FORCE_RESTORE=false
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
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --env-only)
            ENV_ONLY=true
            shift
            ;;
        --secrets-only)
            SECRETS_ONLY=true
            shift
            ;;
        --exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        --backup-current)
            BACKUP_CURRENT=true
            shift
            ;;
        --verify-syntax)
            VERIFY_SYNTAX=true
            shift
            ;;
        --reload-services)
            RELOAD_SERVICES=true
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
    log_section "GitHub Actions Runner - Configuration Restoration"
    
    local restore_start_time=$(date +%s)
    local restore_id="config-restore-$(date +%Y%m%d_%H%M%S)"
    
    log_info "Starting configuration restoration: $restore_id"
    log_info "Backup ID: $BACKUP_ID"
    log_info "Source: $SOURCE_DIR"
    
    # Validate backup exists
    validate_config_backup_exists "$BACKUP_ID"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual restoration will be performed"
        preview_config_restoration "$BACKUP_ID"
        exit 0
    fi
    
    # Create safety backup if requested
    local safety_backup_dir=""
    if [[ "$BACKUP_CURRENT" == true ]]; then
        safety_backup_dir=$(create_config_safety_backup "$restore_id")
    fi
    
    # Perform restoration
    log_section "Performing Configuration Restoration"
    
    local restoration_success=true
    
    if ! restore_configuration_from_backup "$BACKUP_ID" "$restore_id"; then
        restoration_success=false
        log_error "Configuration restoration failed"
    fi
    
    # Post-restoration tasks
    if [[ "$restoration_success" == true ]]; then
        if [[ "$VERIFY_SYNTAX" == true ]]; then
            verify_restored_configuration
        fi
        
        if [[ "$RELOAD_SERVICES" == true ]]; then
            reload_affected_services
        fi
        
        local restore_end_time=$(date +%s)
        local restore_duration=$((restore_end_time - restore_start_time))
        
        log_section "Configuration Restoration Complete"
        log_success "Restoration ID: $restore_id"
        log_info "Duration: $restore_duration seconds"
        log_info "Source backup: $BACKUP_ID"
        
        send_restoration_notification "$restore_id" "success" "$restore_duration" "configuration"
    else
        log_section "Configuration Restoration Failed"
        log_error "Configuration restoration failed for backup: $BACKUP_ID"
        
        if [[ -n "$safety_backup_dir" ]]; then
            log_info "Safety backup available at: $safety_backup_dir"
        fi
        
        send_restoration_notification "$restore_id" "failed" "0" "configuration"
        exit 1
    fi
    
    return 0
}

validate_config_backup_exists() {
    local backup_id="$1"
    
    log_info "Validating configuration backup exists: $backup_id"
    
    # Try different backup manifest locations
    local manifest_files=(
        "$SOURCE_DIR/$backup_id.manifest.json"
        "$SOURCE_DIR/config/$backup_id.manifest.json"
    )
    
    local manifest_file=""
    for manifest in "${manifest_files[@]}"; do
        if [[ -f "$manifest" ]]; then
            manifest_file="$manifest"
            break
        fi
    done
    
    if [[ -z "$manifest_file" ]]; then
        log_error "Configuration backup manifest not found for: $backup_id"
        exit 1
    fi
    
    # Validate manifest structure
    if ! jq . "$manifest_file" >/dev/null 2>&1; then
        log_error "Invalid backup manifest format"
        exit 1
    fi
    
    log_success "Configuration backup validation completed"
}

create_config_safety_backup() {
    local restore_id="$1"
    
    log_info "Creating safety backup of current configuration..."
    
    local safety_backup_dir="/tmp/config-safety-backup-$restore_id"
    mkdir -p "$safety_backup_dir"
    
    # Backup current configuration files
    local config_items=(
        "/etc/github-runner"
        "/etc/systemd/system/github-runner.service"
        "/etc/systemd/system/actions-runner.service"
        "$PROJECT_ROOT/config"
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/docker-compose.yml"
    )
    
    for item in "${config_items[@]}"; do
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
    "safety_backup_id": "config-safety-backup-$restore_id",
    "created_for_restore": "$restore_id",
    "timestamp": $(date +%s),
    "iso_timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "created_by": "$(whoami)",
    "original_restoration_backup": "$BACKUP_ID",
    "backup_type": "configuration_safety"
}
EOF
    
    log_success "Configuration safety backup created: $safety_backup_dir"
    echo "$safety_backup_dir"
}

restore_configuration_from_backup() {
    local backup_id="$1"
    local restore_id="$2"
    
    log_info "Restoring configuration from backup: $backup_id"
    
    # Find backup archive
    local archive_file
    archive_file=$(find_config_backup_archive "$backup_id")
    
    if [[ -z "$archive_file" ]]; then
        log_error "Configuration backup archive not found"
        return 1
    fi
    
    local temp_extract_dir="/tmp/config-restore-$restore_id"
    mkdir -p "$temp_extract_dir"
    
    # Extract configuration backup
    if ! extract_config_backup "$archive_file" "$temp_extract_dir"; then
        log_error "Failed to extract configuration backup"
        rm -rf "$temp_extract_dir"
        return 1
    fi
    
    # Restore different configuration components
    restore_core_configuration "$temp_extract_dir"
    
    if [[ "$ENV_ONLY" != true && "$SECRETS_ONLY" != true ]]; then
        restore_service_configuration "$temp_extract_dir"
        restore_monitoring_configuration "$temp_extract_dir"
    fi
    
    if [[ "$CONFIG_ONLY" != true && "$SECRETS_ONLY" != true ]]; then
        restore_environment_configuration "$temp_extract_dir"
    fi
    
    if [[ "$CONFIG_ONLY" != true && "$ENV_ONLY" != true ]]; then
        restore_security_configuration "$temp_extract_dir"
    fi
    
    # Cleanup
    rm -rf "$temp_extract_dir"
    
    return 0
}

find_config_backup_archive() {
    local backup_id="$1"
    
    # Try different possible locations and formats
    local possible_archives=(
        "$SOURCE_DIR/$backup_id.tar.gz"
        "$SOURCE_DIR/$backup_id.tar"
        "$SOURCE_DIR/$backup_id.zip"
        "$SOURCE_DIR/$backup_id.tar.gz.gpg"
        "$SOURCE_DIR/config/$backup_id.tar.gz"
        "$SOURCE_DIR/config/$backup_id.tar"
        "$SOURCE_DIR/config/$backup_id.zip"
    )
    
    for archive in "${possible_archives[@]}"; do
        if [[ -f "$archive" ]]; then
            echo "$archive"
            return 0
        fi
    done
    
    return 1
}

extract_config_backup() {
    local archive_file="$1"
    local extract_dir="$2"
    
    log_info "Extracting configuration backup: $(basename "$archive_file")"
    
    case "${archive_file##*.}" in
        "gz"|"tgz")
            tar -xzf "$archive_file" -C "$extract_dir" 2>/dev/null
            ;;
        "tar")
            tar -xf "$archive_file" -C "$extract_dir" 2>/dev/null
            ;;
        "zip")
            unzip -q "$archive_file" -d "$extract_dir" 2>/dev/null
            ;;
        "gpg")
            gpg --decrypt "$archive_file" 2>/dev/null | tar -xz -C "$extract_dir" 2>/dev/null
            ;;
        *)
            log_error "Unsupported archive format: ${archive_file##*.}"
            return 1
            ;;
    esac
    
    return $?
}

restore_core_configuration() {
    local extract_dir="$1"
    
    log_info "Restoring core configuration files..."
    
    local core_dir="$extract_dir/core"
    
    if [[ ! -d "$core_dir" ]]; then
        log_warn "No core configuration directory found in backup"
        return 0
    fi
    
    # Restore core configuration files
    for config_file in "$core_dir"/*; do
        if [[ -f "$config_file" ]]; then
            local file_name=$(basename "$config_file")
            local target_path=""
            
            # Determine target path based on file name
            case "$file_name" in
                "runner-config.yml")
                    target_path="$PROJECT_ROOT/config/runner-config.yml"
                    ;;
                "integration-config.yml")
                    target_path="$PROJECT_ROOT/config/integration-config.yml"
                    ;;
                "network-config.yml")
                    target_path="$PROJECT_ROOT/config/network-config.yml"
                    ;;
                "fluent-bit.conf")
                    target_path="$PROJECT_ROOT/config/fluent-bit.conf"
                    ;;
                *)
                    # Skip unknown files
                    continue
                    ;;
            esac
            
            if should_restore_config_file "$target_path"; then
                restore_single_config_file "$config_file" "$target_path"
            fi
        fi
    done
    
    # Restore configuration directories
    for config_dir in "$core_dir"/*/; do
        if [[ -d "$config_dir" ]]; then
            local dir_name=$(basename "$config_dir")
            local target_path="$PROJECT_ROOT/config/$dir_name"
            
            if should_restore_config_file "$target_path"; then
                log_debug "Restoring config directory: $config_dir -> $target_path"
                
                mkdir -p "$(dirname "$target_path")"
                
                if [[ -d "$target_path" && "$FORCE_RESTORE" != true ]]; then
                    log_warn "Configuration directory exists, backing up: $target_path"
                    mv "$target_path" "$target_path.backup.$(date +%s)"
                fi
                
                cp -r "$config_dir" "$target_path"
                chmod -R 644 "$target_path"/* 2>/dev/null || true
            fi
        fi
    done
    
    log_success "Core configuration restored"
}

restore_service_configuration() {
    local extract_dir="$1"
    
    log_info "Restoring service configuration files..."
    
    local systemd_files=(
        "github-runner.service"
        "actions-runner.service"
        "github-runner.timer"
    )
    
    for service_file in "${systemd_files[@]}"; do
        local source_file="$extract_dir/systemd/$service_file"
        local target_path="/etc/systemd/system/$service_file"
        
        if [[ -f "$source_file" ]]; then
            if should_restore_config_file "$target_path"; then
                restore_single_config_file "$source_file" "$target_path"
            fi
        fi
    done
    
    log_success "Service configuration restored"
}

restore_environment_configuration() {
    local extract_dir="$1"
    
    log_info "Restoring environment configuration..."
    
    local env_dir="$extract_dir/environment"
    
    if [[ ! -d "$env_dir" ]]; then
        log_warn "No environment directory found in backup"
        return 0
    fi
    
    # Restore environment files
    for env_file in "$env_dir"/*; do
        if [[ -f "$env_file" ]]; then
            local file_name=$(basename "$env_file")
            local target_path=""
            
            # Determine original path from encoded filename
            case "$file_name" in
                *".env")
                    target_path="$PROJECT_ROOT/.env"
                    ;;
                *"runner.env")
                    target_path="/etc/github-runner/runner.env"
                    ;;
                *"development.env")
                    target_path="$PROJECT_ROOT/config/environments/development.env"
                    ;;
                *"production.env")
                    target_path="$PROJECT_ROOT/config/environments/production.env"
                    ;;
                *)
                    # Skip unknown environment files
                    continue
                    ;;
            esac
            
            if should_restore_config_file "$target_path"; then
                restore_single_config_file "$env_file" "$target_path"
                
                # Verify environment file syntax
                if [[ "$VERIFY_SYNTAX" == true ]]; then
                    verify_environment_file_syntax "$target_path"
                fi
            fi
        fi
    done
    
    log_success "Environment configuration restored"
}

restore_security_configuration() {
    local extract_dir="$1"
    
    log_info "Restoring security configuration..."
    
    local security_dir="$extract_dir/sensitive"
    
    if [[ ! -d "$security_dir" ]]; then
        log_warn "No security directory found in backup"
        return 0
    fi
    
    # Restore security files with proper permissions
    for security_file in "$security_dir"/*; do
        if [[ -f "$security_file" ]]; then
            local file_name=$(basename "$security_file")
            local target_path=""
            
            # Determine original path from encoded filename
            case "$file_name" in
                *".credentials")
                    target_path="/opt/github-runner/.credentials"
                    ;;
                *".runner")
                    target_path="/opt/github-runner/.runner"
                    ;;
                *"token")
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
            
            if should_restore_config_file "$target_path"; then
                restore_single_config_file "$security_file" "$target_path"
                
                # Set secure permissions for credential files
                chmod 600 "$target_path"
                chown root:root "$target_path" 2>/dev/null || true
                
                log_debug "Restored with secure permissions: $target_path"
            fi
        fi
    done
    
    log_success "Security configuration restored"
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
    for monitoring_file in "$monitoring_dir"/*; do
        if [[ -e "$monitoring_file" ]]; then
            local file_name=$(basename "$monitoring_file")
            local target_path="$PROJECT_ROOT/monitoring/$file_name"
            
            if should_restore_config_file "$target_path"; then
                mkdir -p "$(dirname "$target_path")"
                
                if [[ -d "$monitoring_file" ]]; then
                    cp -r "$monitoring_file" "$target_path"
                else
                    cp "$monitoring_file" "$target_path"
                fi
                
                chmod 644 "$target_path" 2>/dev/null || true
                log_debug "Restored monitoring config: $target_path"
            fi
        fi
    done
    
    log_success "Monitoring configuration restored"
}

restore_single_config_file() {
    local source_file="$1"
    local target_path="$2"
    
    log_debug "Restoring config file: $source_file -> $target_path"
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$target_path")"
    
    # Backup existing file if it exists and force is not enabled
    if [[ -f "$target_path" && "$FORCE_RESTORE" != true ]]; then
        local backup_name="$target_path.backup.$(date +%s)"
        cp "$target_path" "$backup_name"
        log_debug "Backed up existing file: $backup_name"
    fi
    
    # Copy the configuration file
    cp "$source_file" "$target_path"
    
    # Set appropriate permissions
    if [[ "$target_path" =~ \.(credentials|token)$ ]]; then
        chmod 600 "$target_path"
    else
        chmod 644 "$target_path"
    fi
}

should_restore_config_file() {
    local file_path="$1"
    
    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file_path" == $pattern ]]; then
            log_debug "Excluding file: $file_path (matches $pattern)"
            return 1
        fi
    done
    
    # Check if file exists and force is not enabled
    if [[ -f "$file_path" && "$FORCE_RESTORE" != true ]]; then
        log_debug "File exists, will backup: $file_path"
    fi
    
    return 0
}

verify_restored_configuration() {
    log_info "Verifying restored configuration syntax..."
    
    local verification_errors=0
    
    # Verify JSON configuration files
    local json_files=(
        "/opt/github-runner/.runner"
        "$PROJECT_ROOT/config/runner-config.yml"
    )
    
    for json_file in "${json_files[@]}"; do
        if [[ -f "$json_file" ]]; then
            if ! jq . "$json_file" >/dev/null 2>&1; then
                log_warn "Invalid JSON syntax: $json_file"
                ((verification_errors++))
            else
                log_debug "JSON syntax verified: $json_file"
            fi
        fi
    done
    
    # Verify YAML configuration files
    local yaml_files=(
        "$PROJECT_ROOT/docker-compose.yml"
        "$PROJECT_ROOT/config/integration-config.yml"
    )
    
    for yaml_file in "${yaml_files[@]}"; do
        if [[ -f "$yaml_file" ]]; then
            if command -v yamllint >/dev/null 2>&1; then
                if ! yamllint "$yaml_file" >/dev/null 2>&1; then
                    log_warn "YAML syntax issues: $yaml_file"
                    ((verification_errors++))
                else
                    log_debug "YAML syntax verified: $yaml_file"
                fi
            fi
        fi
    done
    
    # Verify systemd service files
    local service_files=(
        "/etc/systemd/system/github-runner.service"
        "/etc/systemd/system/actions-runner.service"
    )
    
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            if ! systemd-analyze verify "$service_file" >/dev/null 2>&1; then
                log_warn "Systemd service file issues: $service_file"
                ((verification_errors++))
            else
                log_debug "Systemd service verified: $service_file"
            fi
        fi
    done
    
    if [[ "$verification_errors" -eq 0 ]]; then
        log_success "Configuration syntax verification passed"
    else
        log_warn "Found $verification_errors configuration syntax issue(s)"
    fi
}

verify_environment_file_syntax() {
    local env_file="$1"
    
    log_debug "Verifying environment file syntax: $env_file"
    
    local syntax_errors=0
    local line_number=0
    
    while IFS= read -r line; do
        ((line_number++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Check for valid environment variable format
        if [[ ! "$line" =~ ^[A-Z_][A-Z0-9_]*=.* ]]; then
            log_warn "Invalid environment variable format at line $line_number: $line"
            ((syntax_errors++))
        fi
    done < "$env_file"
    
    if [[ "$syntax_errors" -eq 0 ]]; then
        log_debug "Environment file syntax verified: $env_file"
    else
        log_warn "Found $syntax_errors syntax error(s) in: $env_file"
    fi
}

reload_affected_services() {
    log_info "Reloading affected services..."
    
    # Reload systemd if service files were restored
    if [[ -f "/etc/systemd/system/github-runner.service" ]]; then
        systemctl daemon-reload
        log_info "Systemd configuration reloaded"
    fi
    
    # Restart services if they are running
    local services=("github-runner" "actions-runner")
    
    for service in "${services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_info "Restarting service: $service"
            systemctl restart "$service" || log_warn "Failed to restart $service"
        fi
    done
    
    log_success "Service reload completed"
}

preview_config_restoration() {
    local backup_id="$1"
    
    log_section "Configuration Restoration Preview"
    
    echo "Restoration details:"
    echo "===================="
    echo "Backup ID: $backup_id"
    echo "Source: $SOURCE_DIR"
    echo "Config Only: $CONFIG_ONLY"
    echo "Environment Only: $ENV_ONLY"
    echo "Secrets Only: $SECRETS_ONLY"
    echo "Backup Current: $BACKUP_CURRENT"
    echo "Verify Syntax: $VERIFY_SYNTAX"
    echo "Reload Services: $RELOAD_SERVICES"
    echo "Force Restore: $FORCE_RESTORE"
    echo
    
    # Show what would be restored
    local archive_file
    archive_file=$(find_config_backup_archive "$backup_id")
    
    if [[ -n "$archive_file" ]]; then
        echo "Archive to restore: $(basename "$archive_file")"
        echo
        
        echo "Configuration files that would be restored:"
        echo "==========================================="
        
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
    else
        echo "Configuration backup archive not found"
    fi
}

send_restoration_notification() {
    local restore_id="$1"
    local status="$2"
    local duration="$3"
    local type="$4"
    
    # Send notification if webhook URL is configured
    local webhook_url="${BACKUP_NOTIFICATION_URL:-}"
    
    if [[ -n "$webhook_url" ]]; then
        curl -X POST "$webhook_url" \
             -H "Content-Type: application/json" \
             -d "{
                 \"type\": \"${type}_restoration\",
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