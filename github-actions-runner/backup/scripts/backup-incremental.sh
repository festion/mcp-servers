#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$SCRIPT_DIR/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-backup-incremental.log"

usage() {
    cat << 'EOF'
Usage: backup-incremental.sh [OPTIONS]

Perform incremental backup of GitHub Actions runner

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Backup destination [default: /var/backups/github-runner]
    -c, --config FILE       Backup configuration file
    -b, --baseline ID       Baseline backup ID for comparison
    -a, --auto-baseline     Automatically find latest full backup as baseline
    -e, --encrypt           Encrypt backup files
    -r, --remote            Include remote storage backup
    --exclude PATTERN       Exclude files matching pattern
    --retention DAYS        Retention period in days [default: 7]
    --compression LEVEL     Compression level 0-9 [default: 6]
    --track-changes         Track and report changed files
    --skip-unchanged        Skip files that haven't changed
    --dry-run               Show what would be backed up without creating backup
    --force                 Force backup even if no changes detected

Examples:
    ./backup-incremental.sh                            # Auto baseline incremental
    ./backup-incremental.sh -b full-backup-20240115    # Specific baseline
    ./backup-incremental.sh --track-changes            # With change tracking
    ./backup-incremental.sh --dry-run                  # Preview changes
EOF
}

DESTINATION="/var/backups/github-runner"
CONFIG_FILE="$BACKUP_ROOT/config/backup.conf"
BASELINE_ID=""
AUTO_BASELINE=false
ENCRYPT=false
REMOTE_BACKUP=false
EXCLUDE_PATTERNS=()
RETENTION_DAYS=7
COMPRESSION_LEVEL=6
TRACK_CHANGES=false
SKIP_UNCHANGED=false
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
        -b|--baseline)
            BASELINE_ID="$2"
            shift 2
            ;;
        -a|--auto-baseline)
            AUTO_BASELINE=true
            shift
            ;;
        -e|--encrypt)
            ENCRYPT=true
            shift
            ;;
        -r|--remote)
            REMOTE_BACKUP=true
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
        --track-changes)
            TRACK_CHANGES=true
            shift
            ;;
        --skip-unchanged)
            SKIP_UNCHANGED=true
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
    log_section "GitHub Actions Runner - Incremental Backup"
    
    load_backup_config "$CONFIG_FILE"
    validate_backup_environment
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_id="incremental-backup-$timestamp"
    
    if [[ "$AUTO_BASELINE" == true && -z "$BASELINE_ID" ]]; then
        BASELINE_ID=$(find_latest_full_backup "$DESTINATION")
        if [[ -z "$BASELINE_ID" ]]; then
            log_error "No baseline backup found. Run a full backup first."
            exit 1
        fi
    fi
    
    if [[ -z "$BASELINE_ID" ]]; then
        log_error "Baseline backup ID is required for incremental backup"
        log_error "Use --auto-baseline or specify with --baseline"
        exit 1
    fi
    
    log_info "Starting incremental backup: $backup_id"
    log_info "Baseline: $BASELINE_ID"
    log_info "Destination: $DESTINATION"
    
    validate_baseline_backup "$BASELINE_ID"
    
    create_backup_directory "$DESTINATION"
    
    local backup_manifest="$DESTINATION/$backup_id.manifest.json"
    local changes_manifest="$DESTINATION/$backup_id.changes.json"
    
    init_backup_manifest "$backup_manifest" "$backup_id" "incremental" "$BASELINE_ID"
    
    local baseline_timestamp=$(get_backup_timestamp "$BASELINE_ID")
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual backup will be created"
        preview_incremental_changes "$backup_id" "$baseline_timestamp"
        exit 0
    fi
    
    init_changes_tracking "$changes_manifest" "$backup_id" "$BASELINE_ID"
    
    backup_changed_files "$backup_id" "$baseline_timestamp" "$changes_manifest"
    backup_new_configuration "$backup_id" "$baseline_timestamp" "$changes_manifest"
    backup_modified_data "$backup_id" "$baseline_timestamp" "$changes_manifest"
    backup_security_updates "$backup_id" "$baseline_timestamp" "$changes_manifest"
    backup_log_changes "$backup_id" "$baseline_timestamp" "$changes_manifest"
    backup_state_changes "$backup_id" "$baseline_timestamp" "$changes_manifest"
    
    finalize_changes_tracking "$changes_manifest"
    
    local change_count=$(get_change_count "$changes_manifest")
    
    if [[ "$change_count" -eq 0 && "$FORCE_BACKUP" != true ]]; then
        log_info "No changes detected since baseline backup"
        cleanup_temp_files "$backup_id"
        exit 0
    fi
    
    create_backup_archive "$backup_id" "$COMPRESSION_LEVEL"
    
    if [[ "$ENCRYPT" == true ]]; then
        encrypt_backup_archive "$backup_id"
    fi
    
    finalize_backup_manifest "$backup_manifest" "$backup_id"
    
    if [[ "$REMOTE_BACKUP" == true ]]; then
        sync_to_remote_storage "$backup_id"
    fi
    
    cleanup_old_incremental_backups "$RETENTION_DAYS"
    
    log_section "Incremental Backup Complete"
    log_success "Backup ID: $backup_id"
    log_info "Changes: $change_count items"
    log_info "Location: $DESTINATION/$backup_id"
    
    if [[ "$TRACK_CHANGES" == true ]]; then
        display_change_summary "$changes_manifest"
    fi
    
    send_backup_notification "incremental" "$backup_id" "success" "$change_count"
    
    return 0
}

find_latest_full_backup() {
    local destination="$1"
    
    if [[ ! -d "$destination" ]]; then
        return
    fi
    
    local latest_backup=""
    local latest_timestamp=0
    
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local backup_type
            backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)
            
            if [[ "$backup_type" == "full" ]]; then
                local timestamp
                timestamp=$(jq -r '.timestamp // 0' "$manifest_file" 2>/dev/null)
                
                if [[ "$timestamp" -gt "$latest_timestamp" ]]; then
                    latest_timestamp="$timestamp"
                    latest_backup=$(jq -r '.backup_id // ""' "$manifest_file" 2>/dev/null)
                fi
            fi
        fi
    done < <(find "$destination" -name "*.manifest.json" -print0 2>/dev/null)
    
    echo "$latest_backup"
}

validate_baseline_backup() {
    local baseline_id="$1"
    
    local baseline_manifest="$DESTINATION/$baseline_id.manifest.json"
    
    if [[ ! -f "$baseline_manifest" ]]; then
        log_error "Baseline backup manifest not found: $baseline_manifest"
        exit 1
    fi
    
    local backup_type
    backup_type=$(jq -r '.backup_type // "unknown"' "$baseline_manifest")
    
    if [[ "$backup_type" != "full" ]]; then
        log_warn "Baseline backup is not a full backup (type: $backup_type)"
    fi
    
    log_info "Baseline backup validated: $baseline_id"
}

get_backup_timestamp() {
    local backup_id="$1"
    
    local manifest_file="$DESTINATION/$backup_id.manifest.json"
    
    if [[ -f "$manifest_file" ]]; then
        jq -r '.timestamp // 0' "$manifest_file"
    else
        echo "0"
    fi
}

init_changes_tracking() {
    local changes_manifest="$1"
    local backup_id="$2"
    local baseline_id="$3"
    
    cat > "$changes_manifest" << EOF
{
    "backup_id": "$backup_id",
    "baseline_id": "$baseline_id",
    "change_tracking_start": "$(date -Iseconds)",
    "changes": {
        "files": [],
        "configuration": [],
        "data": [],
        "security": [],
        "logs": [],
        "system": []
    },
    "statistics": {
        "total_changes": 0,
        "new_files": 0,
        "modified_files": 0,
        "deleted_files": 0,
        "total_size": 0
    }
}
EOF
}

backup_changed_files() {
    local backup_id="$1"
    local baseline_timestamp="$2"
    local changes_manifest="$3"
    
    log_info "Scanning for changed files since baseline..."
    
    local temp_dir="/tmp/$backup_id/changed_files"
    mkdir -p "$temp_dir"
    
    local scan_paths=(
        "/opt/github-runner"
        "/opt/actions-runner"
        "/home/runner"
        "$PROJECT_ROOT"
    )
    
    local changed_files=()
    local new_files=()
    local modified_files=()
    
    for scan_path in "${scan_paths[@]}"; do
        if [[ -d "$scan_path" ]]; then
            log_debug "Scanning path: $scan_path"
            
            while IFS= read -r -d '' file; do
                if [[ -f "$file" ]]; then
                    local file_mtime
                    file_mtime=$(stat -c %Y "$file" 2>/dev/null || echo "0")
                    
                    if [[ "$file_mtime" -gt "$baseline_timestamp" ]]; then
                        local relative_path="${file#$scan_path/}"
                        
                        if should_exclude_file "$file"; then
                            continue
                        fi
                        
                        local dest_file="$temp_dir/$relative_path"
                        local dest_dir="$(dirname "$dest_file")"
                        
                        mkdir -p "$dest_dir"
                        cp "$file" "$dest_file"
                        
                        local file_size
                        file_size=$(stat -c %s "$file" 2>/dev/null || echo "0")
                        
                        local change_type="modified"
                        if [[ "$file_mtime" -gt $((baseline_timestamp + 1)) ]]; then
                            change_type="new"
                            new_files+=("$file")
                        else
                            modified_files+=("$file")
                        fi
                        
                        changed_files+=("$file")
                        
                        local change_entry
                        change_entry=$(cat << EOF
{
    "path": "$file",
    "relative_path": "$relative_path",
    "type": "$change_type",
    "mtime": $file_mtime,
    "size": $file_size,
    "timestamp": "$(date -Iseconds -d "@$file_mtime")"
}
EOF
)
                        
                        update_changes_manifest "$changes_manifest" "files" "$change_entry"
                    fi
                fi
            done < <(find "$scan_path" -type f -print0 2>/dev/null)
        fi
    done
    
    log_info "Found ${#changed_files[@]} changed files (${#new_files[@]} new, ${#modified_files[@]} modified)"
    
    if [[ "$TRACK_CHANGES" == true ]]; then
        echo "Changed files:" >> "$temp_dir/file_changes.log"
        printf '%s\n' "${changed_files[@]}" >> "$temp_dir/file_changes.log"
    fi
}

backup_new_configuration() {
    local backup_id="$1"
    local baseline_timestamp="$2"
    local changes_manifest="$3"
    
    log_info "Checking for configuration changes..."
    
    local temp_dir="/tmp/$backup_id/configuration"
    mkdir -p "$temp_dir"
    
    local config_paths=(
        "/etc/github-runner"
        "/etc/systemd/system/github-runner.service"
        "$PROJECT_ROOT/config"
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/docker-compose.yml"
    )
    
    for config_path in "${config_paths[@]}"; do
        if [[ -e "$config_path" ]]; then
            local config_mtime
            config_mtime=$(stat -c %Y "$config_path" 2>/dev/null || echo "0")
            
            if [[ "$config_mtime" -gt "$baseline_timestamp" ]]; then
                log_debug "Configuration changed: $config_path"
                
                local dest_name=$(echo "$config_path" | sed 's|/|-|g' | sed 's|^-||')
                
                if [[ -d "$config_path" ]]; then
                    cp -r "$config_path" "$temp_dir/$dest_name"
                else
                    cp "$config_path" "$temp_dir/$dest_name"
                fi
                
                local change_entry
                change_entry=$(cat << EOF
{
    "path": "$config_path",
    "type": "configuration",
    "mtime": $config_mtime,
    "timestamp": "$(date -Iseconds -d "@$config_mtime")"
}
EOF
)
                
                update_changes_manifest "$changes_manifest" "configuration" "$change_entry"
            fi
        fi
    done
}

backup_modified_data() {
    local backup_id="$1"
    local baseline_timestamp="$2"
    local changes_manifest="$3"
    
    log_info "Checking for data changes..."
    
    local temp_dir="/tmp/$backup_id/data"
    mkdir -p "$temp_dir"
    
    local data_paths=(
        "$PROJECT_ROOT/data"
        "/var/lib/github-runner"
        "/opt/github-runner/_work"
    )
    
    for data_path in "${data_paths[@]}"; do
        if [[ -d "$data_path" ]]; then
            find "$data_path" -type f -newer "@$baseline_timestamp" -print0 2>/dev/null | while IFS= read -r -d '' file; do
                if should_exclude_file "$file"; then
                    continue
                fi
                
                local relative_path="${file#$data_path/}"
                local dest_file="$temp_dir/$(basename "$data_path")/$relative_path"
                local dest_dir="$(dirname "$dest_file")"
                
                mkdir -p "$dest_dir"
                cp "$file" "$dest_file"
                
                local file_mtime
                file_mtime=$(stat -c %Y "$file" 2>/dev/null || echo "0")
                
                local change_entry
                change_entry=$(cat << EOF
{
    "path": "$file",
    "relative_path": "$relative_path",
    "type": "data",
    "mtime": $file_mtime,
    "timestamp": "$(date -Iseconds -d "@$file_mtime")"
}
EOF
)
                
                update_changes_manifest "$changes_manifest" "data" "$change_entry"
            done
        fi
    done
}

backup_security_updates() {
    local backup_id="$1"
    local baseline_timestamp="$2"
    local changes_manifest="$3"
    
    log_info "Checking for security credential changes..."
    
    local temp_dir="/tmp/$backup_id/security"
    mkdir -p "$temp_dir"
    
    local security_paths=(
        "/etc/github-runner/token"
        "/opt/github-runner/.credentials"
        "/opt/github-runner/.runner"
        "$HOME/.github_token"
    )
    
    for security_path in "${security_paths[@]}"; do
        if [[ -f "$security_path" ]]; then
            local security_mtime
            security_mtime=$(stat -c %Y "$security_path" 2>/dev/null || echo "0")
            
            if [[ "$security_mtime" -gt "$baseline_timestamp" ]]; then
                log_debug "Security file changed: $security_path"
                
                local dest_name=$(echo "$security_path" | sed 's|/|-|g' | sed 's|^-||')
                cp "$security_path" "$temp_dir/$dest_name"
                chmod 600 "$temp_dir/$dest_name"
                
                local change_entry
                change_entry=$(cat << EOF
{
    "path": "$security_path",
    "type": "security",
    "mtime": $security_mtime,
    "timestamp": "$(date -Iseconds -d "@$security_mtime")"
}
EOF
)
                
                update_changes_manifest "$changes_manifest" "security" "$change_entry"
            fi
        fi
    done
}

backup_log_changes() {
    local backup_id="$1"
    local baseline_timestamp="$2"
    local changes_manifest="$3"
    
    log_info "Checking for new log entries..."
    
    local temp_dir="/tmp/$backup_id/logs"
    mkdir -p "$temp_dir"
    
    local log_paths=(
        "/var/log/github-runner"
        "$PROJECT_ROOT/logs"
        "/opt/github-runner/_diag"
    )
    
    for log_path in "${log_paths[@]}"; do
        if [[ -d "$log_path" ]]; then
            find "$log_path" -name "*.log" -newer "@$baseline_timestamp" -print0 2>/dev/null | while IFS= read -r -d '' log_file; do
                local dest_name="$(basename "$log_path")-$(basename "$log_file")"
                cp "$log_file" "$temp_dir/$dest_name"
                
                local log_mtime
                log_mtime=$(stat -c %Y "$log_file" 2>/dev/null || echo "0")
                
                local change_entry
                change_entry=$(cat << EOF
{
    "path": "$log_file",
    "type": "log",
    "mtime": $log_mtime,
    "timestamp": "$(date -Iseconds -d "@$log_mtime")"
}
EOF
)
                
                update_changes_manifest "$changes_manifest" "logs" "$change_entry"
            done
        fi
    done
}

backup_state_changes() {
    local backup_id="$1"
    local baseline_timestamp="$2"
    local changes_manifest="$3"
    
    log_info "Capturing current system state..."
    
    local temp_dir="/tmp/$backup_id/system"
    mkdir -p "$temp_dir"
    
    systemctl status github-runner > "$temp_dir/current-service-status.txt" 2>&1 || true
    ps aux | grep -E "(runner|github)" > "$temp_dir/current-processes.txt" || true
    env | grep -E "(GITHUB|RUNNER|ACTIONS)" | sort > "$temp_dir/current-environment.txt" || true
    
    local change_entry
    change_entry=$(cat << EOF
{
    "type": "system_state",
    "timestamp": "$(date -Iseconds)",
    "description": "Current system state snapshot"
}
EOF
)
    
    update_changes_manifest "$changes_manifest" "system" "$change_entry"
}

finalize_changes_tracking() {
    local changes_manifest="$1"
    
    local total_changes
    total_changes=$(jq '[.changes[] | length] | add' "$changes_manifest")
    
    local temp_manifest="/tmp/changes_temp.json"
    jq --arg timestamp "$(date -Iseconds)" --argjson total "$total_changes" '
        .change_tracking_end = $timestamp |
        .statistics.total_changes = $total |
        .statistics.new_files = (.changes.files | map(select(.type == "new")) | length) |
        .statistics.modified_files = (.changes.files | map(select(.type == "modified")) | length)
    ' "$changes_manifest" > "$temp_manifest"
    
    mv "$temp_manifest" "$changes_manifest"
}

get_change_count() {
    local changes_manifest="$1"
    
    if [[ -f "$changes_manifest" ]]; then
        jq -r '.statistics.total_changes // 0' "$changes_manifest"
    else
        echo "0"
    fi
}

display_change_summary() {
    local changes_manifest="$1"
    
    if [[ ! -f "$changes_manifest" ]]; then
        return
    fi
    
    log_section "Change Summary"
    
    local total_changes
    total_changes=$(jq -r '.statistics.total_changes' "$changes_manifest")
    log_info "Total changes: $total_changes"
    
    local new_files
    new_files=$(jq -r '.statistics.new_files' "$changes_manifest")
    log_info "New files: $new_files"
    
    local modified_files
    modified_files=$(jq -r '.statistics.modified_files' "$changes_manifest")
    log_info "Modified files: $modified_files"
    
    echo
    echo "Change breakdown:"
    jq -r '.changes | to_entries[] | "\(.key): \(.value | length) items"' "$changes_manifest"
}

should_exclude_file() {
    local file="$1"
    
    local default_excludes=(
        "*.tmp"
        "*.pid"
        "*.lock"
        "*/_temp/*"
        "*/cache/*"
        "*.log"
    )
    
    for pattern in "${default_excludes[@]}" "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file" == $pattern ]]; then
            return 0
        fi
    done
    
    return 1
}

update_changes_manifest() {
    local changes_manifest="$1"
    local category="$2"
    local entry="$3"
    
    local temp_manifest="/tmp/changes_update.json"
    
    echo "$entry" | jq -s ".[0]" | jq --arg category "$category" --slurpfile current "$changes_manifest" '
        $current[0] | .changes[$category] += [.]
    ' > "$temp_manifest"
    
    mv "$temp_manifest" "$changes_manifest"
}

cleanup_old_incremental_backups() {
    local retention_days="$1"
    
    log_info "Cleaning up old incremental backups (retention: $retention_days days)..."
    
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "-$retention_days days" +%s)
    
    local removed_count=0
    
    while IFS= read -r -d '' manifest_file; do
        if [[ -f "$manifest_file" ]]; then
            local backup_type
            backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)
            
            if [[ "$backup_type" == "incremental" ]]; then
                local backup_timestamp
                backup_timestamp=$(jq -r '.timestamp // 0' "$manifest_file" 2>/dev/null)
                
                if [[ "$backup_timestamp" -lt "$cutoff_timestamp" ]]; then
                    local backup_id
                    backup_id=$(jq -r '.backup_id // "unknown"' "$manifest_file" 2>/dev/null)
                    
                    log_debug "Removing old incremental backup: $backup_id"
                    
                    rm -f "$DESTINATION/$backup_id"*
                    ((removed_count++))
                fi
            fi
        fi
    done < <(find "$DESTINATION" -name "*.manifest.json" -print0 2>/dev/null)
    
    if [[ "$removed_count" -gt 0 ]]; then
        log_info "Removed $removed_count old incremental backup(s)"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi