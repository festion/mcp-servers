#!/bin/bash

set -euo pipefail

# GitHub Actions Runner Health Check Script
# This script monitors the health of the GitHub Actions runner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/health.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

check_container_health() {
    local container_name="$1"
    local status
    
    if ! docker ps --filter "name=$container_name" --format "table {{.Status}}" | grep -q "Up"; then
        error "Container $container_name is not running"
        return 1
    fi
    
    status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
    
    if [[ "$status" != "healthy" ]] && [[ "$status" != "unknown" ]]; then
        error "Container $container_name health check failed: $status"
        return 1
    fi
    
    log "Container $container_name is healthy"
    return 0
}

check_runner_registration() {
    local container_name="github-actions-runner"
    
    if ! docker exec "$container_name" pgrep -f "Runner.Listener" > /dev/null 2>&1; then
        error "GitHub Actions runner process not found"
        return 1
    fi
    
    log "GitHub Actions runner process is running"
    return 0
}

check_disk_space() {
    local threshold=80
    local usage
    
    usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ "$usage" -gt "$threshold" ]]; then
        error "Disk usage is above threshold: ${usage}% (threshold: ${threshold}%)"
        return 1
    fi
    
    log "Disk usage is acceptable: ${usage}%"
    return 0
}

check_memory_usage() {
    local threshold=80
    local container_name="github-actions-runner"
    local usage
    
    usage=$(docker stats --no-stream --format "table {{.MemPerc}}" "$container_name" | tail -1 | sed 's/%//')
    
    if [[ "$usage" -gt "$threshold" ]]; then
        error "Memory usage is above threshold: ${usage}% (threshold: ${threshold}%)"
        return 1
    fi
    
    log "Memory usage is acceptable: ${usage}%"
    return 0
}

check_network_connectivity() {
    local ha_host="${HA_HOST:-192.168.1.155}"
    local ha_port="${HA_PORT:-8123}"
    
    # Test Home Assistant connectivity
    if ! timeout 5 bash -c "</dev/tcp/$ha_host/$ha_port" 2>/dev/null; then
        error "Cannot connect to Home Assistant ($ha_host:$ha_port)"
        return 1
    fi
    
    # Test GitHub connectivity
    if ! timeout 5 curl -s https://api.github.com/rate_limit > /dev/null; then
        error "Cannot connect to GitHub API"
        return 1
    fi
    
    log "Network connectivity is healthy"
    return 0
}

restart_runner() {
    log "Attempting to restart GitHub Actions runner..."
    
    cd "$PROJECT_DIR"
    
    if docker-compose down; then
        log "Runner stopped successfully"
    else
        error "Failed to stop runner"
        return 1
    fi
    
    sleep 5
    
    if docker-compose up -d; then
        log "Runner started successfully"
    else
        error "Failed to start runner"
        return 1
    fi
    
    # Wait for runner to be ready
    sleep 30
    
    log "Runner restart completed"
    return 0
}

send_alert() {
    local message="$1"
    local severity="${2:-WARNING}"
    
    # Log the alert
    log "ALERT [$severity]: $message"
    
    # Send to systemd journal
    logger -t github-actions-runner "[$severity] $message"
    
    # TODO: Add webhook/email notification integration
    # curl -X POST "https://hooks.slack.com/..." -d "{'text': '$message'}"
}

main() {
    local health_issues=0
    
    log "Starting health check..."
    
    # Check container health
    if ! check_container_health "github-actions-runner"; then
        ((health_issues++))
    fi
    
    # Check runner registration
    if ! check_runner_registration; then
        ((health_issues++))
    fi
    
    # Check system resources
    if ! check_disk_space; then
        ((health_issues++))
    fi
    
    if ! check_memory_usage; then
        ((health_issues++))
    fi
    
    # Check network connectivity
    if ! check_network_connectivity; then
        ((health_issues++))
    fi
    
    # Handle health issues
    if [[ "$health_issues" -gt 0 ]]; then
        send_alert "Health check failed with $health_issues issues" "ERROR"
        
        # Attempt automatic recovery for critical issues
        if [[ "$health_issues" -ge 2 ]]; then
            log "Multiple health issues detected, attempting automatic recovery..."
            if restart_runner; then
                send_alert "Automatic recovery successful" "INFO"
            else
                send_alert "Automatic recovery failed" "CRITICAL"
                exit 1
            fi
        fi
    else
        log "Health check passed - all systems healthy"
    fi
    
    log "Health check completed"
}

main "$@"