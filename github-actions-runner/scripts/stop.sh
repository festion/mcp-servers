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

Stop GitHub Actions runner services gracefully

OPTIONS:
    -h, --help          Show this help message
    -s, --service-only  Stop only systemd service (no Docker)
    -d, --docker-only   Stop only Docker containers (no systemd)
    -w, --wait SECONDS  Wait timeout for graceful shutdown [default: 30]
    -f, --force         Force stop (kill) if graceful stop fails
    -k, --kill          Immediate kill (no graceful stop)
    --drain             Drain jobs before stopping
    -v, --verbose       Verbose output

Examples:
    $0                  # Stop all services gracefully
    $0 --force          # Force stop if graceful fails
    $0 --drain          # Wait for current jobs to finish
    $0 --service-only   # Stop only systemd service
EOF
}

SERVICE_ONLY=false
DOCKER_ONLY=false
WAIT_TIMEOUT=30
FORCE=false
KILL=false
DRAIN=false
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
        -k|--kill)
            KILL=true
            shift
            ;;
        --drain)
            DRAIN=true
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

if [[ "$KILL" == true ]] && [[ "$DRAIN" == true ]]; then
    log_error "Cannot specify both --kill and --drain"
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
    fi
    
    log_success "Prerequisites check passed"
}

check_current_status() {
    log_section "Current Status Check"
    
    local systemd_status="unknown"
    local docker_status="unknown"
    local has_running_services=false
    
    if [[ "$DOCKER_ONLY" != true ]]; then
        if systemctl is-active github-runner.service >/dev/null 2>&1; then
            systemd_status="running"
            has_running_services=true
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
        
        if [[ $running_containers -gt 0 ]]; then
            docker_status="running"
            has_running_services=true
        else
            docker_status="stopped"
        fi
        
        log_info "Docker containers status: $docker_status ($running_containers/$total_containers running)"
    fi
    
    if [[ "$has_running_services" == false ]]; then
        log_info "No services are currently running"
        exit 0
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

check_running_jobs() {
    if [[ "$DOCKER_ONLY" == true ]] || [[ "$DRAIN" != true ]]; then
        return 0
    fi
    
    log_section "Running Jobs Check"
    
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ ! -d "$install_path" ]]; then
        log_warn "Installation directory not found: $install_path"
        return 0
    fi
    
    # Check if there are any running jobs
    local job_count=0
    if [[ -d "$install_path/_work" ]]; then
        job_count=$(find "$install_path/_work" -name "*.pid" 2>/dev/null | wc -l)
    fi
    
    if [[ $job_count -gt 0 ]]; then
        log_info "Found $job_count running job(s)"
        
        if [[ "$DRAIN" == true ]]; then
            log_info "Waiting for jobs to complete (drain mode)..."
            
            local max_drain_wait=1800  # 30 minutes max
            local count=0
            
            while [[ $count -lt $max_drain_wait ]]; do
                job_count=$(find "$install_path/_work" -name "*.pid" 2>/dev/null | wc -l)
                
                if [[ $job_count -eq 0 ]]; then
                    log_success "All jobs completed"
                    break
                fi
                
                sleep 10
                ((count += 10))
                
                if [[ $((count % 60)) -eq 0 ]]; then
                    log_info "Still waiting for $job_count job(s) to complete... ($((count/60)) minutes elapsed)"
                fi
            done
            
            if [[ $count -ge $max_drain_wait ]]; then
                log_warn "Drain timeout reached. Proceeding with shutdown."
            fi
        else
            log_warn "Jobs are running but not draining. They will be terminated."
        fi
    else
        log_info "No running jobs detected"
    fi
}

stop_systemd_service() {
    if [[ "$DOCKER_ONLY" == true ]]; then
        return 0
    fi
    
    log_section "Stopping Systemd Service"
    
    if ! systemctl is-active github-runner.service >/dev/null 2>&1; then
        log_info "Systemd service is already stopped"
        return 0
    fi
    
    if [[ "$KILL" == true ]]; then
        log_info "Killing GitHub runner systemd service..."
        systemctl kill github-runner.service
        sleep 2
    else
        log_info "Stopping GitHub runner systemd service..."
        systemctl stop github-runner.service
        
        if wait_for_service_stop github-runner.service "$WAIT_TIMEOUT"; then
            log_success "Systemd service stopped gracefully"
        else
            if [[ "$FORCE" == true ]]; then
                log_warn "Graceful stop failed, forcing kill..."
                systemctl kill github-runner.service
                sleep 5
                
                if ! systemctl is-active github-runner.service >/dev/null 2>&1; then
                    log_success "Systemd service killed successfully"
                else
                    log_error "Failed to kill systemd service"
                    exit 1
                fi
            else
                log_error "Systemd service failed to stop within $WAIT_TIMEOUT seconds"
                log_info "Use --force to kill the service"
                exit 1
            fi
        fi
    fi
    
    # Verify the service is stopped
    if systemctl is-active github-runner.service >/dev/null 2>&1; then
        log_error "Service is still active after stop command"
        exit 1
    fi
}

stop_docker_containers() {
    if [[ "$SERVICE_ONLY" == true ]] || [[ ! -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        return 0
    fi
    
    log_section "Stopping Docker Containers"
    
    cd "$PROJECT_ROOT"
    
    # Check if any containers are running
    local running_containers
    running_containers=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
    
    if [[ $running_containers -eq 0 ]]; then
        log_info "No Docker containers are running"
        return 0
    fi
    
    if [[ "$KILL" == true ]]; then
        log_info "Killing Docker containers..."
        docker-compose kill
        docker-compose down --remove-orphans
    else
        log_info "Stopping Docker containers gracefully..."
        docker-compose down --timeout "$WAIT_TIMEOUT"
        
        # Verify containers are stopped
        running_containers=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        
        if [[ $running_containers -gt 0 ]]; then
            if [[ "$FORCE" == true ]]; then
                log_warn "Some containers didn't stop gracefully, forcing kill..."
                docker-compose kill
                docker-compose down --remove-orphans
            else
                log_error "Some containers failed to stop within timeout"
                log_info "Use --force to kill remaining containers"
                exit 1
            fi
        fi
    fi
    
    log_success "Docker containers stopped successfully"
}

cleanup_resources() {
    log_section "Resource Cleanup"
    
    # Clean up any leftover processes
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    local user="${USER:-github-runner}"
    
    if [[ -d "$install_path" ]]; then
        # Kill any remaining runner processes
        pkill -f "$install_path/bin/Runner.Listener" -u "$user" 2>/dev/null || true
        pkill -f "$install_path/bin/Runner.Worker" -u "$user" 2>/dev/null || true
        
        # Clean up any lock files
        rm -f "$install_path/.runner_lock" 2>/dev/null || true
        
        # Clean up temporary work files
        if [[ -d "$install_path/_work" ]]; then
            find "$install_path/_work" -name "*.pid" -delete 2>/dev/null || true
            find "$install_path/_work" -name "*.lock" -delete 2>/dev/null || true
        fi
    fi
    
    # Clean up Docker volumes if requested
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        
        # Remove anonymous volumes
        docker volume prune -f >/dev/null 2>&1 || true
    fi
    
    log_success "Resource cleanup completed"
}

run_post_stop_checks() {
    log_section "Post-Stop Validation"
    
    # Verify systemd service is stopped
    if [[ "$DOCKER_ONLY" != true ]]; then
        if systemctl is-active github-runner.service >/dev/null 2>&1; then
            log_error "Systemd service is still active"
            exit 1
        else
            log_success "Systemd service is stopped"
        fi
    fi
    
    # Verify Docker containers are stopped
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        local running_containers
        running_containers=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        
        if [[ $running_containers -gt 0 ]]; then
            log_error "Some Docker containers are still running"
            docker-compose ps
            exit 1
        else
            log_success "All Docker containers are stopped"
        fi
    fi
    
    # Check for any remaining processes
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    local user="${USER:-github-runner}"
    
    local remaining_processes
    remaining_processes=$(pgrep -f "$install_path" -u "$user" 2>/dev/null | wc -l || echo 0)
    
    if [[ $remaining_processes -gt 0 ]]; then
        log_warn "$remaining_processes runner processes still running"
        pgrep -f "$install_path" -u "$user" 2>/dev/null || true
    else
        log_success "No remaining runner processes"
    fi
}

create_stop_summary() {
    log_section "Stop Summary"
    
    local summary_file="/var/lib/github-runner/last-stop.json"
    mkdir -p "$(dirname "$summary_file")"
    
    cat > "$summary_file" << EOF
{
    "stop": {
        "timestamp": "$(date -Iseconds)",
        "method": "$(if [[ "$KILL" == true ]]; then echo "kill"; elif [[ "$FORCE" == true ]]; then echo "force"; else echo "graceful"; fi)",
        "drain_used": $DRAIN,
        "wait_timeout": $WAIT_TIMEOUT,
        "service_only": $SERVICE_ONLY,
        "docker_only": $DOCKER_ONLY
    },
    "system": $(get_system_info)
}
EOF
    
    log_info "Stop summary: $summary_file"
}

display_final_status() {
    log_section "Final Status"
    
    if [[ "$DOCKER_ONLY" != true ]]; then
        local systemd_status
        systemd_status=$(get_service_status github-runner.service)
        log_info "Systemd service: $systemd_status"
    fi
    
    if [[ "$SERVICE_ONLY" != true ]] && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        local container_count
        container_count=$(docker-compose ps -q | wc -l)
        log_info "Docker containers: $container_count running"
    fi
    
    log_info ""
    log_info "Management Commands:"
    log_info "  Start:   $SCRIPT_DIR/start.sh"
    log_info "  Status:  $SCRIPT_DIR/status.sh"
    log_info "  Health:  $SCRIPT_DIR/health-check.sh"
}

wait_for_service_stop() {
    local service="$1"
    local max_wait="${2:-30}"
    local count=0
    
    log_info "Waiting for service $service to stop..."
    
    while [[ $count -lt $max_wait ]]; do
        if ! systemctl is-active "$service" >/dev/null 2>&1; then
            return 0
        fi
        
        sleep 1
        ((count++))
        
        if [[ $((count % 5)) -eq 0 ]]; then
            log_info "Still waiting for $service to stop... ($count/$max_wait)"
        fi
    done
    
    return 1
}

main() {
    local lock_file="/var/lock/github-runner-stop.lock"
    
    if ! lock_script "$lock_file" 10; then
        log_error "Another stop operation is in progress"
        exit 1
    fi
    
    trap 'unlock_script "$lock_file"' EXIT
    
    log_section "GitHub Actions Runner Stop"
    
    if [[ "$KILL" == true ]]; then
        log_warn "Using immediate kill mode"
    elif [[ "$FORCE" == true ]]; then
        log_warn "Using force mode"
    elif [[ "$DRAIN" == true ]]; then
        log_info "Using drain mode"
    fi
    
    check_prerequisites
    load_configuration
    check_current_status
    check_running_jobs
    stop_systemd_service
    stop_docker_containers
    cleanup_resources
    run_post_stop_checks
    create_stop_summary
    display_final_status
    
    log_section "Services Stopped Successfully"
    send_notification "info" "GitHub Runner Stopped" "GitHub Actions runner services stopped successfully on $(hostname)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi