#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Deploying configuration for environment: $ENVIRONMENT"

deploy_docker_compose_config() {
    log_info "Deploying Docker Compose configuration"
    
    local compose_template="$SCRIPT_DIR/../infrastructure/docker-compose.yml.template"
    local compose_file="$SCRIPT_DIR/../infrastructure/docker-compose.yml"
    
    if [[ -f "$compose_template" ]]; then
        generate_config "$compose_template" "$compose_file"
    else
        log_warn "Docker Compose template not found: $compose_template"
    fi
}

deploy_nginx_config() {
    log_info "Deploying Nginx configuration"
    
    local nginx_template="$SCRIPT_DIR/../infrastructure/nginx/nginx.conf.template"
    local nginx_config="$SCRIPT_DIR/../infrastructure/nginx/nginx.conf"
    
    if [[ -f "$nginx_template" ]]; then
        generate_config "$nginx_template" "$nginx_config"
    else
        log_warn "Nginx template not found: $nginx_template"
    fi
}

deploy_monitoring_config() {
    log_info "Deploying monitoring configuration"
    
    local prometheus_template="$SCRIPT_DIR/../infrastructure/monitoring/prometheus.yml.template"
    local prometheus_config="$SCRIPT_DIR/../infrastructure/monitoring/prometheus.yml"
    
    if [[ -f "$prometheus_template" ]]; then
        generate_config "$prometheus_template" "$prometheus_config"
    else
        log_warn "Prometheus template not found: $prometheus_template"
    fi
    
    local grafana_template="$SCRIPT_DIR/../infrastructure/monitoring/grafana.json.template"
    local grafana_config="$SCRIPT_DIR/../infrastructure/monitoring/grafana.json"
    
    if [[ -f "$grafana_template" ]]; then
        generate_config "$grafana_template" "$grafana_config"
    else
        log_warn "Grafana template not found: $grafana_template"
    fi
}

deploy_logging_config() {
    log_info "Deploying logging configuration"
    
    local logrotate_template="$SCRIPT_DIR/../infrastructure/logging/logrotate.conf.template"
    local logrotate_config="$SCRIPT_DIR/../infrastructure/logging/logrotate.conf"
    
    if [[ -f "$logrotate_template" ]]; then
        generate_config "$logrotate_template" "$logrotate_config"
    else
        log_warn "Logrotate template not found: $logrotate_template"
    fi
}

deploy_secrets() {
    log_info "Deploying secrets"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        echo "$GITHUB_TOKEN" | docker secret create github-token - 2>/dev/null || true
    fi
    
    if [[ -n "${JWT_SECRET:-}" ]]; then
        echo "$JWT_SECRET" | docker secret create jwt-secret - 2>/dev/null || true
    fi
    
    if [[ -n "${DB_PASSWORD:-}" ]]; then
        echo "$DB_PASSWORD" | docker secret create db-password - 2>/dev/null || true
    fi
}

create_directories() {
    log_info "Creating required directories"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local directories=(
        "$DATA_DIR"
        "$LOG_DIR"
        "$BACKUP_DIR"
        "${DATA_DIR}/github-runner"
        "${LOG_DIR}/github-runner"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            sudo mkdir -p "$dir"
            sudo chown -R "$DEPLOY_USER:$DEPLOY_USER" "$dir"
            log_success "Created directory: $dir"
        fi
    done
}

configure_systemd_services() {
    log_info "Configuring systemd services"
    
    local service_template="$SCRIPT_DIR/../infrastructure/systemd/github-runner.service.template"
    local service_file="/etc/systemd/system/github-runner.service"
    
    if [[ -f "$service_template" ]]; then
        sudo generate_config "$service_template" "$service_file"
        sudo systemctl daemon-reload
        sudo systemctl enable github-runner.service
        log_success "Systemd service configured"
    else
        log_warn "Systemd service template not found: $service_template"
    fi
}

configure_firewall() {
    log_info "Configuring firewall"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow "$GITHUB_RUNNER_PORT"
        sudo ufw allow "$MONITORING_PORT"
        sudo ufw allow "$METRICS_PORT"
        
        if [[ "$ENVIRONMENT" == "prod" ]]; then
            sudo ufw allow 443
            sudo ufw allow 80
        fi
        
        log_success "Firewall configured"
    else
        log_warn "UFW not available, skipping firewall configuration"
    fi
}

configure_log_rotation() {
    log_info "Configuring log rotation"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local logrotate_config="/etc/logrotate.d/github-runner"
    
    sudo tee "$logrotate_config" > /dev/null << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $DEPLOY_USER $DEPLOY_USER
    postrotate
        systemctl reload rsyslog
    endscript
}
EOF
    
    log_success "Log rotation configured"
}

configure_cron_jobs() {
    log_info "Configuring cron jobs"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local cron_jobs=(
        "0 2 * * * $SCRIPT_DIR/../scripts/backup.sh $ENVIRONMENT"
        "*/10 * * * * $SCRIPT_DIR/../validation/health-check.sh $ENVIRONMENT"
        "0 0 * * 0 $SCRIPT_DIR/../scripts/cleanup.sh $ENVIRONMENT"
    )
    
    for job in "${cron_jobs[@]}"; do
        (crontab -l 2>/dev/null; echo "$job") | crontab -
    done
    
    log_success "Cron jobs configured"
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    deploy_docker_compose_config
    deploy_nginx_config
    deploy_monitoring_config
    deploy_logging_config
    deploy_secrets
    create_directories
    configure_systemd_services
    configure_firewall
    configure_log_rotation
    configure_cron_jobs
    
    log_success "Configuration deployment completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi