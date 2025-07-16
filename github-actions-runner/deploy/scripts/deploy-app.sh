#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-dev}"
VERSION="${2:-latest}"

log_info "Deploying application for environment: $ENVIRONMENT, version: $VERSION"

backup_current_deployment() {
    log_info "Backing up current deployment"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR}/version-$VERSION"
    mkdir -p "$backup_dir"
    
    # Backup configuration
    cp -r "$SCRIPT_DIR/../infrastructure" "$backup_dir/"
    cp -r "$SCRIPT_DIR/../environments" "$backup_dir/"
    
    # Backup Docker images
    local images=(
        "github-runner:$VERSION"
        "monitoring:$VERSION"
        "nginx:alpine"
    )
    
    for image in "${images[@]}"; do
        if docker image inspect "$image" &>/dev/null; then
            docker save "$image" >> "$backup_dir/images.tar"
        fi
    done
    
    log_success "Current deployment backed up to: $backup_dir"
}

pull_application_images() {
    log_info "Pulling application images"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local images=(
        "github-runner:$VERSION"
        "monitoring:$VERSION"
        "nginx:alpine"
        "redis:alpine"
        "postgres:13"
    )
    
    for image in "${images[@]}"; do
        if docker pull "$image"; then
            log_success "Pulled image: $image"
        else
            log_error "Failed to pull image: $image"
            return 1
        fi
    done
}

build_custom_images() {
    log_info "Building custom images"
    
    local dockerfile_dir="$SCRIPT_DIR/../infrastructure/docker"
    
    if [[ -d "$dockerfile_dir" ]]; then
        cd "$dockerfile_dir"
        
        if [[ -f "Dockerfile.runner" ]]; then
            docker build -f Dockerfile.runner -t "github-runner:$VERSION" .
            log_success "Built custom runner image"
        fi
        
        if [[ -f "Dockerfile.monitoring" ]]; then
            docker build -f Dockerfile.monitoring -t "monitoring:$VERSION" .
            log_success "Built custom monitoring image"
        fi
        
        cd "$SCRIPT_DIR"
    else
        log_warn "Docker build directory not found: $dockerfile_dir"
    fi
}

deploy_database() {
    log_info "Deploying database"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if [[ "$DATABASE_URL" == postgresql* ]]; then
        local db_compose="$SCRIPT_DIR/../infrastructure/database/docker-compose.yml"
        
        if [[ -f "$db_compose" ]]; then
            docker-compose -f "$db_compose" up -d
            
            # Wait for database to be ready
            wait_for_service "postgresql" "postgresql://localhost:5432" 60
            
            # Run migrations
            if [[ -f "$SCRIPT_DIR/../infrastructure/database/migrations.sql" ]]; then
                docker exec -i postgres psql -U postgres -d github_runner < "$SCRIPT_DIR/../infrastructure/database/migrations.sql"
                log_success "Database migrations completed"
            fi
        fi
    fi
}

deploy_redis() {
    log_info "Deploying Redis"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if [[ "$REDIS_URL" == redis* ]]; then
        local redis_compose="$SCRIPT_DIR/../infrastructure/redis/docker-compose.yml"
        
        if [[ -f "$redis_compose" ]]; then
            docker-compose -f "$redis_compose" up -d
            
            # Wait for Redis to be ready
            wait_for_service "redis" "redis://localhost:6379" 30
            
            log_success "Redis deployment completed"
        fi
    fi
}

deploy_application_containers() {
    log_info "Deploying application containers"
    
    local compose_file="$SCRIPT_DIR/../infrastructure/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        # Start containers in dependency order
        docker-compose -f "$compose_file" up -d --remove-orphans
        
        log_success "Application containers deployed"
    else
        log_error "Docker compose file not found: $compose_file"
        return 1
    fi
}

register_github_runners() {
    log_info "Registering GitHub runners"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local runner_count="$GITHUB_RUNNER_COUNT"
    
    for ((i=1; i<=runner_count; i++)); do
        local runner_name="runner-$i"
        local container_name="github-runner-$i"
        
        log_info "Registering runner: $runner_name"
        
        # Get registration token
        local reg_token
        reg_token=$(curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/$GITHUB_ORG/actions/runners/registration-token" | \
            jq -r .token)
        
        if [[ -n "$reg_token" ]] && [[ "$reg_token" != "null" ]]; then
            # Register runner
            docker exec "$container_name" ./config.sh \
                --url "https://github.com/$GITHUB_ORG" \
                --token "$reg_token" \
                --name "$runner_name" \
                --labels "$GITHUB_RUNNER_LABELS" \
                --unattended \
                --replace
            
            log_success "Runner registered: $runner_name"
        else
            log_error "Failed to get registration token for runner: $runner_name"
            return 1
        fi
    done
}

configure_load_balancer() {
    log_info "Configuring load balancer"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local nginx_config="$SCRIPT_DIR/../infrastructure/nginx/nginx.conf"
    
    if [[ -f "$nginx_config" ]]; then
        docker-compose -f "$SCRIPT_DIR/../infrastructure/nginx/docker-compose.yml" up -d
        
        # Wait for Nginx to be ready
        wait_for_service "nginx" "http://localhost:80" 30
        
        log_success "Load balancer configured"
    else
        log_warn "Nginx configuration not found: $nginx_config"
    fi
}

configure_monitoring() {
    log_info "Configuring monitoring"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local monitoring_compose="$SCRIPT_DIR/../infrastructure/monitoring/docker-compose.yml"
    
    if [[ -f "$monitoring_compose" ]]; then
        docker-compose -f "$monitoring_compose" up -d
        
        # Wait for monitoring services to be ready
        wait_for_service "prometheus" "http://localhost:$MONITORING_PORT" 60
        wait_for_service "grafana" "http://localhost:3000" 60
        
        log_success "Monitoring configured"
    else
        log_warn "Monitoring configuration not found: $monitoring_compose"
    fi
}

configure_logging() {
    log_info "Configuring logging"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    # Configure log aggregation
    local fluentd_config="$SCRIPT_DIR/../infrastructure/logging/fluentd.conf"
    
    if [[ -f "$fluentd_config" ]]; then
        docker-compose -f "$SCRIPT_DIR/../infrastructure/logging/docker-compose.yml" up -d
        
        log_success "Logging configured"
    else
        log_warn "Logging configuration not found: $fluentd_config"
    fi
}

run_post_deployment_tasks() {
    log_info "Running post-deployment tasks"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    # Warm up services
    local services=(
        "http://localhost:$GITHUB_RUNNER_PORT/health"
        "http://localhost:$MONITORING_PORT/metrics"
        "http://localhost:$METRICS_PORT/metrics"
    )
    
    for service in "${services[@]}"; do
        retry_command 3 5 curl -s "$service" > /dev/null || true
    done
    
    # Initialize data
    if [[ -f "$SCRIPT_DIR/../scripts/init-data.sh" ]]; then
        "$SCRIPT_DIR/../scripts/init-data.sh" "$ENVIRONMENT"
    fi
    
    log_success "Post-deployment tasks completed"
}

verify_deployment() {
    log_info "Verifying deployment"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    # Check container health
    local containers
    containers=$(docker ps --filter "label=github-runner" --format "{{.Names}}")
    
    local healthy_containers=0
    for container in $containers; do
        if docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            ((healthy_containers++))
        fi
    done
    
    log_info "Healthy containers: $healthy_containers"
    
    # Check service endpoints
    local failed_checks=0
    local endpoints=(
        "http://localhost:$GITHUB_RUNNER_PORT/health"
        "http://localhost:$MONITORING_PORT/api/v1/query"
        "http://localhost:$METRICS_PORT/metrics"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if ! curl -s -f "$endpoint" > /dev/null; then
            log_error "Health check failed: $endpoint"
            ((failed_checks++))
        fi
    done
    
    if (( failed_checks > 0 )); then
        log_error "Deployment verification failed: $failed_checks checks failed"
        return 1
    fi
    
    log_success "Deployment verification completed successfully"
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    backup_current_deployment
    pull_application_images
    build_custom_images
    deploy_database
    deploy_redis
    deploy_application_containers
    register_github_runners
    configure_load_balancer
    configure_monitoring
    configure_logging
    run_post_deployment_tasks
    verify_deployment
    
    log_success "Application deployment completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi