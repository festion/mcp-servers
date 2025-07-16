#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-cleanup.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TARGET]

Clean up GitHub Actions runner files and resources

TARGETS:
    logs            Clean log files
    cache           Clean cache and temporary files
    work            Clean runner work directories
    docker          Clean Docker resources
    backups         Clean old backup files
    all             Clean all targets

OPTIONS:
    -h, --help              Show this help message
    -a, --age DAYS          Clean files older than N days [default: 30]
    --cache-age DAYS        Cache retention period [default: 7]
    --work-age DAYS         Work directory retention [default: 3]
    --backup-age DAYS       Backup retention period [default: 30]
    -s, --size-threshold GB Minimum size threshold for cleanup [default: 1]
    -f, --force             Force cleanup without confirmation
    --dry-run               Show what would be cleaned without executing
    -v, --verbose           Verbose output
    -j, --json              JSON output format

Examples:
    $0 logs --age 7             # Clean logs older than 7 days
    $0 cache --force            # Force clean cache files
    $0 work --dry-run           # Preview work directory cleanup
    $0 all --age 14             # Clean all targets older than 14 days
EOF
}

TARGET="all"
AGE_DAYS=30
CACHE_AGE_DAYS=7
WORK_AGE_DAYS=3
BACKUP_AGE_DAYS=30
SIZE_THRESHOLD_GB=1
FORCE=false
DRY_RUN=false
VERBOSE=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -a|--age)
            AGE_DAYS="$2"
            shift 2
            ;;
        --cache-age)
            CACHE_AGE_DAYS="$2"
            shift 2
            ;;
        --work-age)
            WORK_AGE_DAYS="$2"
            shift 2
            ;;
        --backup-age)
            BACKUP_AGE_DAYS="$2"
            shift 2
            ;;
        -s|--size-threshold)
            SIZE_THRESHOLD_GB="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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
        logs|cache|work|docker|backups|all)
            TARGET="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

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
}

check_prerequisites() {
    log_debug "Checking cleanup prerequisites..."
    
    # Check available disk space
    local available_gb
    available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ "$available_gb" -lt 2 ]]; then
        log_warn "Very low disk space available: ${available_gb}GB"
    fi
    
    # Check if cleanup is actually needed
    local current_usage
    current_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ "$current_usage" -lt 70 ]] && [[ "$FORCE" != true ]]; then
        log_info "Disk usage is only ${current_usage}% - cleanup may not be necessary"
        log_info "Use --force to proceed anyway"
    fi
    
    log_success "Prerequisites check completed"
}

get_directory_size() {
    local dir="$1"
    
    if [[ -d "$dir" ]]; then
        du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

format_size() {
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

confirm_cleanup() {
    local target="$1"
    local estimated_size="$2"
    
    if [[ "$FORCE" == true ]] || [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    echo "About to clean: $target"
    echo "Estimated space to free: $estimated_size"
    echo
    read -p "Proceed with cleanup? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled by user"
        return 1
    fi
    
    return 0
}

cleanup_logs() {
    log_section "Log Files Cleanup"
    
    local total_freed=0
    local files_removed=0
    local dirs_cleaned=0
    
    # Define log directories to clean
    local log_dirs=(
        "/var/log/github-runner"
        "$PROJECT_ROOT/logs"
        "/var/cache/github-runner"
        "/tmp"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ ! -d "$log_dir" ]]; then
            log_debug "Directory not found: $log_dir"
            continue
        fi
        
        log_info "Cleaning logs in: $log_dir"
        
        local dir_size_before
        dir_size_before=$(get_directory_size "$log_dir")
        
        # Clean log files older than specified age
        local log_files
        log_files=$(find "$log_dir" -name "*.log" -type f -mtime +"$AGE_DAYS" 2>/dev/null || echo "")
        
        if [[ -n "$log_files" ]]; then
            while IFS= read -r log_file; do
                if [[ -f "$log_file" ]]; then
                    local file_size
                    file_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
                    
                    if [[ "$DRY_RUN" == true ]]; then
                        log_debug "Would remove: $log_file ($(format_size "$file_size"))"
                    else
                        rm -f "$log_file"
                        log_debug "Removed: $log_file ($(format_size "$file_size"))"
                    fi
                    
                    total_freed=$((total_freed + file_size))
                    ((files_removed++))
                fi
            done <<< "$log_files"
        fi
        
        # Clean compressed log files
        local compressed_logs
        compressed_logs=$(find "$log_dir" -name "*.log.gz" -type f -mtime +"$AGE_DAYS" 2>/dev/null || echo "")
        
        if [[ -n "$compressed_logs" ]]; then
            while IFS= read -r log_file; do
                if [[ -f "$log_file" ]]; then
                    local file_size
                    file_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
                    
                    if [[ "$DRY_RUN" == true ]]; then
                        log_debug "Would remove: $log_file ($(format_size "$file_size"))"
                    else
                        rm -f "$log_file"
                        log_debug "Removed: $log_file ($(format_size "$file_size"))"
                    fi
                    
                    total_freed=$((total_freed + file_size))
                    ((files_removed++))
                fi
            done <<< "$compressed_logs"
        fi
        
        # Clean empty directories
        local empty_dirs
        empty_dirs=$(find "$log_dir" -type d -empty 2>/dev/null || echo "")
        
        if [[ -n "$empty_dirs" ]]; then
            while IFS= read -r empty_dir; do
                if [[ -d "$empty_dir" ]] && [[ "$empty_dir" != "$log_dir" ]]; then
                    if [[ "$DRY_RUN" == true ]]; then
                        log_debug "Would remove empty directory: $empty_dir"
                    else
                        rmdir "$empty_dir" 2>/dev/null || true
                        log_debug "Removed empty directory: $empty_dir"
                    fi
                    ((dirs_cleaned++))
                fi
            done <<< "$empty_dirs"
        fi
        
        local dir_size_after
        dir_size_after=$(get_directory_size "$log_dir")
        local dir_freed=$((dir_size_before - dir_size_after))
        
        if [[ "$dir_freed" -gt 0 ]]; then
            log_info "Freed $(format_size "$dir_freed") from $log_dir"
        fi
    done
    
    # Clean systemd journal if running as root
    if [[ $EUID -eq 0 ]] && command -v journalctl >/dev/null 2>&1; then
        log_info "Cleaning systemd journal..."
        
        if [[ "$DRY_RUN" == true ]]; then
            local journal_size
            journal_size=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B' || echo "unknown")
            log_info "Would clean systemd journal (current size: $journal_size)"
        else
            local journal_before
            journal_before=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B' || echo "0")
            
            journalctl --vacuum-time="${AGE_DAYS}d" >/dev/null 2>&1 || log_warn "Failed to clean systemd journal"
            
            local journal_after
            journal_after=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B' || echo "0")
            
            log_success "Systemd journal cleaned: $journal_before → $journal_after"
        fi
    fi
    
    log_success "Log cleanup completed"
    log_info "Files removed: $files_removed"
    log_info "Directories cleaned: $dirs_cleaned"
    log_info "Space freed: $(format_size "$total_freed")"
    
    echo "$total_freed"
}

cleanup_cache() {
    log_section "Cache and Temporary Files Cleanup"
    
    local total_freed=0
    local files_removed=0
    
    # Cache directories
    local cache_dirs=(
        "/var/cache/github-runner"
        "/tmp/github-runner"
        "$HOME/.cache"
        "/var/tmp"
    )
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ ! -d "$cache_dir" ]]; then
            continue
        fi
        
        log_info "Cleaning cache in: $cache_dir"
        
        # Clean files older than cache age
        local cache_files
        cache_files=$(find "$cache_dir" -type f -mtime +"$CACHE_AGE_DAYS" 2>/dev/null || echo "")
        
        if [[ -n "$cache_files" ]]; then
            while IFS= read -r cache_file; do
                if [[ -f "$cache_file" ]]; then
                    local file_size
                    file_size=$(stat -c%s "$cache_file" 2>/dev/null || echo "0")
                    
                    # Skip files that are currently in use
                    if lsof "$cache_file" >/dev/null 2>&1; then
                        log_debug "Skipping file in use: $cache_file"
                        continue
                    fi
                    
                    if [[ "$DRY_RUN" == true ]]; then
                        log_debug "Would remove: $cache_file ($(format_size "$file_size"))"
                    else
                        rm -f "$cache_file" 2>/dev/null || true
                        log_debug "Removed: $cache_file ($(format_size "$file_size"))"
                    fi
                    
                    total_freed=$((total_freed + file_size))
                    ((files_removed++))
                fi
            done <<< "$cache_files"
        fi
        
        # Clean large files regardless of age if they're taking significant space
        local large_files
        large_files=$(find "$cache_dir" -type f -size +100M 2>/dev/null || echo "")
        
        if [[ -n "$large_files" ]]; then
            while IFS= read -r large_file; do
                if [[ -f "$large_file" ]]; then
                    local file_size
                    file_size=$(stat -c%s "$large_file" 2>/dev/null || echo "0")
                    
                    if lsof "$large_file" >/dev/null 2>&1; then
                        log_debug "Skipping large file in use: $large_file"
                        continue
                    fi
                    
                    log_warn "Found large cache file: $large_file ($(format_size "$file_size"))"
                    
                    if [[ "$FORCE" == true ]] || confirm_cleanup "$(basename "$large_file")" "$(format_size "$file_size")"; then
                        if [[ "$DRY_RUN" == true ]]; then
                            log_info "Would remove large file: $large_file"
                        else
                            rm -f "$large_file" 2>/dev/null || true
                            log_info "Removed large file: $large_file"
                        fi
                        
                        total_freed=$((total_freed + file_size))
                        ((files_removed++))
                    fi
                fi
            done <<< "$large_files"
        fi
    done
    
    # Package manager caches
    if command -v apt-get >/dev/null 2>&1 && [[ $EUID -eq 0 ]]; then
        log_info "Cleaning apt package cache..."
        
        if [[ "$DRY_RUN" == true ]]; then
            local apt_cache_size
            apt_cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "unknown")
            log_info "Would clean apt cache (current size: $apt_cache_size)"
        else
            apt-get autoclean >/dev/null 2>&1 || true
            log_success "Apt package cache cleaned"
        fi
    fi
    
    log_success "Cache cleanup completed"
    log_info "Files removed: $files_removed"
    log_info "Space freed: $(format_size "$total_freed")"
    
    echo "$total_freed"
}

cleanup_work_directories() {
    log_section "Work Directories Cleanup"
    
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    local work_dir="$install_path/_work"
    local total_freed=0
    local dirs_removed=0
    
    if [[ ! -d "$work_dir" ]]; then
        log_info "Work directory not found: $work_dir"
        echo "0"
        return 0
    fi
    
    log_info "Cleaning work directory: $work_dir"
    
    # Check for running jobs first
    local running_jobs
    running_jobs=$(find "$work_dir" -name "*.pid" 2>/dev/null | wc -l)
    
    if [[ "$running_jobs" -gt 0 ]]; then
        log_warn "$running_jobs job(s) currently running - skipping active work directories"
    fi
    
    # Find old work directories
    local old_work_dirs
    old_work_dirs=$(find "$work_dir" -maxdepth 1 -type d -name "_*" -mtime +"$WORK_AGE_DAYS" 2>/dev/null || echo "")
    
    if [[ -n "$old_work_dirs" ]]; then
        while IFS= read -r work_subdir; do
            if [[ -d "$work_subdir" ]]; then
                # Check if this directory has active jobs
                local active_pids
                active_pids=$(find "$work_subdir" -name "*.pid" 2>/dev/null | wc -l)
                
                if [[ "$active_pids" -gt 0 ]]; then
                    log_debug "Skipping active work directory: $work_subdir"
                    continue
                fi
                
                local dir_size
                dir_size=$(get_directory_size "$work_subdir")
                
                if [[ "$DRY_RUN" == true ]]; then
                    log_debug "Would remove: $work_subdir ($(format_size "$dir_size"))"
                else
                    rm -rf "$work_subdir" 2>/dev/null || log_warn "Failed to remove: $work_subdir"
                    log_debug "Removed: $work_subdir ($(format_size "$dir_size"))"
                fi
                
                total_freed=$((total_freed + dir_size))
                ((dirs_removed++))
            fi
        done <<< "$old_work_dirs"
    fi
    
    # Clean temporary files in remaining work directories
    local temp_files
    temp_files=$(find "$work_dir" -name "*.tmp" -o -name "*.temp" -o -name "*.lock" -type f -mtime +1 2>/dev/null || echo "")
    
    if [[ -n "$temp_files" ]]; then
        while IFS= read -r temp_file; do
            if [[ -f "$temp_file" ]]; then
                # Check if file is in use
                if lsof "$temp_file" >/dev/null 2>&1; then
                    log_debug "Skipping temp file in use: $temp_file"
                    continue
                fi
                
                local file_size
                file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "0")
                
                if [[ "$DRY_RUN" == true ]]; then
                    log_debug "Would remove temp file: $temp_file"
                else
                    rm -f "$temp_file" 2>/dev/null || true
                    log_debug "Removed temp file: $temp_file"
                fi
                
                total_freed=$((total_freed + file_size))
            fi
        done <<< "$temp_files"
    fi
    
    # Keep only the most recent work directories (beyond age-based cleanup)
    local all_work_dirs
    all_work_dirs=$(find "$work_dir" -maxdepth 1 -type d -name "_*" 2>/dev/null | sort -V || echo "")
    
    if [[ -n "$all_work_dirs" ]]; then
        local work_dir_count
        work_dir_count=$(echo "$all_work_dirs" | wc -l)
        
        if [[ "$work_dir_count" -gt 10 ]]; then
            log_info "Found $work_dir_count work directories, keeping only the 10 most recent"
            
            local dirs_to_remove
            dirs_to_remove=$(echo "$all_work_dirs" | head -n $((work_dir_count - 10)))
            
            while IFS= read -r work_subdir; do
                if [[ -d "$work_subdir" ]]; then
                    # Double-check for active jobs
                    local active_pids
                    active_pids=$(find "$work_subdir" -name "*.pid" 2>/dev/null | wc -l)
                    
                    if [[ "$active_pids" -gt 0 ]]; then
                        log_debug "Skipping active work directory: $work_subdir"
                        continue
                    fi
                    
                    local dir_size
                    dir_size=$(get_directory_size "$work_subdir")
                    
                    if [[ "$DRY_RUN" == true ]]; then
                        log_debug "Would remove old work dir: $work_subdir ($(format_size "$dir_size"))"
                    else
                        rm -rf "$work_subdir" 2>/dev/null || log_warn "Failed to remove: $work_subdir"
                        log_debug "Removed old work dir: $work_subdir ($(format_size "$dir_size"))"
                    fi
                    
                    total_freed=$((total_freed + dir_size))
                    ((dirs_removed++))
                fi
            done <<< "$dirs_to_remove"
        fi
    fi
    
    log_success "Work directory cleanup completed"
    log_info "Directories removed: $dirs_removed"
    log_info "Space freed: $(format_size "$total_freed")"
    
    echo "$total_freed"
}

cleanup_docker() {
    log_section "Docker Resources Cleanup"
    
    local total_freed=0
    
    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker not found, skipping Docker cleanup"
        echo "0"
        return 0
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker daemon not accessible, skipping Docker cleanup"
        echo "0"
        return 0
    fi
    
    # Get Docker space usage before cleanup
    local docker_space_before
    docker_space_before=$(docker system df --format "table {{.Type}}\t{{.Size}}" 2>/dev/null | tail -n +2 | awk '{sum+=$2} END{print sum}' || echo "0")
    
    log_info "Docker space usage before cleanup: $(format_size "$docker_space_before")"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would clean Docker resources:"
        log_info "  - Stopped containers"
        log_info "  - Unused networks"
        log_info "  - Dangling images"
        log_info "  - Build cache"
        
        docker system df 2>/dev/null || true
        echo "0"
        return 0
    fi
    
    # Clean stopped containers
    log_info "Removing stopped containers..."
    local removed_containers
    removed_containers=$(docker container prune -f 2>/dev/null | grep "Total reclaimed space" | awk '{print $4}' || echo "0")
    if [[ "$removed_containers" != "0" ]]; then
        log_success "Removed stopped containers: $removed_containers"
    fi
    
    # Clean unused networks
    log_info "Removing unused networks..."
    docker network prune -f >/dev/null 2>&1 || true
    log_success "Cleaned unused networks"
    
    # Clean dangling images
    log_info "Removing dangling images..."
    local removed_images
    removed_images=$(docker image prune -f 2>/dev/null | grep "Total reclaimed space" | awk '{print $4}' || echo "0")
    if [[ "$removed_images" != "0" ]]; then
        log_success "Removed dangling images: $removed_images"
    fi
    
    # Clean build cache
    if docker builder version >/dev/null 2>&1; then
        log_info "Cleaning build cache..."
        local removed_cache
        removed_cache=$(docker builder prune -f 2>/dev/null | grep "Total:" | awk '{print $2}' || echo "0")
        if [[ "$removed_cache" != "0" ]]; then
            log_success "Cleaned build cache: $removed_cache"
        fi
    fi
    
    # Clean unused volumes (with caution)
    log_info "Cleaning unused volumes..."
    local removed_volumes
    removed_volumes=$(docker volume prune -f 2>/dev/null | grep "Total reclaimed space" | awk '{print $4}' || echo "0")
    if [[ "$removed_volumes" != "0" ]]; then
        log_success "Removed unused volumes: $removed_volumes"
    fi
    
    # Get Docker space usage after cleanup
    local docker_space_after
    docker_space_after=$(docker system df --format "table {{.Type}}\t{{.Size}}" 2>/dev/null | tail -n +2 | awk '{sum+=$2} END{print sum}' || echo "0")
    
    total_freed=$((docker_space_before - docker_space_after))
    
    log_success "Docker cleanup completed"
    log_info "Space freed: $(format_size "$total_freed")"
    
    echo "$total_freed"
}

cleanup_backups() {
    log_section "Backup Files Cleanup"
    
    local backup_dirs=(
        "/var/backups/github-runner"
        "$PROJECT_ROOT/backups"
    )
    
    local total_freed=0
    local files_removed=0
    
    for backup_dir in "${backup_dirs[@]}"; do
        if [[ ! -d "$backup_dir" ]]; then
            continue
        fi
        
        log_info "Cleaning backups in: $backup_dir"
        
        # Use backup script if available
        local backup_script="$SCRIPT_DIR/backup-enhanced.sh"
        if [[ -x "$backup_script" ]]; then
            log_info "Using backup script for cleanup..."
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would run: $backup_script cleanup --retention-days $BACKUP_AGE_DAYS"
            else
                "$backup_script" cleanup --retention-days "$BACKUP_AGE_DAYS" >/dev/null 2>&1 || log_warn "Backup script cleanup failed"
            fi
        else
            # Manual cleanup
            local old_backups
            old_backups=$(find "$backup_dir" -name "backup-*" -type f -mtime +"$BACKUP_AGE_DAYS" 2>/dev/null || echo "")
            
            if [[ -n "$old_backups" ]]; then
                while IFS= read -r backup_file; do
                    if [[ -f "$backup_file" ]]; then
                        local file_size
                        file_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
                        
                        if [[ "$DRY_RUN" == true ]]; then
                            log_debug "Would remove: $backup_file ($(format_size "$file_size"))"
                        else
                            rm -f "$backup_file"
                            log_debug "Removed: $backup_file ($(format_size "$file_size"))"
                        fi
                        
                        total_freed=$((total_freed + file_size))
                        ((files_removed++))
                    fi
                done <<< "$old_backups"
            fi
        fi
    done
    
    log_success "Backup cleanup completed"
    log_info "Files removed: $files_removed"
    log_info "Space freed: $(format_size "$total_freed")"
    
    echo "$total_freed"
}

generate_cleanup_report() {
    local results="$1"
    local timestamp=$(date +%s)
    
    local report_file="/var/lib/github-runner/cleanup-report-$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$(dirname "$report_file")"
    
    local report_data
    report_data=$(cat << EOF
{
    "cleanup_timestamp": $timestamp,
    "iso_timestamp": "$(date -Iseconds)",
    "target": "$TARGET",
    "hostname": "$(hostname)",
    "dry_run": $DRY_RUN,
    "force": $FORCE,
    "parameters": {
        "age_days": $AGE_DAYS,
        "cache_age_days": $CACHE_AGE_DAYS,
        "work_age_days": $WORK_AGE_DAYS,
        "backup_age_days": $BACKUP_AGE_DAYS,
        "size_threshold_gb": $SIZE_THRESHOLD_GB
    },
    "results": $results,
    "system_info": $(get_system_info)
}
EOF
)
    
    echo "$report_data" > "$report_file"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$report_data" | jq .
    else
        log_info "Cleanup report saved: $report_file"
    fi
}

main() {
    local lock_file="/var/lock/github-runner-cleanup.lock"
    
    if ! lock_script "$lock_file" 300; then
        log_error "Another cleanup operation is in progress"
        exit 1
    fi
    
    trap 'unlock_script "$lock_file"' EXIT
    
    log_section "GitHub Actions Runner Cleanup"
    log_info "Target: $TARGET"
    log_info "Dry run: $DRY_RUN"
    log_info "Force: $FORCE"
    
    load_configuration
    check_prerequisites
    
    local cleanup_results="{}"
    local total_space_freed=0
    
    case "$TARGET" in
        logs)
            local freed
            freed=$(cleanup_logs)
            total_space_freed=$((total_space_freed + freed))
            cleanup_results=$(echo '{}' | jq --arg freed "$freed" '. + {"logs": ($freed | tonumber)}')
            ;;
        cache)
            local freed
            freed=$(cleanup_cache)
            total_space_freed=$((total_space_freed + freed))
            cleanup_results=$(echo '{}' | jq --arg freed "$freed" '. + {"cache": ($freed | tonumber)}')
            ;;
        work)
            local freed
            freed=$(cleanup_work_directories)
            total_space_freed=$((total_space_freed + freed))
            cleanup_results=$(echo '{}' | jq --arg freed "$freed" '. + {"work": ($freed | tonumber)}')
            ;;
        docker)
            local freed
            freed=$(cleanup_docker)
            total_space_freed=$((total_space_freed + freed))
            cleanup_results=$(echo '{}' | jq --arg freed "$freed" '. + {"docker": ($freed | tonumber)}')
            ;;
        backups)
            local freed
            freed=$(cleanup_backups)
            total_space_freed=$((total_space_freed + freed))
            cleanup_results=$(echo '{}' | jq --arg freed "$freed" '. + {"backups": ($freed | tonumber)}')
            ;;
        all)
            local targets=("logs" "cache" "work" "docker" "backups")
            
            for target in "${targets[@]}"; do
                log_section "Cleaning: $target"
                
                local freed=0
                case "$target" in
                    logs) freed=$(cleanup_logs) ;;
                    cache) freed=$(cleanup_cache) ;;
                    work) freed=$(cleanup_work_directories) ;;
                    docker) freed=$(cleanup_docker) ;;
                    backups) freed=$(cleanup_backups) ;;
                esac
                
                total_space_freed=$((total_space_freed + freed))
                cleanup_results=$(echo "$cleanup_results" | jq --arg target "$target" --arg freed "$freed" '. + {($target): ($freed | tonumber)}')
            done
            ;;
        *)
            log_error "Unknown target: $TARGET"
            exit 1
            ;;
    esac
    
    # Add total to results
    cleanup_results=$(echo "$cleanup_results" | jq --arg total "$total_space_freed" '. + {"total_freed": ($total | tonumber)}')
    
    generate_cleanup_report "$cleanup_results"
    
    log_section "Cleanup Completed"
    log_success "Total space freed: $(format_size "$total_space_freed")"
    
    # Send notification
    if [[ "$total_space_freed" -gt 0 ]]; then
        local freed_mb=$((total_space_freed / 1024 / 1024))
        send_notification "success" "Cleanup Complete" "GitHub Actions runner cleanup completed on $(hostname): $(format_size "$total_space_freed") freed from $TARGET"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi