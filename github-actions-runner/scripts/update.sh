#!/bin/bash

set -euo pipefail

# GitHub Actions Runner Update Script
# This script handles updates for the runner and its components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

check_for_updates() {
    log "Checking for updates..."
    
    # Check for Docker image updates
    local current_image="myoung34/github-runner:latest"
    local current_digest=$(docker image inspect "$current_image" --format '{{.Id}}' 2>/dev/null || echo "")
    
    log "Pulling latest image..."
    docker pull "$current_image"
    
    local new_digest=$(docker image inspect "$current_image" --format '{{.Id}}')
    
    if [[ "$current_digest" != "$new_digest" ]]; then
        log "New image available: $new_digest"
        return 0
    else
        log "No image updates available"
        return 1
    fi
}

update_runner() {
    log "Starting runner update process..."
    
    # Create backup before update
    log "Creating backup before update..."
    "$SCRIPT_DIR/backup.sh" create
    
    # Stop current containers
    log "Stopping current containers..."
    cd "$PROJECT_DIR"
    docker-compose down
    
    # Pull latest images
    log "Pulling latest images..."
    docker-compose pull
    
    # Start updated containers
    log "Starting updated containers..."
    docker-compose up -d
    
    # Wait for containers to be ready
    log "Waiting for containers to be ready..."
    sleep 30
    
    # Run health check
    log "Running health check..."
    if "$SCRIPT_DIR/health-check.sh"; then
        log "Update completed successfully"
    else
        error "Health check failed after update"
        
        # Rollback
        log "Rolling back to previous backup..."
        "$SCRIPT_DIR/backup.sh" restore latest
        
        error "Update failed, rolled back to previous version"
        exit 1
    fi
}

update_system_packages() {
    log "Updating system packages..."
    
    # Update package lists
    sudo apt-get update
    
    # Update Docker and Docker Compose if available
    if apt list --upgradable 2>/dev/null | grep -q docker; then
        log "Docker updates available, updating..."
        sudo apt-get upgrade -y docker-ce docker-ce-cli containerd.io
        
        # Restart Docker service
        sudo systemctl restart docker
        
        # Wait for Docker to be ready
        sleep 10
    fi
    
    # Update other system packages
    sudo apt-get upgrade -y
    
    log "System packages updated"
}

rollback_update() {
    log "Rolling back to previous version..."
    
    # Stop current containers
    cd "$PROJECT_DIR"
    docker-compose down
    
    # Restore from backup
    "$SCRIPT_DIR/backup.sh" restore latest
    
    log "Rollback completed"
}

schedule_update() {
    local schedule="${1:-weekly}"
    
    log "Scheduling automatic updates: $schedule"
    
    local cron_entry=""
    case "$schedule" in
        daily)
            cron_entry="0 2 * * * $SCRIPT_DIR/update.sh auto"
            ;;
        weekly)
            cron_entry="0 2 * * 0 $SCRIPT_DIR/update.sh auto"
            ;;
        monthly)
            cron_entry="0 2 1 * * $SCRIPT_DIR/update.sh auto"
            ;;
        *)
            error "Invalid schedule: $schedule (use daily, weekly, or monthly)"
            exit 1
            ;;
    esac
    
    # Add to crontab
    (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
    
    log "Automatic updates scheduled: $schedule"
}

auto_update() {
    log "Running automatic update check..."
    
    # Check if updates are available
    if check_for_updates; then
        log "Updates available, proceeding with update..."
        update_runner
    else
        log "No updates available"
    fi
    
    # Clean up old backups
    "$SCRIPT_DIR/backup.sh" cleanup 7
}

usage() {
    cat <<EOF
Usage: $0 {check|update|rollback|schedule|auto} [options]

Commands:
    check               Check for available updates
    update             Update the runner and components
    rollback           Rollback to previous version
    schedule [freq]    Schedule automatic updates (daily/weekly/monthly)
    auto               Run automatic update process

Examples:
    $0 check
    $0 update
    $0 rollback
    $0 schedule weekly
    $0 auto
EOF
}

main() {
    local command="${1:-}"
    
    case "$command" in
        check)
            check_for_updates
            ;;
        update)
            update_runner
            ;;
        rollback)
            rollback_update
            ;;
        schedule)
            schedule_update "${2:-weekly}"
            ;;
        auto)
            auto_update
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"