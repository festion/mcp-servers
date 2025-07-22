#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-dev}"
ROLLBACK_VERSION="${2:-}"

log_info "Starting rollback procedure for environment: $ENVIRONMENT"

if [[ -z "$ROLLBACK_VERSION" ]]; then
    log_error "Rollback version is required"
    exit 1
fi

validate_rollback_prerequisites() {
    log_info "Validating rollback prerequisites"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        exit 1
    fi
    
    local version_backup="$backup_dir/version-$ROLLBACK_VERSION"
    
    if [[ ! -d "$version_backup" ]]; then
        log_error "Version backup not found: $version_backup"
        exit 1
    fi
    
    log_success "Rollback prerequisites validated"
}

create_rollback_checkpoint() {
    log_info "Creating rollback checkpoint"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    local current_version
    current_version=$(cat "$SCRIPT_DIR/../environments/$ENVIRONMENT.current" 2>/dev/null || echo "unknown")
    
    local checkpoint_dir="$backup_dir/checkpoint-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$checkpoint_dir"
    
    # Backup current configuration
    cp -r "$SCRIPT_DIR/../infrastructure/" "$checkpoint_dir/"
    
    # Backup current version info
    echo "$current_version" > "$checkpoint_dir/version"
    
    # Backup container state
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > "$checkpoint_dir/containers.txt"
    
    log_success "Rollback checkpoint created: $checkpoint_dir"
}

stop_current_services() {
    log_info "Stopping current services"
    
    local compose_file="$SCRIPT_DIR/../infrastructure/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        docker-compose -f "$compose_file" down --timeout 30
        log_success "Services stopped successfully"
    else
        log_warn "Docker compose file not found, attempting to stop containers manually"
        
        local containers
        containers=$(docker ps --filter "label=github-runner" --format "{{.Names}}")
        
        if [[ -n "$containers" ]]; then
            echo "$containers" | xargs docker stop
            log_success "Containers stopped manually"
        fi
    fi
}

restore_configuration() {
    log_info "Restoring configuration for version: $ROLLBACK_VERSION"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    local version_backup="$backup_dir/version-$ROLLBACK_VERSION"
    
    if [[ -d "$version_backup/infrastructure" ]]; then
        cp -r "$version_backup/infrastructure/"* "$SCRIPT_DIR/../infrastructure/"
        log_success "Infrastructure configuration restored"
    fi
    
    if [[ -d "$version_backup/environments" ]]; then
        cp -r "$version_backup/environments/"* "$SCRIPT_DIR/../environments/"
        log_success "Environment configuration restored"
    fi
    
    if [[ -f "$version_backup/docker-compose.yml" ]]; then
        cp "$version_backup/docker-compose.yml" "$SCRIPT_DIR/../infrastructure/"
        log_success "Docker compose configuration restored"
    fi
}

restore_application_images() {
    log_info "Restoring application images for version: $ROLLBACK_VERSION"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    local version_backup="$backup_dir/version-$ROLLBACK_VERSION"
    
    if [[ -f "$version_backup/images.tar" ]]; then
        log_info "Loading Docker images from backup"
        docker load -i "$version_backup/images.tar"
        log_success "Docker images restored"
    else
        log_warn "No Docker images backup found, pulling from registry"
        
        local images=(
            "github-runner:$ROLLBACK_VERSION"
            "monitoring:$ROLLBACK_VERSION"
        )
        
        for image in "${images[@]}"; do
            if docker pull "$image" 2>/dev/null; then
                log_success "Pulled image: $image"
            else
                log_warn "Failed to pull image: $image"
            fi
        done
    fi
}

start_rollback_services() {
    log_info "Starting services with rolled back configuration"
    
    local compose_file="$SCRIPT_DIR/../infrastructure/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        docker-compose -f "$compose_file" up -d
        log_success "Services started successfully"
    else
        log_error "Docker compose file not found after rollback"
        exit 1
    fi
}

verify_rollback_success() {
    log_info "Verifying rollback success"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    # Wait for services to be ready
    sleep 10
    
    local services=(
        "github-runner-1:$GITHUB_RUNNER_PORT"
        "github-runner-2:$((GITHUB_RUNNER_PORT + 1))"
        "monitoring:$MONITORING_PORT"
    )
    
    local failed_services=0
    
    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local service_port="${service##*:}"
        
        if wait_for_service "$service_name" "http://localhost:$service_port/health" 60; then
            log_success "Service $service_name is healthy after rollback"
        else
            log_error "Service $service_name failed health check after rollback"
            ((failed_services++))
        fi
    done
    
    if (( failed_services > 0 )); then
        log_error "Rollback verification failed: $failed_services services are unhealthy"
        return 1
    fi
    
    log_success "Rollback verification completed successfully"
}

update_version_tracking() {
    log_info "Updating version tracking"
    
    local version_file="$SCRIPT_DIR/../environments/$ENVIRONMENT.current"
    echo "$ROLLBACK_VERSION" > "$version_file"
    
    local rollback_log="$SCRIPT_DIR/../logs/rollbacks.log"
    mkdir -p "$(dirname "$rollback_log")"
    
    cat >> "$rollback_log" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$ENVIRONMENT",
    "rollback_version": "$ROLLBACK_VERSION",
    "user": "$(whoami)",
    "status": "success"
}
EOF
    
    log_success "Version tracking updated"
}

cleanup_rollback_resources() {
    log_info "Cleaning up rollback resources"
    
    # Remove unused Docker images
    docker image prune -f
    
    # Remove old containers
    docker container prune -f
    
    log_success "Rollback resources cleaned up"
}

generate_rollback_report() {
    log_info "Generating rollback report"
    
    local report_file="/tmp/rollback-report-$ENVIRONMENT-$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "environment": "$ENVIRONMENT",
    "rollback_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "rollback_version": "$ROLLBACK_VERSION",
    "rollback_status": "successful",
    "services_status": {
        "github_runners": "$(docker ps --filter 'name=github-runner' --format '{{.Names}}' | wc -l)",
        "containers_running": "$(docker ps --filter 'status=running' | wc -l)",
        "total_containers": "$(docker ps -a | wc -l)"
    },
    "verification": {
        "health_checks": "passed",
        "service_availability": "passed",
        "configuration_restored": "passed"
    },
    "rollback_procedure": {
        "prerequisites_validated": "passed",
        "checkpoint_created": "passed",
        "services_stopped": "passed",
        "configuration_restored": "passed",
        "images_restored": "passed",
        "services_started": "passed",
        "verification_completed": "passed"
    }
}
EOF
    
    log_success "Rollback report generated: $report_file"
}

send_rollback_notification() {
    log_info "Sending rollback notification"
    
    local message="🔄 Rollback completed successfully for $ENVIRONMENT environment (v$ROLLBACK_VERSION)"
    
    send_notification "$message" "success"
}

main() {
    validate_rollback_prerequisites
    create_rollback_checkpoint
    stop_current_services
    restore_configuration
    restore_application_images
    start_rollback_services
    verify_rollback_success
    update_version_tracking
    cleanup_rollback_resources
    generate_rollback_report
    send_rollback_notification
    
    log_success "Rollback procedure completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi