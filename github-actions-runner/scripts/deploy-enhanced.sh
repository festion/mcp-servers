#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-deploy.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy GitHub Actions runner environment

OPTIONS:
    -h, --help              Show this help message
    -e, --environment ENV   Environment (dev|staging|prod) [default: dev]
    -c, --config-file FILE  Configuration file path
    --skip-backup           Skip initial backup creation
    --skip-health-check     Skip health checks
    --force                 Force deployment even if issues detected
    -v, --verbose           Verbose output

Examples:
    $0 --environment prod
    $0 --config-file /custom/config.env --force
EOF
}

ENVIRONMENT="dev"
CONFIG_FILE=""
SKIP_BACKUP=false
SKIP_HEALTH_CHECK=false
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-health-check)
            SKIP_HEALTH_CHECK=true
            shift
            ;;
        --force)
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

load_configuration() {
    log_section "Configuration Loading"
    
    local config_file
    if [[ -n "$CONFIG_FILE" ]]; then
        config_file="$CONFIG_FILE"
    else
        config_file="/etc/github-runner/config.env"
        if [[ ! -f "$config_file" ]]; then
            config_file="$PROJECT_ROOT/config/runner.env"
        fi
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    log_info "Loading configuration from: $config_file"
    
    set -a
    source "$config_file"
    set +a
    
    log_success "Configuration loaded successfully"
}

validate_configuration() {
    log_section "Configuration Validation"
    
    local required_vars=(
        "REPO"
        "USER"
        "INSTALL_PATH"
        "ENVIRONMENT"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required variable $var is not set"
            exit 1
        fi
    done
    
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        exit 1
    fi
    
    log_success "Configuration validation passed"
}

check_prerequisites() {
    log_section "Prerequisites Check"
    
    if ! check_command docker docker.io; then
        exit 1
    fi
    
    if ! check_command systemctl systemd; then
        exit 1
    fi
    
    if ! check_command jq jq; then
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check if user exists and has proper permissions
    if ! id "$USER" >/dev/null 2>&1; then
        log_error "User $USER does not exist"
        exit 1
    fi
    
    if ! groups "$USER" | grep -q docker; then
        log_error "User $USER is not in the docker group"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

pre_deployment_checks() {
    log_section "Pre-Deployment Checks"
    
    # Check disk space
    if ! check_disk_space "$INSTALL_PATH" 80; then
        if [[ "$FORCE" != true ]]; then
            log_error "Insufficient disk space. Use --force to override"
            exit 1
        else
            log_warn "Proceeding despite low disk space (--force used)"
        fi
    fi
    
    # Check memory usage
    if ! check_memory_usage 80; then
        if [[ "$FORCE" != true ]]; then
            log_error "High memory usage detected. Use --force to override"
            exit 1
        else
            log_warn "Proceeding despite high memory usage (--force used)"
        fi
    fi
    
    # Check if GitHub is reachable
    if ! curl -s --connect-timeout 10 https://api.github.com/rate_limit >/dev/null; then
        log_error "Cannot reach GitHub API"
        exit 1
    fi
    
    log_success "Pre-deployment checks passed"
}

stop_existing_services() {
    log_section "Stopping Existing Services"
    
    # Stop systemd service if running
    if systemctl is-active github-runner.service >/dev/null 2>&1; then
        log_info "Stopping existing systemd service..."
        systemctl stop github-runner.service
        
        # Wait for service to stop
        if ! wait_for_service github-runner.service 30; then
            log_warn "Service did not stop gracefully, forcing stop"
            systemctl kill github-runner.service
        fi
    fi
    
    # Stop Docker containers if running
    if command -v docker-compose >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log_info "Stopping existing Docker containers..."
        cd "$PROJECT_ROOT"
        docker-compose down --remove-orphans --timeout 30
    fi
    
    log_success "Existing services stopped"
}

backup_current_configuration() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        log_info "Skipping backup creation"
        return 0
    fi
    
    log_section "Configuration Backup"
    
    local backup_dir="/var/backups/github-runner/pre-deploy-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup configuration files
    if [[ -d "/etc/github-runner" ]]; then
        cp -r "/etc/github-runner" "$backup_dir/"
        log_info "Backed up /etc/github-runner"
    fi
    
    # Backup installation directory if it exists
    if [[ -d "$INSTALL_PATH" ]]; then
        tar -czf "$backup_dir/install-path.tar.gz" -C "$(dirname "$INSTALL_PATH")" "$(basename "$INSTALL_PATH")"
        log_info "Backed up installation directory"
    fi
    
    # Backup systemd service
    if [[ -f "/etc/systemd/system/github-runner.service" ]]; then
        cp "/etc/systemd/system/github-runner.service" "$backup_dir/"
        log_info "Backed up systemd service file"
    fi
    
    log_success "Configuration backup completed: $backup_dir"
    echo "$backup_dir" > /var/lib/github-runner/last-backup
}

deploy_runner_binary() {
    log_section "Runner Binary Deployment"
    
    if [[ ! -d "$INSTALL_PATH" ]]; then
        log_error "Installation path does not exist: $INSTALL_PATH"
        log_info "Run setup script first"
        exit 1
    fi
    
    # Check if runner is already configured
    if [[ -f "$INSTALL_PATH/.runner" ]]; then
        log_info "Runner already configured, checking for updates..."
        
        cd "$INSTALL_PATH"
        local current_version
        current_version=$(./config.sh --version 2>/dev/null | grep -o 'v[0-9.]*' || echo "unknown")
        
        local latest_version
        latest_version=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
        
        if [[ "$current_version" != "$latest_version" ]]; then
            log_info "Updating runner from $current_version to $latest_version"
            
            # Download new version
            local runner_arch="x64"
            if [[ $(uname -m) == "aarch64" ]]; then
                runner_arch="arm64"
            fi
            
            local download_url="https://github.com/actions/runner/releases/download/${latest_version}/actions-runner-linux-${runner_arch}-${latest_version#v}.tar.gz"
            
            # Stop runner before update
            sudo -u "$USER" ./svc.sh stop 2>/dev/null || true
            
            # Download and extract new version
            wget -q "$download_url" -O "actions-runner-new.tar.gz"
            sudo -u "$USER" tar xzf "actions-runner-new.tar.gz"
            rm "actions-runner-new.tar.gz"
            
            log_success "Runner updated to $latest_version"
        else
            log_info "Runner is already at latest version: $current_version"
        fi
    else
        log_error "Runner not configured. Run setup script first"
        exit 1
    fi
}

configure_systemd_service() {
    log_section "Systemd Service Configuration"
    
    # Create service file
    cat > /etc/systemd/system/github-runner.service << EOF
[Unit]
Description=GitHub Actions Runner
After=network.target docker.service
Wants=docker.service

[Service]
Type=notify
User=$USER
Group=$USER
WorkingDirectory=$INSTALL_PATH
Environment=HOME=/home/$USER
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$INSTALL_PATH/run.sh
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
Restart=always
RestartSec=10
TimeoutStopSec=30
TimeoutStartSec=300
StandardOutput=journal
StandardError=journal
SyslogIdentifier=github-runner

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$INSTALL_PATH /var/log/github-runner /var/lib/github-runner /var/cache/github-runner
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable github-runner.service
    
    log_success "Systemd service configured"
}

start_services() {
    log_section "Starting Services"
    
    # Start the main service
    systemctl start github-runner.service
    
    if wait_for_service github-runner.service 60; then
        log_success "GitHub runner service started successfully"
    else
        log_error "GitHub runner service failed to start"
        systemctl status github-runner.service
        journalctl -u github-runner.service --no-pager -n 50
        exit 1
    fi
    
    # Start Docker containers if docker-compose.yml exists
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log_info "Starting Docker containers..."
        cd "$PROJECT_ROOT"
        docker-compose up -d
        
        sleep 10
        
        # Check container health
        local failed_containers=()
        while IFS= read -r container; do
            if ! docker ps --format "{{.Names}}" | grep -q "^$container$"; then
                failed_containers+=("$container")
            fi
        done < <(docker-compose config --services)
        
        if [[ ${#failed_containers[@]} -gt 0 ]]; then
            log_error "Failed containers: ${failed_containers[*]}"
            docker-compose logs
            exit 1
        fi
        
        log_success "Docker containers started successfully"
    fi
}

run_post_deployment_checks() {
    if [[ "$SKIP_HEALTH_CHECK" == true ]]; then
        log_info "Skipping health checks"
        return 0
    fi
    
    log_section "Post-Deployment Health Checks"
    
    # Check service status
    if ! systemctl is-active github-runner.service >/dev/null 2>&1; then
        log_error "GitHub runner service is not active"
        exit 1
    fi
    
    # Check runner registration
    local max_wait=120
    local count=0
    
    log_info "Waiting for runner to register with GitHub..."
    
    while [[ $count -lt $max_wait ]]; do
        if cd "$INSTALL_PATH" && sudo -u "$USER" ./config.sh --check >/dev/null 2>&1; then
            log_success "Runner successfully registered with GitHub"
            break
        fi
        
        sleep 5
        ((count += 5))
        
        if [[ $((count % 30)) -eq 0 ]]; then
            log_info "Still waiting for registration... ($count/$max_wait seconds)"
        fi
    done
    
    if [[ $count -ge $max_wait ]]; then
        log_error "Runner failed to register within $max_wait seconds"
        exit 1
    fi
    
    # Run health check script if available
    local health_script="$SCRIPT_DIR/health-check.sh"
    if [[ -x "$health_script" ]]; then
        if "$health_script" --quick; then
            log_success "Health checks passed"
        else
            log_error "Health checks failed"
            exit 1
        fi
    fi
    
    log_success "Post-deployment checks completed"
}

setup_monitoring_and_logging() {
    log_section "Monitoring and Logging Setup"
    
    # Setup log rotation
    cat > /etc/logrotate.d/github-runner << EOF
/var/log/github-runner/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
    postrotate
        systemctl reload-or-restart github-runner.service || true
    endscript
}
EOF
    
    # Setup monitoring cron job
    local cron_job="*/5 * * * * root $SCRIPT_DIR/monitor.sh check >> /var/log/github-runner/monitor.log 2>&1"
    
    if ! grep -q "monitor.sh" /etc/crontab 2>/dev/null; then
        echo "$cron_job" >> /etc/crontab
        log_info "Added monitoring cron job"
    fi
    
    # Create monitoring alerts script
    cat > /usr/local/bin/github-runner-alert << 'EOF'
#!/bin/bash
source /home/dev/workspace/github-actions-runner/scripts/common/logging.sh
source /home/dev/workspace/github-actions-runner/scripts/common/utils.sh

case "$1" in
    service-down)
        send_notification "error" "GitHub Runner Service Down" "The GitHub Actions runner service has stopped on $(hostname)"
        ;;
    disk-space-low)
        send_notification "warning" "Low Disk Space" "Disk space is running low on $(hostname): $2"
        ;;
    memory-high)
        send_notification "warning" "High Memory Usage" "Memory usage is high on $(hostname): $2"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/github-runner-alert
    
    log_success "Monitoring and logging setup completed"
}

create_deployment_summary() {
    log_section "Deployment Summary"
    
    local system_info
    system_info=$(get_system_info)
    
    cat > /var/lib/github-runner/deployment-summary.json << EOF
{
    "deployment": {
        "timestamp": "$(date -Iseconds)",
        "environment": "$ENVIRONMENT",
        "version": "$(cd "$INSTALL_PATH" && sudo -u "$USER" ./config.sh --version 2>/dev/null || echo 'unknown')",
        "user": "$USER",
        "install_path": "$INSTALL_PATH",
        "repository": "${REPO:-unknown}"
    },
    "system": $system_info,
    "services": {
        "github_runner": "$(get_service_status github-runner.service)",
        "docker": "$(get_service_status docker.service)"
    }
}
EOF
    
    log_info "Deployment summary created: /var/lib/github-runner/deployment-summary.json"
}

display_deployment_info() {
    log_section "Deployment Information"
    
    log_info "Environment: $ENVIRONMENT"
    log_info "Repository: ${REPO:-Not configured}"
    log_info "Runner User: $USER"
    log_info "Installation Path: $INSTALL_PATH"
    log_info "Service Status: $(get_service_status github-runner.service)"
    
    log_info ""
    log_info "Management Commands:"
    log_info "  Status:    systemctl status github-runner"
    log_info "  Stop:      systemctl stop github-runner"
    log_info "  Start:     systemctl start github-runner"
    log_info "  Restart:   systemctl restart github-runner"
    log_info "  Logs:      journalctl -u github-runner -f"
    log_info "  Health:    $SCRIPT_DIR/health-check.sh"
    log_info "  Monitor:   $SCRIPT_DIR/monitor.sh"
    
    log_info ""
    log_info "Next Steps:"
    log_info "1. Verify runner appears in GitHub repository settings"
    log_info "2. Test with a simple workflow"
    log_info "3. Configure monitoring dashboards"
    log_info "4. Schedule regular backups"
}

cleanup_deployment() {
    log_section "Deployment Cleanup"
    
    # Clean up temporary files
    rm -f /tmp/github-runner-*
    
    # Clean up old logs if they exist
    cleanup_old_files "/var/log/github-runner" "*.log.*.gz" 30
    
    log_success "Deployment cleanup completed"
}

main() {
    local lock_file="/var/lock/github-runner-deploy.lock"
    
    if ! lock_script "$lock_file"; then
        log_error "Another deployment process is running"
        exit 1
    fi
    
    trap 'unlock_script "$lock_file"' EXIT
    
    log_section "GitHub Actions Runner Deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Force mode: $FORCE"
    
    load_configuration
    validate_configuration
    check_prerequisites
    pre_deployment_checks
    backup_current_configuration
    stop_existing_services
    deploy_runner_binary
    configure_systemd_service
    start_services
    run_post_deployment_checks
    setup_monitoring_and_logging
    create_deployment_summary
    cleanup_deployment
    display_deployment_info
    
    log_section "Deployment Completed Successfully"
    send_notification "success" "GitHub Runner Deployment Complete" "Runner deployment completed successfully on $(hostname) for environment: $ENVIRONMENT"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi