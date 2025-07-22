#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-operations.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Restart GitHub Actions runner services

OPTIONS:
    -h, --help          Show this help message
    -s, --service-only  Restart only systemd service (no Docker)
    -d, --docker-only   Restart only Docker containers (no systemd)
    -w, --wait SECONDS  Wait timeout for operations [default: 60]
    -f, --force         Force restart (kill if graceful fails)
    --drain             Drain jobs before stopping
    --health-check      Run health check after restart
    --update            Pull latest images/updates before restart
    -v, --verbose       Verbose output

Examples:
    $0                  # Restart all services
    $0 --drain          # Wait for jobs to finish before restart
    $0 --update         # Update and restart
    $0 --health-check   # Restart with health validation
EOF
}

SERVICE_ONLY=false
DOCKER_ONLY=false
WAIT_TIMEOUT=60
FORCE=false
DRAIN=false
HEALTH_CHECK=false
UPDATE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--service-only)
            SERVICE_ONLY=true
            shift
            ;;
        -d|--docker-only)
            DOCKER_ONLY=true
            shift
            ;;
        -w|--wait)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --drain)
            DRAIN=true
            shift
            ;;
        --health-check)
            HEALTH_CHECK=true
            shift
            ;;
        --update)
            UPDATE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ "$SERVICE_ONLY" == true ]] && [[ "$DOCKER_ONLY" == true ]]; then
    log_error "Cannot specify both --service-only and --docker-only"
    exit 1
fi

check_prerequisites() {
    log_section "Prerequisites Check"
    
    if [[ "$DOCKER_ONLY" != true ]]; then
        check_command systemctl systemd || exit 1
    fi
    
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        check_command docker docker.io || exit 1
        check_command docker-compose docker-compose || exit 1
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Docker daemon is not running"
            exit 1
        fi
    fi
    
    log_success "Prerequisites check passed"
}

check_current_status() {
    log_section "Current Status Check"
    
    local systemd_status="unknown"
    local docker_status="unknown"
    
    if [[ "$DOCKER_ONLY" != true ]]; then
        systemd_status=$(get_service_status github-runner.service)
        log_info "Systemd service status: $systemd_status"
    fi
    
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        local running_containers
        running_containers=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        local total_containers
        total_containers=$(docker-compose config --services 2>/dev/null | wc -l)
        
        if [[ $running_containers -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
            docker_status="running"
        elif [[ $running_containers -gt 0 ]]; then
            docker_status="partial"
        else
            docker_status="stopped"
        fi
        
        log_info "Docker containers status: $docker_status ($running_containers/$total_containers)"
    fi
}

load_configuration() {
    log_section "Configuration Loading"
    
    local config_file="/etc/github-runner/config.env"
    if [[ ! -f "$config_file" ]]; then
        config_file="$PROJECT_ROOT/config/runner.env"
    fi
    
    if [[ -f "$config_file" ]]; then
        log_info "Loading configuration from: $config_file"
        set -a
        source "$config_file"
        set +a
        log_success "Configuration loaded"
    else
        log_warn "No configuration file found, using defaults"
    fi
}

pre_restart_checks() {
    log_section "Pre-Restart Checks"
    
    # Check disk space
    if ! check_disk_space "/" 85; then
        log_error "Insufficient disk space for restart"
        exit 1
    fi
    
    # Check memory usage
    if ! check_memory_usage 90; then
        log_error "Insufficient memory for restart"
        exit 1
    fi
    
    # Check GitHub connectivity
    if ! curl -s --connect-timeout 10 https://api.github.com/rate_limit >/dev/null; then
        log_warn "Cannot reach GitHub API, but continuing restart"
    fi
    
    log_success "Pre-restart checks passed"
}

create_restart_backup() {
    log_section "Creating Restart Backup"
    
    local backup_dir="/var/backups/github-runner/restart-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup current configuration
    if [[ -d "/etc/github-runner" ]]; then
        cp -r "/etc/github-runner" "$backup_dir/"
        log_info "Backed up configuration"
    fi
    
    # Backup systemd service status
    if [[ "$DOCKER_ONLY" != true ]]; then
        systemctl status github-runner.service --no-pager > "$backup_dir/service-status.txt" 2>&1 || true
        journalctl -u github-runner.service --no-pager -n 100 > "$backup_dir/service-logs.txt" 2>&1 || true
    fi
    
    # Backup Docker container status
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        docker-compose ps > "$backup_dir/container-status.txt" 2>&1 || true
        docker-compose logs --tail=100 > "$backup_dir/container-logs.txt" 2>&1 || true
    fi
    
    log_success "Restart backup created: $backup_dir"
    echo "$backup_dir" > /var/lib/github-runner/last-restart-backup
}

update_components() {
    if [[ "$UPDATE" != true ]]; then
        return 0
    fi
    
    log_section "Updating Components"
    
    # Update Docker images
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log_info "Pulling latest Docker images..."
        cd "$PROJECT_ROOT"
        docker-compose pull || log_warn "Failed to pull some images"
    fi
    
    # Update runner binary if systemd service is being restarted
    if [[ "$DOCKER_ONLY" != true ]]; then
        local install_path="${INSTALL_PATH:-/opt/github-runner}"
        
        if [[ -d "$install_path" ]]; then
            log_info "Checking for runner updates..."
            
            cd "$install_path"
            local current_version
            current_version=$(./config.sh --version 2>/dev/null | grep -o 'v[0-9.]*' || echo "unknown")
            
            local latest_version
            latest_version=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
            
            if [[ "$current_version" != "$latest_version" ]]; then
                log_info "Updating runner from $current_version to $latest_version"
                
                local runner_arch="x64"
                if [[ $(uname -m) == "aarch64" ]]; then
                    runner_arch="arm64"
                fi
                
                local download_url="https://github.com/actions/runner/releases/download/${latest_version}/actions-runner-linux-${runner_arch}-${latest_version#v}.tar.gz"
                
                # Download and extract new version
                wget -q "$download_url" -O "actions-runner-new.tar.gz"
                sudo -u "${USER:-github-runner}" tar xzf "actions-runner-new.tar.gz"
                rm "actions-runner-new.tar.gz"
                
                log_success "Runner updated to $latest_version"
            else
                log_info "Runner is already at latest version: $current_version"
            fi
        fi
    fi
    
    log_success "Component updates completed"
}

stop_services() {
    log_section "Stopping Services"
    
    local stop_args=()
    
    if [[ "$SERVICE_ONLY" == true ]]; then
        stop_args+=("--service-only")
    elif [[ "$DOCKER_ONLY" == true ]]; then
        stop_args+=("--docker-only")
    fi
    
    stop_args+=("--wait" "$WAIT_TIMEOUT")
    
    if [[ "$FORCE" == true ]]; then
        stop_args+=("--force")
    fi
    
    if [[ "$DRAIN" == true ]]; then
        stop_args+=("--drain")
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        stop_args+=("--verbose")
    fi
    
    log_info "Stopping services with args: ${stop_args[*]}"
    
    if "$SCRIPT_DIR/stop.sh" "${stop_args[@]}"; then
        log_success "Services stopped successfully"
    else
        log_error "Failed to stop services"
        exit 1
    fi
}

start_services() {
    log_section "Starting Services"
    
    local start_args=()
    
    if [[ "$SERVICE_ONLY" == true ]]; then
        start_args+=("--service-only")
    elif [[ "$DOCKER_ONLY" == true ]]; then
        start_args+=("--docker-only")
    fi
    
    start_args+=("--wait" "$WAIT_TIMEOUT")
    start_args+=("--force")  # Always force start after restart
    
    if [[ "$VERBOSE" == true ]]; then
        start_args+=("--verbose")
    fi
    
    log_info "Starting services with args: ${start_args[*]}"
    
    if "$SCRIPT_DIR/start.sh" "${start_args[@]}"; then
        log_success "Services started successfully"
    else
        log_error "Failed to start services"
        exit 1
    fi
}

run_post_restart_validation() {
    log_section "Post-Restart Validation"
    
    # Wait for services to stabilize
    log_info "Waiting for services to stabilize..."
    sleep 10
    
    # Check systemd service health
    if [[ "$DOCKER_ONLY" != true ]]; then
        if ! systemctl is-active github-runner.service >/dev/null 2>&1; then
            log_error "Systemd service is not active after restart"
            exit 1
        fi
        
        # Check if runner is properly registered
        local install_path="${INSTALL_PATH:-/opt/github-runner}"
        if [[ -f "$install_path/.runner" ]]; then
            log_info "Verifying runner registration..."
            
            local max_wait=60
            local count=0
            
            while [[ $count -lt $max_wait ]]; do
                if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
                    log_success "Runner is properly registered and listening"
                    break
                fi
                
                sleep 2
                ((count += 2))
                
                if [[ $((count % 10)) -eq 0 ]]; then
                    log_info "Still verifying registration... ($count/$max_wait)"
                fi
            done
            
            if [[ $count -ge $max_wait ]]; then
                log_error "Runner registration verification failed"
                exit 1
            fi
        fi
    fi
    
    # Check Docker container health
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        
        # Check container status
        local running_containers
        running_containers=$(docker-compose ps --services --filter "status=running" | wc -l)
        local total_containers
        total_containers=$(docker-compose config --services | wc -l)
        
        if [[ $running_containers -ne $total_containers ]]; then
            log_error "Not all containers are running after restart ($running_containers/$total_containers)"
            docker-compose ps
            exit 1
        fi
        
        # Check for unhealthy containers
        local unhealthy_containers=()
        while IFS= read -r container; do
            local health_status
            health_status=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
            
            if [[ "$health_status" == "unhealthy" ]]; then
                unhealthy_containers+=("$container")
            fi
        done < <(docker-compose ps -q)
        
        if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
            log_error "Unhealthy containers detected: ${unhealthy_containers[*]}"
            exit 1
        fi
    fi
    
    # Run health check if requested
    if [[ "$HEALTH_CHECK" == true ]]; then
        local health_script="$SCRIPT_DIR/health-check.sh"
        if [[ -x "$health_script" ]]; then
            log_info "Running comprehensive health check..."
            if "$health_script" --comprehensive; then
                log_success "Health check passed"
            else
                log_error "Health check failed"
                exit 1
            fi
        else
            log_warn "Health check script not found: $health_script"
        fi
    fi
    
    log_success "Post-restart validation completed"
}

create_restart_summary() {
    log_section "Restart Summary"
    
    local summary_file="/var/lib/github-runner/last-restart.json"
    mkdir -p "$(dirname "$summary_file")"
    
    local systemd_status="not-managed"
    local docker_status="not-managed"
    
    if [[ "$DOCKER_ONLY" != true ]]; then
        systemd_status=$(get_service_status github-runner.service)
    fi
    
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        local running_containers
        running_containers=$(docker-compose ps --services --filter "status=running" | wc -l)
        local total_containers
        total_containers=$(docker-compose config --services | wc -l)
        docker_status="$running_containers/$total_containers"
    fi
    
    cat > "$summary_file" << EOF
{
    "restart": {
        "timestamp": "$(date -Iseconds)",
        "systemd_service": "$systemd_status",
        "docker_containers": "$docker_status",
        "options": {
            "force": $FORCE,
            "drain": $DRAIN,
            "update": $UPDATE,
            "health_check": $HEALTH_CHECK,
            "wait_timeout": $WAIT_TIMEOUT
        }
    },
    "system": $(get_system_info)
}
EOF
    
    log_info "Restart summary: $summary_file"
}

display_restart_status() {
    log_section "Restart Status"
    
    if [[ "$DOCKER_ONLY" != true ]]; then
        log_info "Systemd Service:"
        systemctl status github-runner.service --no-pager --lines=3 || true
    fi
    
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log_info "Docker Containers:"
        cd "$PROJECT_ROOT"
        docker-compose ps
    fi
    
    # Display runner information
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ -f "$install_path/.runner" ]] && [[ "$DOCKER_ONLY" != true ]]; then
        local runner_info
        runner_info=$(cat "$install_path/.runner" 2>/dev/null | jq -r '.agentName // "unknown"' 2>/dev/null || echo "unknown")
        log_info "Runner name: $runner_info"
        
        local repo_info
        repo_info=$(cat "$install_path/.runner" 2>/dev/null | jq -r '.repositoryUrl // "unknown"' 2>/dev/null || echo "unknown")
        log_info "Repository: $repo_info"
    fi
    
    log_info ""
    log_info "Management Commands:"
    log_info "  Status:  $SCRIPT_DIR/status.sh"
    log_info "  Stop:    $SCRIPT_DIR/stop.sh"
    log_info "  Health:  $SCRIPT_DIR/health-check.sh"
    log_info "  Monitor: $SCRIPT_DIR/monitor.sh"
}

main() {
    local lock_file="/var/lock/github-runner-restart.lock"
    
    if ! lock_script "$lock_file" 10; then
        log_error "Another restart operation is in progress"
        exit 1
    fi
    
    trap 'unlock_script "$lock_file"' EXIT
    
    log_section "GitHub Actions Runner Restart"
    
    if [[ "$FORCE" == true ]]; then
        log_warn "Using force mode"
    fi
    if [[ "$DRAIN" == true ]]; then
        log_info "Using drain mode"
    fi
    if [[ "$UPDATE" == true ]]; then
        log_info "Updating components"
    fi
    if [[ "$HEALTH_CHECK" == true ]]; then
        log_info "Running health check after restart"
    fi
    
    check_prerequisites
    load_configuration
    check_current_status
    pre_restart_checks
    create_restart_backup
    update_components
    stop_services
    start_services
    run_post_restart_validation
    create_restart_summary
    display_restart_status
    
    log_section "Restart Completed Successfully"
    send_notification "success" "GitHub Runner Restarted" "GitHub Actions runner restarted successfully on $(hostname)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi