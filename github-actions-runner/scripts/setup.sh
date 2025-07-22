#!/bin/bash

set -euo pipefail

# GitHub Actions Runner Setup Script
# This script sets up the GitHub Actions runner environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$PROJECT_DIR/logs/setup.log"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$PROJECT_DIR/logs/setup.log" >&2
}

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed"
        exit 1
    fi
    
    log "Dependencies check passed"
}

setup_environment() {
    log "Setting up environment..."
    
    # Create required directories
    mkdir -p "$PROJECT_DIR/logs"
    mkdir -p "$PROJECT_DIR/config"
    
    # Set permissions
    chmod 755 "$PROJECT_DIR/scripts/"*.sh
    chmod 600 "$PROJECT_DIR/config/runner.env"
    
    # Create log files
    touch "$PROJECT_DIR/logs/runner.log"
    touch "$PROJECT_DIR/logs/health.log"
    touch "$PROJECT_DIR/logs/security.log"
    touch "$PROJECT_DIR/logs/setup.log"
    
    log "Environment setup completed"
}

validate_config() {
    log "Validating configuration..."
    
    local env_file="$PROJECT_DIR/config/runner.env"
    
    if [[ ! -f "$env_file" ]]; then
        error "Configuration file not found: $env_file"
        exit 1
    fi
    
    # Check required variables
    local required_vars=(
        "GITHUB_RUNNER_TOKEN"
        "GITHUB_REPOSITORY_URL"
        "RUNNER_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$env_file"; then
            error "Required variable $var not found in $env_file"
            exit 1
        fi
        
        if grep -q "^$var=your_.*_here" "$env_file"; then
            error "Variable $var contains placeholder value. Please configure it properly."
            exit 1
        fi
    done
    
    log "Configuration validation passed"
}

setup_systemd_service() {
    log "Setting up systemd service..."
    
    local service_file="/etc/systemd/system/github-actions-runner.service"
    
    sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=GitHub Actions Self-Hosted Runner
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable github-actions-runner.service
    
    log "Systemd service setup completed"
}

test_connectivity() {
    log "Testing network connectivity..."
    
    # Test Home Assistant connectivity
    local ha_host="${HA_HOST:-192.168.1.155}"
    local ha_port="${HA_PORT:-8123}"
    
    if timeout 10 bash -c "</dev/tcp/$ha_host/$ha_port"; then
        log "Home Assistant connectivity test passed ($ha_host:$ha_port)"
    else
        error "Home Assistant connectivity test failed ($ha_host:$ha_port)"
        exit 1
    fi
    
    # Test GitHub connectivity
    if curl -s --connect-timeout 10 https://api.github.com/rate_limit > /dev/null; then
        log "GitHub connectivity test passed"
    else
        error "GitHub connectivity test failed"
        exit 1
    fi
    
    log "Network connectivity tests passed"
}

main() {
    log "Starting GitHub Actions Runner setup..."
    
    check_dependencies
    setup_environment
    validate_config
    setup_systemd_service
    test_connectivity
    
    log "Setup completed successfully!"
    log "Next steps:"
    log "1. Configure your GitHub runner token in config/runner.env"
    log "2. Run: sudo systemctl start github-actions-runner"
    log "3. Check status: sudo systemctl status github-actions-runner"
    log "4. Monitor logs: tail -f logs/runner.log"
}

main "$@"