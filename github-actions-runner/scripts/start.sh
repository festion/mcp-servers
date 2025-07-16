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

Start GitHub Actions runner services

OPTIONS:
    -h, --help          Show this help message
    -s, --service-only  Start only systemd service (no Docker)
    -d, --docker-only   Start only Docker containers (no systemd)
    -w, --wait SECONDS  Wait timeout for service startup [default: 60]
    -f, --force         Force start even if already running
    -v, --verbose       Verbose output

Examples:
    $0                  # Start all services
    $0 --service-only   # Start only systemd service
    $0 --wait 120       # Wait up to 120 seconds for startup
EOF
}

SERVICE_ONLY=false
DOCKER_ONLY=false
WAIT_TIMEOUT=60
FORCE=false
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
        if systemctl is-active github-runner.service >/dev/null 2>&1; then
            systemd_status="running"
        elif systemctl is-enabled github-runner.service >/dev/null 2>&1; then
            systemd_status="stopped"
        else
            systemd_status="disabled"
        fi
        
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
        
        log_info "Docker containers status: $docker_status ($running_containers/$total_containers running)"
    fi
    
    # Check if services are already running and force is not specified
    if [[ "$FORCE" != true ]]; then
        if [[ "$systemd_status" == "running" ]] && [[ "$DOCKER_ONLY" != true ]]; then
            log_warn "Systemd service is already running. Use --force to restart"
            if [[ "$SERVICE_ONLY" == true ]]; then
                exit 0
            fi
        fi
        
        if [[ "$docker_status" == "running" ]] && [[ "$SERVICE_ONLY" != true ]]; then
            log_warn "Docker containers are already running. Use --force to restart"
            if [[ "$DOCKER_ONLY" == true ]]; then
                exit 0
            fi
        fi
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

pre_start_checks() {
    log_section "Pre-Start Checks"
    
    # Check disk space
    if ! check_disk_space "/" 90; then
        log_error "Insufficient disk space to start services"
        exit 1
    fi
    
    # Check memory usage
    if ! check_memory_usage 95; then
        log_error "Insufficient memory to start services"
        exit 1
    fi
    
    # Check if installation exists
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ "$DOCKER_ONLY" != true ]] && [[ ! -d "$install_path" ]]; then
        log_error "Installation directory not found: $install_path"
        log_info "Run setup script first"
        exit 1
    fi
    
    # Check GitHub connectivity
    if ! curl -s --connect-timeout 10 https://api.github.com/rate_limit >/dev/null; then
        log_warn "Cannot reach GitHub API, but continuing startup"
    fi
    
    log_success "Pre-start checks passed"
}

start_systemd_service() {
    if [[ "$DOCKER_ONLY" == true ]]; then
        return 0
    fi
    
    log_section "Starting Systemd Service"
    
    if [[ "$FORCE" == true ]] && systemctl is-active github-runner.service >/dev/null 2>&1; then
        log_info "Stopping service for forced restart..."
        systemctl stop github-runner.service
        wait_for_service github-runner.service 30 "stopped" || {
            log_warn "Service did not stop gracefully, killing it"
            systemctl kill github-runner.service
            sleep 5
        }
    fi
    
    log_info "Starting GitHub runner systemd service..."
    systemctl start github-runner.service
    
    if wait_for_service github-runner.service "$WAIT_TIMEOUT"; then
        log_success "Systemd service started successfully"
        
        # Log service details
        local install_path="${INSTALL_PATH:-/opt/github-runner}"
        if [[ -f "$install_path/.runner" ]]; then
            local runner_info
            runner_info=$(cat "$install_path/.runner" 2>/dev/null | jq -r '.agentName // "unknown"' 2>/dev/null || echo "unknown")
            log_info "Runner name: $runner_info"
        fi
    else
        log_error "Systemd service failed to start within $WAIT_TIMEOUT seconds"
        log_info "Service status:"
        systemctl status github-runner.service --no-pager || true
        log_info "Recent logs:"
        journalctl -u github-runner.service --no-pager -n 20 || true
        exit 1
    fi
}

start_docker_containers() {
    if [[ "$SERVICE_ONLY" == true ]] || [[ ! -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        return 0
    fi
    
    log_section "Starting Docker Containers"
    
    cd "$PROJECT_ROOT"
    
    if [[ "$FORCE" == true ]]; then
        log_info "Stopping containers for forced restart..."
        docker-compose down --timeout 30 >/dev/null 2>&1 || true
    fi
    
    log_info "Pulling latest images..."
    docker-compose pull >/dev/null 2>&1 || log_warn "Failed to pull some images"
    
    log_info "Starting Docker containers..."
    docker-compose up -d
    
    # Wait for containers to be ready
    log_info "Waiting for containers to be ready..."
    local max_wait=60
    local count=0
    
    while [[ $count -lt $max_wait ]]; do
        local running_containers
        running_containers=$(docker-compose ps --services --filter "status=running" | wc -l)
        local total_containers
        total_containers=$(docker-compose config --services | wc -l)
        
        if [[ $running_containers -eq $total_containers ]]; then
            log_success "All containers started successfully ($running_containers/$total_containers)"
            break
        fi
        
        sleep 2
        ((count += 2))
        
        if [[ $((count % 10)) -eq 0 ]]; then
            log_info "Still waiting for containers... ($running_containers/$total_containers ready)"
        fi
    done
    
    if [[ $count -ge $max_wait ]]; then
        log_error "Not all containers started within $max_wait seconds"
        log_info "Container status:"
        docker-compose ps
        log_info "Container logs:"
        docker-compose logs --tail=20
        exit 1
    fi
    
    # Display container status
    log_info "Container status:"
    docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
}

run_post_start_checks() {
    log_section "Post-Start Validation"
    
    # Check systemd service health
    if [[ "$DOCKER_ONLY" != true ]]; then
        if ! systemctl is-active github-runner.service >/dev/null 2>&1; then
            log_error "Systemd service is not active after startup"
            exit 1
        fi
        
        # Check if runner is listening for jobs
        local install_path="${INSTALL_PATH:-/opt/github-runner}"
        if [[ -f "$install_path/.runner" ]]; then
            log_info "Checking runner registration..."
            
            local max_wait=30
            local count=0
            
            while [[ $count -lt $max_wait ]]; do
                if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
                    log_success "Runner is properly registered and listening"
                    break
                fi
                
                sleep 2
                ((count += 2))
            done
            
            if [[ $count -ge $max_wait ]]; then
                log_warn "Could not verify runner registration within $max_wait seconds"
            fi
        fi
    fi
    
    # Check Docker container health
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        
        local unhealthy_containers=()
        while IFS= read -r container; do
            local health_status
            health_status=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
            
            if [[ "$health_status" == "unhealthy" ]]; then
                unhealthy_containers+=("$container")
            fi
        done < <(docker-compose ps -q)
        
        if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
            log_warn "Unhealthy containers detected: ${unhealthy_containers[*]}"
        else
            log_success "All containers are healthy"
        fi
    fi
    
    # Run health check script if available
    local health_script="$SCRIPT_DIR/health-check.sh"
    if [[ -x "$health_script" ]]; then
        if "$health_script" --quick >/dev/null 2>&1; then
            log_success "Health checks passed"
        else
            log_warn "Health checks failed, but services are running"
        fi
    fi
}

create_startup_summary() {
    log_section "Startup Summary"
    
    local summary_file="/var/lib/github-runner/last-start.json"
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
    "startup": {
        "timestamp": "$(date -Iseconds)",
        "systemd_service": "$systemd_status",
        "docker_containers": "$docker_status",
        "force_used": $FORCE,
        "wait_timeout": $WAIT_TIMEOUT
    },
    "system": $(get_system_info)
}
EOF
    
    log_info "Startup summary: $summary_file"
}

display_status() {
    log_section "Service Status"
    
    if [[ "$DOCKER_ONLY" != true ]]; then
        log_info "Systemd Service:"
        systemctl status github-runner.service --no-pager --lines=5 || true
    fi
    
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log_info "Docker Containers:"
        cd "$PROJECT_ROOT"
        docker-compose ps
    fi
    
    log_info ""
    log_info "Management Commands:"
    log_info "  Status:  $SCRIPT_DIR/status.sh"
    log_info "  Stop:    $SCRIPT_DIR/stop.sh"
    log_info "  Restart: $SCRIPT_DIR/restart.sh"
    log_info "  Health:  $SCRIPT_DIR/health-check.sh"
    log_info "  Logs:    journalctl -u github-runner -f"
}

main() {
    local lock_file="/var/lock/github-runner-start.lock"
    
    if ! lock_script "$lock_file" 30; then
        log_error "Another start operation is in progress"
        exit 1
    fi
    
    trap 'unlock_script "$lock_file"' EXIT
    
    log_section "GitHub Actions Runner Start"
    
    check_prerequisites
    load_configuration
    check_current_status
    pre_start_checks
    start_systemd_service
    start_docker_containers
    run_post_start_checks
    create_startup_summary
    display_status
    
    log_section "Services Started Successfully"
    send_notification "success" "GitHub Runner Started" "GitHub Actions runner services started successfully on $(hostname)"
}

wait_for_service() {
    local service="$1"
    local max_wait="${2:-30}"
    local desired_state="${3:-active}"
    local count=0
    
    log_info "Waiting for service $service to be $desired_state..."
    
    while [[ $count -lt $max_wait ]]; do
        local current_state
        if [[ "$desired_state" == "stopped" ]]; then
            if ! systemctl is-active "$service" >/dev/null 2>&1; then
                log_success "Service $service is stopped"
                return 0
            fi
        else
            if systemctl is-active "$service" >/dev/null 2>&1; then
                log_success "Service $service is $desired_state"
                return 0
            fi
        fi
        
        sleep 1
        ((count++))
        
        if [[ $((count % 5)) -eq 0 ]]; then
            log_info "Still waiting for $service... ($count/$max_wait)"
        fi
    done
    
    log_error "Service $service failed to reach $desired_state within $max_wait seconds"
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi