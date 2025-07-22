#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-maintenance.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Perform maintenance tasks for GitHub Actions runner

COMMANDS:
    routine         Run routine maintenance tasks
    logs            Log cleanup and rotation
    disk            Disk space cleanup
    security        Security updates and checks
    performance     Performance optimization
    health          Health check and repair
    full            Complete maintenance cycle

OPTIONS:
    -h, --help              Show this help message
    -f, --force             Force maintenance even if runner is active
    --dry-run               Show what would be done without executing
    --skip-backup           Skip backup before maintenance
    --retention-days DAYS   Log retention period [default: 30]
    --disk-threshold PCT    Disk cleanup threshold [default: 80]
    -v, --verbose           Verbose output
    -j, --json              JSON output format

Examples:
    $0 routine                      # Run routine maintenance
    $0 logs --retention-days 7      # Clean logs older than 7 days
    $0 disk --disk-threshold 70     # Clean if disk > 70%
    $0 full --force                 # Complete maintenance cycle
EOF
}

COMMAND=""
FORCE=false
DRY_RUN=false
SKIP_BACKUP=false
RETENTION_DAYS=30
DISK_THRESHOLD=80
VERBOSE=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --disk-threshold)
            DISK_THRESHOLD="$2"
            shift 2
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
        routine|logs|disk|security|performance|health|full)
            COMMAND="$1"
            shift
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
    log_debug "Checking maintenance prerequisites..."
    
    # Check if we're running as appropriate user
    if [[ $EUID -eq 0 ]]; then
        log_debug "Running as root - full system access"
    else
        log_warn "Not running as root - some maintenance tasks may be limited"
    fi
    
    # Check disk space for logs
    if ! check_disk_space "/var/log" 95; then
        log_warn "Low disk space in /var/log - log cleanup may be needed urgently"
    fi
    
    log_success "Prerequisites check completed"
}

check_runner_state() {
    local can_proceed=true
    
    # Check if service is running
    local service_active=false
    if systemctl is-active github-runner.service >/dev/null 2>&1; then
        service_active=true
        log_info "GitHub runner service is active"
    else
        log_info "GitHub runner service is not active"
    fi
    
    # Check for running jobs
    local running_jobs=0
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ -d "$install_path/_work" ]]; then
        running_jobs=$(find "$install_path/_work" -name "*.pid" 2>/dev/null | wc -l)
    fi
    
    if [[ "$running_jobs" -gt 0 ]]; then
        log_warn "$running_jobs job(s) currently running"
        if [[ "$FORCE" != true ]]; then
            log_error "Cannot perform maintenance with active jobs. Use --force to override"
            can_proceed=false
        else
            log_warn "Proceeding with maintenance despite active jobs (--force used)"
        fi
    fi
    
    if [[ "$service_active" == true ]] && [[ "$FORCE" != true ]] && [[ "$COMMAND" =~ ^(security|performance|full)$ ]]; then
        log_warn "Service is active. Some maintenance tasks may require service restart"
        log_warn "Use --force to proceed or stop the service manually"
        can_proceed=false
    fi
    
    if [[ "$can_proceed" != true ]]; then
        exit 1
    fi
}

create_maintenance_backup() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        log_info "Skipping maintenance backup"
        return 0
    fi
    
    log_section "Creating Maintenance Backup"
    
    local backup_script="$SCRIPT_DIR/backup-enhanced.sh"
    if [[ -x "$backup_script" ]]; then
        log_info "Creating pre-maintenance backup..."
        
        local backup_id
        if backup_id=$("$backup_script" create --destination "/var/backups/github-runner/maintenance" 2>/dev/null); then
            log_success "Maintenance backup created: $backup_id"
            echo "$backup_id" > /tmp/maintenance-backup-id
        else
            log_warn "Failed to create maintenance backup"
        fi
    else
        log_warn "Backup script not found: $backup_script"
    fi
}

cleanup_logs() {
    log_section "Log Cleanup"
    
    local cleaned_size=0
    local cleaned_files=0
    
    # System logs
    local log_dirs=(
        "/var/log/github-runner"
        "$PROJECT_ROOT/logs"
        "/var/cache/github-runner"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            log_info "Cleaning logs in: $log_dir"
            
            # Find old log files
            local old_files
            old_files=$(find "$log_dir" -name "*.log" -type f -mtime +"$RETENTION_DAYS" 2>/dev/null || echo "")
            
            if [[ -n "$old_files" ]]; then
                while IFS= read -r log_file; do
                    if [[ -f "$log_file" ]]; then
                        local file_size
                        file_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
                        
                        if [[ "$DRY_RUN" == true ]]; then
                            log_info "Would remove: $log_file ($(format_bytes "$file_size"))"
                        else
                            rm -f "$log_file"
                            log_debug "Removed: $log_file ($(format_bytes "$file_size"))"
                        fi
                        
                        cleaned_size=$((cleaned_size + file_size))
                        ((cleaned_files++))
                    fi
                done <<< "$old_files"
            fi
            
            # Compress old logs
            local compress_files
            compress_files=$(find "$log_dir" -name "*.log" -type f -mtime +7 ! -name "*.gz" 2>/dev/null || echo "")
            
            if [[ -n "$compress_files" ]]; then
                while IFS= read -r log_file; do
                    if [[ -f "$log_file" ]]; then
                        if [[ "$DRY_RUN" == true ]]; then
                            log_info "Would compress: $log_file"
                        else
                            gzip "$log_file" 2>/dev/null || log_warn "Failed to compress: $log_file"
                            log_debug "Compressed: $log_file"
                        fi
                    fi
                done <<< "$compress_files"
            fi
        fi
    done
    
    # Systemd journal cleanup
    if command -v journalctl >/dev/null 2>&1 && [[ $EUID -eq 0 ]]; then
        log_info "Cleaning systemd journal..."
        
        if [[ "$DRY_RUN" == true ]]; then
            local journal_size
            journal_size=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B' || echo "unknown")
            log_info "Would clean systemd journal (current size: $journal_size)"
        else
            journalctl --vacuum-time="${RETENTION_DAYS}d" >/dev/null 2>&1 || log_warn "Failed to clean systemd journal"
            log_success "Systemd journal cleaned"
        fi
    fi
    
    # Docker cleanup
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        log_info "Cleaning Docker resources..."
        
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would clean Docker: unused containers, networks, images"
        else
            # Clean up stopped containers
            docker container prune -f >/dev/null 2>&1 || true
            
            # Clean up unused networks
            docker network prune -f >/dev/null 2>&1 || true
            
            # Clean up unused images (but keep recent ones)
            docker image prune -f >/dev/null 2>&1 || true
            
            log_success "Docker cleanup completed"
        fi
    fi
    
    local cleaned_size_mb=$((cleaned_size / 1024 / 1024))
    
    log_success "Log cleanup completed"
    log_info "Files processed: $cleaned_files"
    log_info "Space freed: ${cleaned_size_mb}MB"
    
    return 0
}

cleanup_disk_space() {
    log_section "Disk Space Cleanup"
    
    local current_usage
    current_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log_info "Current disk usage: ${current_usage}%"
    log_info "Threshold: ${DISK_THRESHOLD}%"
    
    if [[ "$current_usage" -lt "$DISK_THRESHOLD" ]]; then
        log_success "Disk usage is below threshold, no cleanup needed"
        return 0
    fi
    
    log_warn "Disk usage exceeds threshold, performing cleanup..."
    
    # Temporary files cleanup
    local temp_dirs=(
        "/tmp"
        "/var/tmp"
        "/var/cache/github-runner"
    )
    
    local total_freed=0
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            log_info "Cleaning temporary files in: $temp_dir"
            
            # Find files older than 7 days
            local old_temp_files
            old_temp_files=$(find "$temp_dir" -type f -mtime +7 2>/dev/null || echo "")
            
            if [[ -n "$old_temp_files" ]]; then
                local freed_bytes=0
                
                while IFS= read -r temp_file; do
                    if [[ -f "$temp_file" ]]; then
                        local file_size
                        file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "0")
                        
                        if [[ "$DRY_RUN" == true ]]; then
                            log_debug "Would remove: $temp_file"
                        else
                            rm -f "$temp_file" 2>/dev/null || true
                        fi
                        
                        freed_bytes=$((freed_bytes + file_size))
                    fi
                done <<< "$old_temp_files"
                
                total_freed=$((total_freed + freed_bytes))
                local freed_mb=$((freed_bytes / 1024 / 1024))
                log_info "Freed ${freed_mb}MB from $temp_dir"
            fi
        fi
    done
    
    # Package cache cleanup
    if command -v apt-get >/dev/null 2>&1 && [[ $EUID -eq 0 ]]; then
        log_info "Cleaning package cache..."
        
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would clean apt package cache"
        else
            apt-get autoremove -y >/dev/null 2>&1 || true
            apt-get autoclean >/dev/null 2>&1 || true
            log_success "Package cache cleaned"
        fi
    fi
    
    # Runner work directory cleanup
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ -d "$install_path/_work" ]]; then
        log_info "Cleaning runner work directory..."
        
        # Remove old workflow runs (keep last 10)
        local work_dirs
        work_dirs=$(find "$install_path/_work" -maxdepth 1 -type d -name "_*" 2>/dev/null | sort -V | head -n -10 || echo "")
        
        if [[ -n "$work_dirs" ]]; then
            while IFS= read -r work_dir; do
                if [[ -d "$work_dir" ]]; then
                    local dir_size
                    dir_size=$(du -sb "$work_dir" 2>/dev/null | cut -f1 || echo "0")
                    
                    if [[ "$DRY_RUN" == true ]]; then
                        log_debug "Would remove work directory: $work_dir"
                    else
                        rm -rf "$work_dir" 2>/dev/null || true
                    fi
                    
                    total_freed=$((total_freed + dir_size))
                fi
            done <<< "$work_dirs"
        fi
    fi
    
    local total_freed_mb=$((total_freed / 1024 / 1024))
    
    # Check final disk usage
    local final_usage
    final_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log_success "Disk cleanup completed"
    log_info "Space freed: ${total_freed_mb}MB"
    log_info "Disk usage: ${current_usage}% → ${final_usage}%"
    
    if [[ "$final_usage" -ge "$DISK_THRESHOLD" ]]; then
        log_warn "Disk usage still above threshold after cleanup"
        return 1
    fi
    
    return 0
}

perform_security_maintenance() {
    log_section "Security Maintenance"
    
    # Update system packages
    if command -v apt-get >/dev/null 2>&1 && [[ $EUID -eq 0 ]]; then
        log_info "Checking for security updates..."
        
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would update system packages"
        else
            # Update package lists
            apt-get update -qq >/dev/null 2>&1 || log_warn "Failed to update package lists"
            
            # Check for security updates
            local security_updates
            security_updates=$(apt list --upgradable 2>/dev/null | grep -c security || echo "0")
            
            if [[ "$security_updates" -gt 0 ]]; then
                log_info "Installing $security_updates security update(s)..."
                apt-get upgrade -y >/dev/null 2>&1 || log_warn "Some updates failed"
                log_success "Security updates installed"
            else
                log_success "No security updates available"
            fi
        fi
    fi
    
    # Check file permissions
    log_info "Checking file permissions..."
    
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    local user="${USER:-github-runner}"
    
    if [[ -d "$install_path" ]]; then
        # Check ownership
        local wrong_owner
        wrong_owner=$(find "$install_path" ! -user "$user" 2>/dev/null | wc -l)
        
        if [[ "$wrong_owner" -gt 0 ]]; then
            log_warn "Found $wrong_owner files with incorrect ownership"
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would fix ownership for $wrong_owner files"
            else
                chown -R "$user:$user" "$install_path" 2>/dev/null || log_warn "Failed to fix some ownership issues"
                log_success "File ownership corrected"
            fi
        else
            log_success "File ownership is correct"
        fi
        
        # Check executable permissions
        local script_files=("$install_path"/*.sh)
        for script in "${script_files[@]}"; do
            if [[ -f "$script" ]] && [[ ! -x "$script" ]]; then
                log_warn "Script not executable: $script"
                
                if [[ "$DRY_RUN" == true ]]; then
                    log_info "Would make executable: $script"
                else
                    chmod +x "$script" 2>/dev/null || log_warn "Failed to make executable: $script"
                fi
            fi
        done
    fi
    
    # Check configuration file permissions
    if [[ -d "/etc/github-runner" ]]; then
        find "/etc/github-runner" -name "*.env" -perm /044 2>/dev/null | while IFS= read -r config_file; do
            log_warn "Configuration file is world-readable: $config_file"
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would fix permissions for: $config_file"
            else
                chmod 640 "$config_file" 2>/dev/null || log_warn "Failed to fix permissions: $config_file"
            fi
        done
    fi
    
    # Check for suspicious processes
    log_info "Checking for suspicious processes..."
    
    local suspicious_count=0
    
    # Check for processes running as root that shouldn't be
    if pgrep -u root -f "github.*runner" >/dev/null 2>&1; then
        log_warn "Found GitHub runner processes running as root"
        ((suspicious_count++))
    fi
    
    # Check for unusual network connections
    if command -v netstat >/dev/null 2>&1; then
        local unusual_connections
        unusual_connections=$(netstat -tuln | grep -E ":(22|80|443|8080|9000)" | wc -l || echo "0")
        log_debug "Found $unusual_connections network connections on common ports"
    fi
    
    if [[ "$suspicious_count" -eq 0 ]]; then
        log_success "No security issues detected"
    else
        log_warn "Found $suspicious_count potential security issue(s)"
    fi
    
    return 0
}

optimize_performance() {
    log_section "Performance Optimization"
    
    # System performance tuning
    log_info "Checking system performance settings..."
    
    # Check swap usage
    local swap_usage
    swap_usage=$(free | awk 'NR==3{printf "%.0f", $3*100/($2+1)}' 2>/dev/null || echo "0")
    
    if [[ "$swap_usage" -gt 50 ]]; then
        log_warn "High swap usage detected: ${swap_usage}%"
        
        # Clear swap if possible
        if [[ $EUID -eq 0 ]] && [[ "$DRY_RUN" != true ]]; then
            log_info "Attempting to reduce swap usage..."
            sysctl vm.swappiness=10 >/dev/null 2>&1 || true
        fi
    else
        log_success "Swap usage is acceptable: ${swap_usage}%"
    fi
    
    # Check for memory leaks
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    
    if pgrep -f "$install_path" >/dev/null 2>&1; then
        local runner_memory
        runner_memory=$(ps -o pid,pmem,cmd -C Runner.Listener,Runner.Worker 2>/dev/null | awk 'NR>1{sum+=$2} END{printf "%.1f", sum}' || echo "0")
        
        log_info "Runner memory usage: ${runner_memory}%"
        
        if [[ $(echo "$runner_memory > 20" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
            log_warn "High runner memory usage detected"
            
            if [[ "$FORCE" == true ]] && [[ "$DRY_RUN" != true ]]; then
                log_info "Restarting runner to clear memory..."
                systemctl restart github-runner.service || log_warn "Failed to restart service"
            fi
        fi
    fi
    
    # Optimize Docker if present
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        log_info "Optimizing Docker performance..."
        
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would optimize Docker settings"
        else
            # Prune build cache
            docker builder prune -f >/dev/null 2>&1 || true
            
            # Optimize Docker daemon settings
            local docker_config="/etc/docker/daemon.json"
            if [[ ! -f "$docker_config" ]] && [[ $EUID -eq 0 ]]; then
                mkdir -p "$(dirname "$docker_config")"
                cat > "$docker_config" << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
                systemctl reload docker >/dev/null 2>&1 || true
                log_success "Docker configuration optimized"
            fi
        fi
    fi
    
    # File system optimization
    log_info "Checking file system performance..."
    
    # Check for file system errors
    if [[ $EUID -eq 0 ]] && command -v fsck >/dev/null 2>&1; then
        local root_device
        root_device=$(df / | awk 'NR==2{print $1}')
        
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would check file system integrity"
        else
            # Check read-only
            if fsck -n "$root_device" >/dev/null 2>&1; then
                log_success "File system integrity check passed"
            else
                log_warn "File system issues detected - manual check recommended"
            fi
        fi
    fi
    
    log_success "Performance optimization completed"
    return 0
}

run_health_checks() {
    log_section "Health Checks and Repair"
    
    # Run comprehensive health check
    local health_script="$SCRIPT_DIR/health-check.sh"
    if [[ -x "$health_script" ]]; then
        log_info "Running comprehensive health check..."
        
        if "$health_script" --comprehensive >/dev/null 2>&1; then
            log_success "Health check passed"
        else
            log_warn "Health check detected issues"
            
            # Attempt automatic repair
            if [[ "$FORCE" == true ]] && [[ "$DRY_RUN" != true ]]; then
                log_info "Attempting automatic repair..."
                
                # Restart service if unhealthy
                if ! systemctl is-active github-runner.service >/dev/null 2>&1; then
                    systemctl start github-runner.service || log_warn "Failed to start service"
                fi
                
                # Re-run health check
                if "$health_script" --comprehensive >/dev/null 2>&1; then
                    log_success "Automatic repair successful"
                else
                    log_warn "Automatic repair failed - manual intervention needed"
                fi
            fi
        fi
    else
        log_warn "Health check script not found: $health_script"
    fi
    
    # Check configuration consistency
    log_info "Checking configuration consistency..."
    
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    
    if [[ -f "$install_path/.runner" ]]; then
        # Validate runner configuration
        if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
            log_success "Runner configuration is valid"
        else
            log_warn "Runner configuration validation failed"
            
            if [[ "$FORCE" == true ]] && [[ "$DRY_RUN" != true ]]; then
                log_info "Attempting to re-register runner..."
                # This would require a new token, so just log the issue
                log_warn "Manual re-registration may be required"
            fi
        fi
    else
        log_warn "Runner not configured at: $install_path"
    fi
    
    # Check systemd service health
    if systemctl is-enabled github-runner.service >/dev/null 2>&1; then
        if systemctl is-active github-runner.service >/dev/null 2>&1; then
            log_success "Systemd service is healthy"
        else
            log_warn "Systemd service is not active"
            
            if [[ "$FORCE" == true ]] && [[ "$DRY_RUN" != true ]]; then
                systemctl start github-runner.service || log_warn "Failed to start service"
            fi
        fi
    else
        log_warn "Systemd service is not enabled"
        
        if [[ "$FORCE" == true ]] && [[ "$DRY_RUN" != true ]]; then
            systemctl enable github-runner.service || log_warn "Failed to enable service"
        fi
    fi
    
    return 0
}

generate_maintenance_report() {
    local maintenance_results="$1"
    local timestamp=$(date +%s)
    
    local report_file="/var/lib/github-runner/maintenance-report-$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$(dirname "$report_file")"
    
    local report_data
    report_data=$(cat << EOF
{
    "maintenance_timestamp": $timestamp,
    "iso_timestamp": "$(date -Iseconds)",
    "command": "$COMMAND",
    "hostname": "$(hostname)",
    "dry_run": $DRY_RUN,
    "force": $FORCE,
    "results": $maintenance_results,
    "system_info": $(get_system_info)
}
EOF
)
    
    echo "$report_data" > "$report_file"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$report_data" | jq .
    else
        log_info "Maintenance report saved: $report_file"
    fi
}

run_routine_maintenance() {
    log_section "Routine Maintenance"
    
    local results="{}"
    
    # Log cleanup
    log_info "Performing log cleanup..."
    if cleanup_logs; then
        results=$(echo "$results" | jq '. + {"log_cleanup": "success"}')
    else
        results=$(echo "$results" | jq '. + {"log_cleanup": "failed"}')
    fi
    
    # Basic disk cleanup
    if [[ $(df / | awk 'NR==2 {print $5}' | sed 's/%//') -gt 70 ]]; then
        log_info "Performing disk cleanup..."
        if cleanup_disk_space; then
            results=$(echo "$results" | jq '. + {"disk_cleanup": "success"}')
        else
            results=$(echo "$results" | jq '. + {"disk_cleanup": "failed"}')
        fi
    else
        results=$(echo "$results" | jq '. + {"disk_cleanup": "skipped"}')
    fi
    
    # Health check
    log_info "Performing health check..."
    if run_health_checks; then
        results=$(echo "$results" | jq '. + {"health_check": "success"}')
    else
        results=$(echo "$results" | jq '. + {"health_check": "failed"}')
    fi
    
    echo "$results"
}

run_full_maintenance() {
    log_section "Full Maintenance Cycle"
    
    local results="{}"
    
    # All maintenance tasks
    local tasks=("logs" "disk" "security" "performance" "health")
    
    for task in "${tasks[@]}"; do
        log_info "Running $task maintenance..."
        
        local success=true
        
        case "$task" in
            logs) cleanup_logs || success=false ;;
            disk) cleanup_disk_space || success=false ;;
            security) perform_security_maintenance || success=false ;;
            performance) optimize_performance || success=false ;;
            health) run_health_checks || success=false ;;
        esac
        
        if [[ "$success" == true ]]; then
            results=$(echo "$results" | jq --arg task "$task" '. + {($task): "success"}')
        else
            results=$(echo "$results" | jq --arg task "$task" '. + {($task): "failed"}')
        fi
    done
    
    echo "$results"
}

main() {
    local lock_file="/var/lock/github-runner-maintenance.lock"
    
    if ! lock_script "$lock_file" 600; then
        log_error "Another maintenance operation is in progress"
        exit 1
    fi
    
    trap 'unlock_script "$lock_file"' EXIT
    
    log_section "GitHub Actions Runner Maintenance"
    log_info "Command: $COMMAND"
    log_info "Dry run: $DRY_RUN"
    log_info "Force: $FORCE"
    
    load_configuration
    check_prerequisites
    check_runner_state
    
    if [[ "$COMMAND" != "logs" ]]; then
        create_maintenance_backup
    fi
    
    local maintenance_results="{}"
    
    case "$COMMAND" in
        routine)
            maintenance_results=$(run_routine_maintenance)
            ;;
        logs)
            if cleanup_logs; then
                maintenance_results='{"log_cleanup": "success"}'
            else
                maintenance_results='{"log_cleanup": "failed"}'
            fi
            ;;
        disk)
            if cleanup_disk_space; then
                maintenance_results='{"disk_cleanup": "success"}'
            else
                maintenance_results='{"disk_cleanup": "failed"}'
            fi
            ;;
        security)
            if perform_security_maintenance; then
                maintenance_results='{"security_maintenance": "success"}'
            else
                maintenance_results='{"security_maintenance": "failed"}'
            fi
            ;;
        performance)
            if optimize_performance; then
                maintenance_results='{"performance_optimization": "success"}'
            else
                maintenance_results='{"performance_optimization": "failed"}'
            fi
            ;;
        health)
            if run_health_checks; then
                maintenance_results='{"health_check": "success"}'
            else
                maintenance_results='{"health_check": "failed"}'
            fi
            ;;
        full)
            maintenance_results=$(run_full_maintenance)
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
    
    generate_maintenance_report "$maintenance_results"
    
    # Send notification
    local success_count
    success_count=$(echo "$maintenance_results" | jq '[.[] | select(. == "success")] | length')
    local total_count
    total_count=$(echo "$maintenance_results" | jq 'length')
    
    if [[ "$success_count" -eq "$total_count" ]]; then
        log_section "Maintenance Completed Successfully"
        send_notification "success" "Maintenance Complete" "GitHub Actions runner maintenance completed successfully on $(hostname): $COMMAND"
    else
        log_section "Maintenance Completed with Issues"
        send_notification "warning" "Maintenance Issues" "GitHub Actions runner maintenance completed with issues on $(hostname): $success_count/$total_count tasks successful"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi