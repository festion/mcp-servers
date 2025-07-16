#!/bin/bash

set -euo pipefail

# GitHub Actions Runner Deployment Script
# This script handles the complete deployment of the GitHub Actions runner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/deploy.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as correct user
    if [[ "$USER" != "dev" ]]; then
        error "This script must be run as the 'dev' user"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running or user lacks permissions"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        error "User 'dev' is not in the docker group"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

validate_configuration() {
    log "Validating configuration..."
    
    local env_file="$PROJECT_DIR/config/runner.env"
    
    if [[ ! -f "$env_file" ]]; then
        error "Configuration file not found: $env_file"
        exit 1
    fi
    
    # Source the environment file to check variables
    set -a
    source "$env_file"
    set +a
    
    # Check required variables
    local required_vars=(
        "GITHUB_RUNNER_TOKEN"
        "GITHUB_REPOSITORY_URL"
        "RUNNER_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required variable $var is not set"
            exit 1
        fi
        
        if [[ "${!var}" == *"your_"*"_here" ]]; then
            error "Variable $var contains placeholder value: ${!var}"
            exit 1
        fi
    done
    
    # Validate GitHub repository URL format
    if [[ ! "$GITHUB_REPOSITORY_URL" =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then
        error "Invalid GitHub repository URL format: $GITHUB_REPOSITORY_URL"
        exit 1
    fi
    
    # Validate runner token format (should start with specific prefix)
    if [[ ! "$GITHUB_RUNNER_TOKEN" =~ ^[A-Z0-9]{29}$ ]] && [[ ! "$GITHUB_RUNNER_TOKEN" =~ ^ghs_[a-zA-Z0-9]{36}$ ]]; then
        log "WARNING: GitHub runner token format seems unusual: ${GITHUB_RUNNER_TOKEN:0:10}..."
    fi
    
    log "Configuration validation passed"
}

setup_directories() {
    log "Setting up directories..."
    
    # Create all required directories
    mkdir -p "$PROJECT_DIR/logs"
    mkdir -p "/home/dev/backups/github-actions-runner"
    
    # Set proper permissions
    chmod 755 "$PROJECT_DIR/logs"
    chmod 755 "/home/dev/backups/github-actions-runner"
    
    # Create initial log files
    touch "$PROJECT_DIR/logs/runner.log"
    touch "$PROJECT_DIR/logs/health.log"
    touch "$PROJECT_DIR/logs/security.log"
    touch "$PROJECT_DIR/logs/deploy.log"
    
    log "Directories setup completed"
}

deploy_runner() {
    log "Deploying GitHub Actions runner..."
    
    cd "$PROJECT_DIR"
    
    # Pull latest images
    log "Pulling Docker images..."
    docker-compose pull
    
    # Stop any existing containers
    log "Stopping existing containers..."
    docker-compose down --remove-orphans
    
    # Start the runner
    log "Starting GitHub Actions runner..."
    docker-compose up -d
    
    # Wait for containers to be ready
    log "Waiting for containers to be ready..."
    sleep 30
    
    # Check if containers are running
    local running_containers=$(docker-compose ps --services --filter "status=running")
    local expected_containers=("github-runner" "health-monitor" "log-aggregator")
    
    for container in "${expected_containers[@]}"; do
        if ! echo "$running_containers" | grep -q "$container"; then
            error "Container $container is not running"
            docker-compose logs "$container"
            exit 1
        fi
    done
    
    log "GitHub Actions runner deployed successfully"
}

setup_systemd_service() {
    log "Setting up systemd service..."
    
    local service_file="$PROJECT_DIR/config/systemd/github-actions-runner.service"
    local target_service="/etc/systemd/system/github-actions-runner.service"
    
    # Copy service file
    sudo cp "$service_file" "$target_service"
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable the service
    sudo systemctl enable github-actions-runner.service
    
    # Start the service
    sudo systemctl start github-actions-runner.service
    
    # Check service status
    if sudo systemctl is-active --quiet github-actions-runner.service; then
        log "Systemd service setup completed successfully"
    else
        error "Systemd service failed to start"
        sudo systemctl status github-actions-runner.service
        exit 1
    fi
}

run_health_checks() {
    log "Running health checks..."
    
    # Run the health check script
    if "$SCRIPT_DIR/health-check.sh"; then
        log "Health checks passed"
    else
        error "Health checks failed"
        exit 1
    fi
    
    # Test GitHub connectivity
    log "Testing GitHub connectivity..."
    if timeout 10 curl -s https://api.github.com/rate_limit > /dev/null; then
        log "GitHub connectivity test passed"
    else
        error "GitHub connectivity test failed"
        exit 1
    fi
    
    # Test Home Assistant connectivity
    log "Testing Home Assistant connectivity..."
    local ha_host="${HA_HOST:-192.168.1.155}"
    local ha_port="${HA_PORT:-8123}"
    
    if timeout 10 bash -c "</dev/tcp/$ha_host/$ha_port"; then
        log "Home Assistant connectivity test passed"
    else
        error "Home Assistant connectivity test failed"
        exit 1
    fi
}

setup_monitoring() {
    log "Setting up monitoring..."
    
    # Create cron job for health monitoring
    local cron_entry="*/5 * * * * $SCRIPT_DIR/health-check.sh"
    
    # Add to crontab if not already present
    if ! crontab -l 2>/dev/null | grep -q "health-check.sh"; then
        (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
        log "Health monitoring cron job added"
    else
        log "Health monitoring cron job already exists"
    fi
    
    # Setup log rotation
    sudo cp /dev/stdin > /etc/logrotate.d/github-actions-runner <<EOF
$PROJECT_DIR/logs/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 644 dev dev
    postrotate
        /usr/bin/docker-compose -f $PROJECT_DIR/docker-compose.yml restart log-aggregator
    endscript
}
EOF
    
    log "Monitoring setup completed"
}

create_initial_backup() {
    log "Creating initial backup..."
    
    if "$SCRIPT_DIR/backup.sh" create; then
        log "Initial backup created successfully"
    else
        error "Failed to create initial backup"
        exit 1
    fi
}

display_deployment_summary() {
    log "Deployment Summary:"
    log "==================="
    log "✅ GitHub Actions runner deployed and running"
    log "✅ Systemd service configured and enabled"
    log "✅ Health monitoring active"
    log "✅ Logging and monitoring configured"
    log "✅ Initial backup created"
    log ""
    log "Management Commands:"
    log "  Status:    sudo systemctl status github-actions-runner"
    log "  Stop:      sudo systemctl stop github-actions-runner"
    log "  Start:     sudo systemctl start github-actions-runner"
    log "  Restart:   sudo systemctl restart github-actions-runner"
    log "  Logs:      tail -f $PROJECT_DIR/logs/runner.log"
    log "  Health:    $SCRIPT_DIR/health-check.sh"
    log "  Backup:    $SCRIPT_DIR/backup.sh create"
    log "  Update:    $SCRIPT_DIR/update.sh update"
    log ""
    log "Configuration:"
    log "  Repository: $GITHUB_REPOSITORY_URL"
    log "  Runner:     $RUNNER_NAME"
    log "  Labels:     $LABELS"
    log ""
    log "Next Steps:"
    log "1. Verify the runner appears in your GitHub repository settings"
    log "2. Test a workflow to ensure the runner is working correctly"
    log "3. Configure monitoring dashboards if needed"
    log "4. Schedule regular backups"
}

main() {
    log "Starting GitHub Actions runner deployment..."
    
    check_prerequisites
    validate_configuration
    setup_directories
    deploy_runner
    setup_systemd_service
    run_health_checks
    setup_monitoring
    create_initial_backup
    display_deployment_summary
    
    log "Deployment completed successfully!"
}

main "$@"