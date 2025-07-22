#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$SCRIPT_DIR/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-backup-full.log"

usage() {
    cat << 'EOF'
Usage: backup-full.sh [OPTIONS]

Perform a complete system backup of GitHub Actions runner

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Backup destination [default: /var/backups/github-runner]
    -c, --config FILE       Backup configuration file
    -e, --encrypt           Encrypt backup files
    -r, --remote            Include remote storage backup
    -v, --verify            Verify backup after creation
    --exclude PATTERN       Exclude files matching pattern
    --retention DAYS        Retention period in days [default: 30]
    --compression LEVEL     Compression level 0-9 [default: 6]
    --include-docker        Include Docker containers/images
    --include-logs          Include all log files
    --include-metrics       Include metrics and monitoring data
    --parallel              Use parallel processing for large datasets
    --dry-run               Show what would be backed up without creating backup
    --force                 Force backup even if runner is active

Examples:
    ./backup-full.sh                                    # Standard full backup
    ./backup-full.sh --encrypt --remote                # Encrypted backup with remote storage
    ./backup-full.sh --dry-run                         # Preview backup contents
    ./backup-full.sh --include-docker --parallel       # Full backup with Docker data
EOF
}

DESTINATION="/var/backups/github-runner"
CONFIG_FILE="$BACKUP_ROOT/config/backup.conf"
ENCRYPT=false
REMOTE_BACKUP=false
VERIFY_BACKUP=false
EXCLUDE_PATTERNS=()
RETENTION_DAYS=30
COMPRESSION_LEVEL=6
INCLUDE_DOCKER=false
INCLUDE_LOGS=false
INCLUDE_METRICS=false
PARALLEL_MODE=false
DRY_RUN=false
FORCE_BACKUP=false

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
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -e|--encrypt)
            ENCRYPT=true
            shift
            ;;
        -r|--remote)
            REMOTE_BACKUP=true
            shift
            ;;
        -v|--verify)
            VERIFY_BACKUP=true
            shift
            ;;
        --exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --compression)
            COMPRESSION_LEVEL="$2"
            shift 2
            ;;
        --include-docker)
            INCLUDE_DOCKER=true
            shift
            ;;
        --include-logs)
            INCLUDE_LOGS=true
            shift
            ;;
        --include-metrics)
            INCLUDE_METRICS=true
            shift
            ;;
        --parallel)
            PARALLEL_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE_BACKUP=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

main() {
    log_section "GitHub Actions Runner - Full System Backup"
    
    load_backup_config "$CONFIG_FILE"
    validate_backup_environment
    
    if [[ "$FORCE_BACKUP" != true ]]; then
        check_runner_status
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_id="full-backup-$timestamp"
    
    log_info "Starting full backup: $backup_id"
    log_info "Destination: $DESTINATION"
    log_info "Configuration: $CONFIG_FILE"
    
    create_backup_directory "$DESTINATION"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual backup will be created"
        preview_backup_contents "$backup_id"
        exit 0
    fi
    
    local backup_manifest="$DESTINATION/$backup_id.manifest.json"
    
    init_backup_manifest "$backup_manifest" "$backup_id" "full"
    
    backup_runner_installation "$backup_id"
    backup_configuration_files "$backup_id"
    backup_persistent_data "$backup_id"
    backup_security_credentials "$backup_id"
    
    if [[ "$INCLUDE_LOGS" == true ]]; then
        backup_log_files "$backup_id"
    fi
    
    if [[ "$INCLUDE_METRICS" == true ]]; then
        backup_metrics_data "$backup_id"
    fi
    
    if [[ "$INCLUDE_DOCKER" == true ]]; then
        backup_docker_resources "$backup_id"
    fi
    
    backup_system_state "$backup_id"
    
    create_backup_archive "$backup_id" "$COMPRESSION_LEVEL"
    
    if [[ "$ENCRYPT" == true ]]; then
        encrypt_backup_archive "$backup_id"
    fi
    
    finalize_backup_manifest "$backup_manifest" "$backup_id"
    
    if [[ "$VERIFY_BACKUP" == true ]]; then
        verify_backup_integrity "$backup_id"
    fi
    
    if [[ "$REMOTE_BACKUP" == true ]]; then
        sync_to_remote_storage "$backup_id"
    fi
    
    cleanup_old_backups "$RETENTION_DAYS"
    
    log_section "Full Backup Complete"
    log_success "Backup ID: $backup_id"
    log_info "Location: $DESTINATION/$backup_id"
    
    send_backup_notification "full" "$backup_id" "success"
    
    return 0
}

backup_runner_installation() {
    local backup_id="$1"
    
    log_info "Backing up runner installation..."
    
    local install_paths=(
        "/opt/github-runner"
        "/opt/actions-runner"
        "/home/runner"
        "/usr/local/bin/github-runner"
    )
    
    local temp_dir="/tmp/$backup_id/installation"
    mkdir -p "$temp_dir"
    
    for install_path in "${install_paths[@]}"; do
        if [[ -d "$install_path" ]]; then
            log_debug "Found installation at: $install_path"
            
            local dest_path="$temp_dir/$(basename "$install_path")"
            
            if [[ "$PARALLEL_MODE" == true ]]; then
                rsync -av --exclude='_work/_temp' --exclude='*.pid' \
                      "$install_path/" "$dest_path/" &
            else
                rsync -av --exclude='_work/_temp' --exclude='*.pid' \
                      "$install_path/" "$dest_path/"
            fi
            
            update_backup_manifest "$backup_manifest" "installation" "$install_path" "$(du -sh "$dest_path" | cut -f1)"
        fi
    done
    
    if [[ "$PARALLEL_MODE" == true ]]; then
        wait
    fi
    
    log_success "Runner installation backed up"
}

backup_configuration_files() {
    local backup_id="$1"
    
    log_info "Backing up configuration files..."
    
    local config_paths=(
        "/etc/github-runner"
        "/etc/systemd/system/github-runner.service"
        "/etc/systemd/system/actions-runner.service"
        "$PROJECT_ROOT/config"
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/docker-compose.yml"
        "/etc/default/github-runner"
    )
    
    local temp_dir="/tmp/$backup_id/configuration"
    mkdir -p "$temp_dir"
    
    for config_path in "${config_paths[@]}"; do
        if [[ -e "$config_path" ]]; then
            log_debug "Backing up config: $config_path"
            
            local dest_name=$(echo "$config_path" | sed 's|/|-|g' | sed 's|^-||')
            
            if [[ -d "$config_path" ]]; then
                cp -r "$config_path" "$temp_dir/$dest_name"
            else
                cp "$config_path" "$temp_dir/$dest_name"
            fi
            
            update_backup_manifest "$backup_manifest" "configuration" "$config_path" "$(du -sh "$temp_dir/$dest_name" | cut -f1)"
        fi
    done
    
    backup_environment_variables "$temp_dir"
    
    log_success "Configuration files backed up"
}

backup_persistent_data() {
    local backup_id="$1"
    
    log_info "Backing up persistent data..."
    
    local data_paths=(
        "$PROJECT_ROOT/data"
        "/var/lib/github-runner"
        "/opt/github-runner/_work"
        "/opt/actions-runner/_work"
    )
    
    local temp_dir="/tmp/$backup_id/data"
    mkdir -p "$temp_dir"
    
    for data_path in "${data_paths[@]}"; do
        if [[ -d "$data_path" ]]; then
            log_debug "Backing up data: $data_path"
            
            local dest_name=$(basename "$data_path")
            
            rsync -av --exclude='_temp' --exclude='*.tmp' \
                  "$data_path/" "$temp_dir/$dest_name/"
            
            update_backup_manifest "$backup_manifest" "persistent_data" "$data_path" "$(du -sh "$temp_dir/$dest_name" | cut -f1)"
        fi
    done
    
    backup_database_state "$temp_dir"
    
    log_success "Persistent data backed up"
}

backup_security_credentials() {
    local backup_id="$1"
    
    log_info "Backing up security credentials..."
    
    local temp_dir="/tmp/$backup_id/security"
    mkdir -p "$temp_dir"
    
    local credential_paths=(
        "/etc/github-runner/token"
        "/etc/github-runner/credentials"
        "$PROJECT_ROOT/security/certs"
        "$HOME/.github_token"
        "/opt/github-runner/.credentials"
        "/opt/github-runner/.runner"
    )
    
    for cred_path in "${credential_paths[@]}"; do
        if [[ -e "$cred_path" ]]; then
            log_debug "Backing up credentials: $cred_path"
            
            local dest_name=$(echo "$cred_path" | sed 's|/|-|g' | sed 's|^-||')
            
            if [[ -d "$cred_path" ]]; then
                cp -r "$cred_path" "$temp_dir/$dest_name"
            else
                cp "$cred_path" "$temp_dir/$dest_name"
            fi
            
            chmod 600 "$temp_dir/$dest_name" 2>/dev/null || true
            
            update_backup_manifest "$backup_manifest" "security" "$cred_path" "$(du -sh "$temp_dir/$dest_name" | cut -f1)"
        fi
    done
    
    backup_ssh_keys "$temp_dir"
    backup_tls_certificates "$temp_dir"
    
    log_success "Security credentials backed up"
}

backup_log_files() {
    local backup_id="$1"
    
    log_info "Backing up log files..."
    
    local temp_dir="/tmp/$backup_id/logs"
    mkdir -p "$temp_dir"
    
    local log_paths=(
        "/var/log/github-runner"
        "$PROJECT_ROOT/logs"
        "/opt/github-runner/_diag"
        "/var/log/actions-runner"
        "/var/log/syslog"
        "/var/log/daemon.log"
    )
    
    for log_path in "${log_paths[@]}"; do
        if [[ -e "$log_path" ]]; then
            log_debug "Backing up logs: $log_path"
            
            local dest_name=$(echo "$log_path" | sed 's|/|-|g' | sed 's|^-||')
            
            if [[ -d "$log_path" ]]; then
                find "$log_path" -name "*.log" -mtime -7 -exec cp {} "$temp_dir/" \;
            else
                if [[ "$log_path" =~ \.(log|out)$ ]]; then
                    cp "$log_path" "$temp_dir/$dest_name"
                fi
            fi
        fi
    done
    
    backup_journal_logs "$temp_dir"
    
    log_success "Log files backed up"
}

backup_metrics_data() {
    local backup_id="$1"
    
    log_info "Backing up metrics and monitoring data..."
    
    local temp_dir="/tmp/$backup_id/metrics"
    mkdir -p "$temp_dir"
    
    local metrics_paths=(
        "$PROJECT_ROOT/monitoring"
        "$PROJECT_ROOT/prometheus"
        "/var/lib/prometheus"
        "/var/lib/grafana"
        "$PROJECT_ROOT/data/metrics"
    )
    
    for metrics_path in "${metrics_paths[@]}"; do
        if [[ -d "$metrics_path" ]]; then
            log_debug "Backing up metrics: $metrics_path"
            
            local dest_name=$(basename "$metrics_path")
            rsync -av "$metrics_path/" "$temp_dir/$dest_name/"
            
            update_backup_manifest "$backup_manifest" "metrics" "$metrics_path" "$(du -sh "$temp_dir/$dest_name" | cut -f1)"
        fi
    done
    
    backup_performance_data "$temp_dir"
    
    log_success "Metrics data backed up"
}

backup_docker_resources() {
    local backup_id="$1"
    
    log_info "Backing up Docker resources..."
    
    local temp_dir="/tmp/$backup_id/docker"
    mkdir -p "$temp_dir"
    
    if command -v docker >/dev/null 2>&1; then
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}" > "$temp_dir/images.txt"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" > "$temp_dir/containers.txt"
        
        if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
            cp "$PROJECT_ROOT/docker-compose.yml" "$temp_dir/"
        fi
        
        docker inspect github-runner 2>/dev/null | jq . > "$temp_dir/runner-inspect.json" || true
        
        update_backup_manifest "$backup_manifest" "docker" "containers" "$(wc -l < "$temp_dir/containers.txt") containers"
        update_backup_manifest "$backup_manifest" "docker" "images" "$(wc -l < "$temp_dir/images.txt") images"
    fi
    
    log_success "Docker resources backed up"
}

backup_system_state() {
    local backup_id="$1"
    
    log_info "Backing up system state..."
    
    local temp_dir="/tmp/$backup_id/system"
    mkdir -p "$temp_dir"
    
    systemctl status github-runner > "$temp_dir/service-status.txt" 2>&1 || true
    ps aux | grep -E "(runner|github)" > "$temp_dir/processes.txt" || true
    netstat -tulpn | grep -E "(runner|github)" > "$temp_dir/network.txt" || true
    df -h > "$temp_dir/disk-usage.txt"
    free -h > "$temp_dir/memory-usage.txt"
    uname -a > "$temp_dir/system-info.txt"
    
    if command -v crontab >/dev/null 2>&1; then
        crontab -l > "$temp_dir/crontab.txt" 2>/dev/null || echo "No crontab" > "$temp_dir/crontab.txt"
    fi
    
    env | grep -E "(GITHUB|RUNNER|ACTIONS)" | sort > "$temp_dir/environment.txt" || true
    
    update_backup_manifest "$backup_manifest" "system_state" "status" "complete"
    
    log_success "System state backed up"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi