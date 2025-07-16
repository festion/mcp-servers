#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-setup.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup GitHub Actions runner environment

OPTIONS:
    -h, --help              Show this help message
    -e, --environment ENV   Environment (dev|staging|prod) [default: dev]
    -r, --repo REPO         GitHub repository (format: owner/repo)
    -t, --token TOKEN       GitHub runner registration token
    -u, --user USER         User to run services as [default: github-runner]
    -p, --path PATH         Installation path [default: /opt/github-runner]
    --skip-deps             Skip dependency installation
    --skip-docker           Skip Docker setup
    --skip-monitoring       Skip monitoring setup
    -v, --verbose           Verbose output

Examples:
    $0 --environment prod --repo myorg/myrepo --token ghp_xxx
    $0 --user runner --path /home/runner/actions
EOF
}

ENVIRONMENT="dev"
REPO=""
TOKEN=""
USER="github-runner"
INSTALL_PATH="/opt/github-runner"
SKIP_DEPS=false
SKIP_DOCKER=false
SKIP_MONITORING=false
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
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -t|--token)
            TOKEN="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -p|--path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --skip-monitoring)
            SKIP_MONITORING=true
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

validate_inputs() {
    if [[ -z "$REPO" ]]; then
        log_error "Repository is required. Use --repo owner/repo"
        exit 1
    fi
    
    if [[ -z "$TOKEN" ]]; then
        log_error "GitHub token is required. Use --token ghp_xxx"
        exit 1
    fi
    
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Environment must be dev, staging, or prod"
        exit 1
    fi
    
    if [[ ! "$REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        log_error "Repository must be in format owner/repo"
        exit 1
    fi
}

check_requirements() {
    log_section "System Requirements Check"
    
    require_root
    
    check_command curl curl
    check_command systemctl systemd
    
    if ! check_command jq jq && [[ "$SKIP_DEPS" == false ]]; then
        log_warn "jq is not installed and will be installed"
    fi
    
    log_success "System requirements check passed"
}

install_dependencies() {
    if [[ "$SKIP_DEPS" == true ]]; then
        log_info "Skipping dependency installation"
        return 0
    fi
    
    log_section "Installing Dependencies"
    
    log_command "apt-get update -qq"
    log_command "apt-get install -y curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common jq unzip tar gzip git build-essential python3 python3-pip nodejs npm htop iotop net-tools tcpdump strace rsync logrotate"
    
    log_success "Dependencies installed successfully"
}

setup_user() {
    log_section "User Setup"
    
    if id "$USER" &>/dev/null; then
        log_info "User $USER already exists"
    else
        useradd -r -m -d "/home/$USER" -s /bin/bash "$USER"
        log_success "Created user: $USER"
    fi
    
    usermod -aG docker "$USER" 2>/dev/null || log_warn "Docker group not found, will be added later"
    
    mkdir -p "/home/$USER/.ssh"
    chmod 700 "/home/$USER/.ssh"
    chown "$USER:$USER" "/home/$USER/.ssh"
    
    log_success "User setup completed"
}

setup_directories() {
    log_section "Directory Setup"
    
    local directories=(
        "$INSTALL_PATH"
        "/var/log/github-runner"
        "/etc/github-runner"
        "/var/lib/github-runner"
        "/var/cache/github-runner"
        "/var/backups/github-runner"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    done
    
    chown "$USER:$USER" "$INSTALL_PATH"
    chown "$USER:$USER" "/var/log/github-runner"
    chown "$USER:$USER" "/var/lib/github-runner"
    chown "$USER:$USER" "/var/cache/github-runner"
    chown root:root "/etc/github-runner"
    chown root:root "/var/backups/github-runner"
    
    chmod 755 "$INSTALL_PATH"
    chmod 755 "/var/log/github-runner"
    chmod 750 "/etc/github-runner"
    chmod 755 "/var/lib/github-runner"
    chmod 755 "/var/cache/github-runner"
    chmod 750 "/var/backups/github-runner"
    
    log_success "Directories created and configured"
}

setup_docker() {
    if [[ "$SKIP_DOCKER" == true ]]; then
        log_info "Skipping Docker setup"
        return 0
    fi
    
    log_section "Docker Setup"
    
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker already installed"
    else
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        log_command "apt-get update -qq"
        log_command "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin"
        
        log_success "Docker installed successfully"
    fi
    
    systemctl enable docker
    systemctl start docker
    
    usermod -aG docker "$USER"
    
    log_success "Docker setup completed"
}

download_runner() {
    log_section "GitHub Actions Runner Download"
    
    local runner_version
    runner_version=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')
    
    local runner_arch="x64"
    if [[ $(uname -m) == "aarch64" ]]; then
        runner_arch="arm64"
    fi
    
    local download_url="https://github.com/actions/runner/releases/download/v${runner_version}/actions-runner-linux-${runner_arch}-${runner_version}.tar.gz"
    
    log_info "Downloading runner version $runner_version for $runner_arch"
    
    cd "$INSTALL_PATH"
    wget -q "$download_url" -O "actions-runner.tar.gz"
    
    sudo -u "$USER" tar xzf "actions-runner.tar.gz"
    rm "actions-runner.tar.gz"
    
    log_success "GitHub Actions runner downloaded and extracted"
}

configure_runner() {
    log_section "Runner Configuration"
    
    cd "$INSTALL_PATH"
    
    local runner_name="$(hostname)-runner"
    local labels="$ENVIRONMENT,linux,$(uname -m)"
    
    log_info "Configuring runner: $runner_name"
    log_info "Labels: $labels"
    
    sudo -u "$USER" ./config.sh \
        --url "https://github.com/$REPO" \
        --token "$TOKEN" \
        --name "$runner_name" \
        --work "_work" \
        --labels "$labels" \
        --unattended \
        --replace
    
    log_success "Runner configured successfully"
}

create_systemd_service() {
    log_section "Systemd Service Creation"
    
    cat > /etc/systemd/system/github-runner.service << 'EOF'
[Unit]
Description=GitHub Actions Runner
After=network.target docker.service
Wants=docker.service

[Service]
Type=notify
User=%i
Group=%i
WorkingDirectory=%h
Environment=HOME=%h
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=%h/run.sh
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
Restart=always
RestartSec=10
TimeoutStopSec=30
StandardOutput=journal
StandardError=journal
SyslogIdentifier=github-runner

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=%h /var/log/github-runner /var/lib/github-runner /var/cache/github-runner
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Replace placeholders with actual values
    sed -i "s|%i|$USER|g" /etc/systemd/system/github-runner.service
    sed -i "s|%h|$INSTALL_PATH|g" /etc/systemd/system/github-runner.service
    
    systemctl daemon-reload
    systemctl enable github-runner.service
    
    log_success "Systemd service created and enabled"
}

setup_monitoring() {
    if [[ "$SKIP_MONITORING" == true ]]; then
        log_info "Skipping monitoring setup"
        return 0
    fi
    
    log_section "Monitoring Setup"
    
    # Logrotate configuration
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
    
    # Health check script
    cat > /usr/local/bin/github-runner-health << 'EOF'
#!/bin/bash
source /home/dev/workspace/github-actions-runner/scripts/common/logging.sh
source /home/dev/workspace/github-actions-runner/scripts/common/utils.sh

check_service_health() {
    if systemctl is-active github-runner.service >/dev/null 2>&1; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
}

check_disk_space
check_memory_usage
echo "status:$(check_service_health)"
EOF
    
    chmod +x /usr/local/bin/github-runner-health
    
    # Cron job for health monitoring
    cat > /etc/cron.d/github-runner-monitoring << EOF
# GitHub Actions Runner Health Monitoring
*/5 * * * * root /usr/local/bin/github-runner-health >> /var/log/github-runner/health.log 2>&1
EOF
    
    log_success "Monitoring setup completed"
}

create_config_file() {
    log_section "Configuration File Creation"
    
    cat > /etc/github-runner/config.env << EOF
# GitHub Actions Runner Configuration
ENVIRONMENT=$ENVIRONMENT
REPO=$REPO
USER=$USER
INSTALL_PATH=$INSTALL_PATH
RUNNER_NAME=$(hostname)-runner
RUNNER_WORK_DIR=$INSTALL_PATH/_work
LOG_LEVEL=INFO
DOCKER_ENABLED=true
MONITORING_ENABLED=true

# Resource Limits
MAX_CONCURRENT_JOBS=2
MAX_JOB_TIMEOUT=3600
DISK_SPACE_WARNING_THRESHOLD=80
MEMORY_WARNING_THRESHOLD=80

# Backup Configuration
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30
BACKUP_LOCATION="/var/backups/github-runner"

# Security Settings
WEBHOOK_URL=""
ALERT_EMAIL=""
EOF
    
    chmod 640 /etc/github-runner/config.env
    chown root:"$USER" /etc/github-runner/config.env
    
    log_success "Configuration file created"
}

setup_firewall() {
    log_section "Firewall Configuration"
    
    if command -v ufw >/dev/null 2>&1; then
        ufw --force enable
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow out 443/tcp comment "HTTPS outbound"
        ufw allow out 80/tcp comment "HTTP outbound"
        ufw allow out 9418/tcp comment "Git protocol"
        
        log_success "UFW firewall configured"
    else
        log_warn "UFW not found, skipping firewall configuration"
    fi
}

run_validation() {
    log_section "Post-Setup Validation"
    
    local validation_script="$SCRIPT_DIR/validate.sh"
    if [[ -x "$validation_script" ]]; then
        "$validation_script" --quick
    else
        log_warn "Validation script not found, performing basic checks"
        
        if systemctl is-enabled github-runner.service >/dev/null 2>&1; then
            log_success "Service is enabled"
        else
            log_error "Service is not enabled"
            return 1
        fi
        
        if [[ -f "$INSTALL_PATH/config.sh" ]]; then
            log_success "Runner is configured"
        else
            log_error "Runner configuration not found"
            return 1
        fi
    fi
    
    log_success "Setup validation completed"
}

cleanup() {
    log_section "Cleanup"
    
    rm -f /tmp/github-runner-*
    apt-get autoremove -y >/dev/null 2>&1 || true
    apt-get autoclean >/dev/null 2>&1 || true
    
    log_success "Cleanup completed"
}

main() {
    local lock_file="/var/lock/github-runner-setup.lock"
    
    if ! lock_script "$lock_file"; then
        log_error "Another setup process is running"
        exit 1
    fi
    
    trap 'unlock_script "$lock_file"' EXIT
    
    log_section "GitHub Actions Runner Setup"
    log_info "Environment: $ENVIRONMENT"
    log_info "Repository: $REPO"
    log_info "User: $USER"
    log_info "Install Path: $INSTALL_PATH"
    
    validate_inputs
    check_requirements
    install_dependencies
    setup_user
    setup_directories
    setup_docker
    download_runner
    configure_runner
    create_systemd_service
    setup_monitoring
    create_config_file
    setup_firewall
    run_validation
    cleanup
    
    log_section "Setup Completed Successfully"
    log_info "Next steps:"
    log_info "1. Start the service: systemctl start github-runner"
    log_info "2. Check status: systemctl status github-runner"
    log_info "3. View logs: journalctl -u github-runner -f"
    log_info "4. Test runner: $SCRIPT_DIR/validate.sh"
    
    send_notification "success" "GitHub Runner Setup Complete" "Runner setup completed successfully on $(hostname)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi