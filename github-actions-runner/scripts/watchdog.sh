#!/bin/bash

# GitHub Actions Runner Watchdog Script
# Monitors service health and restarts unhealthy containers

set -euo pipefail

# Configuration
WATCHDOG_ENDPOINTS=${WATCHDOG_ENDPOINTS:-"http://runner:8080/health,http://health_monitor:9100/,http://metrics_collector:9090/-/healthy"}
RESTART_UNHEALTHY=${RESTART_UNHEALTHY:-true}
MAX_RESTART_ATTEMPTS=${MAX_RESTART_ATTEMPTS:-3}
LOG_FILE="/var/log/watchdog.log"

# Restart tracking
RESTART_COUNT_FILE="/tmp/restart_counts"
touch "$RESTART_COUNT_FILE"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Function to check service health
check_service_health() {
    local endpoint="$1"
    local service_name="$2"
    
    log "Checking health of $service_name ($endpoint)"
    
    if curl -f -s --max-time 10 "$endpoint" > /dev/null 2>&1; then
        log "$service_name is healthy"
        return 0
    else
        error "$service_name is unhealthy (endpoint: $endpoint)"
        return 1
    fi
}

# Function to get restart count for a service
get_restart_count() {
    local service_name="$1"
    grep "^$service_name:" "$RESTART_COUNT_FILE" 2>/dev/null | cut -d: -f2 || echo "0"
}

# Function to increment restart count for a service
increment_restart_count() {
    local service_name="$1"
    local current_count=$(get_restart_count "$service_name")
    local new_count=$((current_count + 1))
    
    # Update or add the count
    if grep -q "^$service_name:" "$RESTART_COUNT_FILE"; then
        sed -i "s/^$service_name:.*/$service_name:$new_count/" "$RESTART_COUNT_FILE"
    else
        echo "$service_name:$new_count" >> "$RESTART_COUNT_FILE"
    fi
    
    echo "$new_count"
}

# Function to reset restart count for a service
reset_restart_count() {
    local service_name="$1"
    sed -i "/^$service_name:/d" "$RESTART_COUNT_FILE"
}

# Function to restart a service
restart_service() {
    local service_name="$1"
    local restart_count=$(get_restart_count "$service_name")
    
    if [ "$restart_count" -ge "$MAX_RESTART_ATTEMPTS" ]; then
        error "$service_name has reached maximum restart attempts ($MAX_RESTART_ATTEMPTS). Manual intervention required."
        return 1
    fi
    
    log "Restarting $service_name (attempt $((restart_count + 1))/$MAX_RESTART_ATTEMPTS)"
    
    if docker restart "$service_name" > /dev/null 2>&1; then
        increment_restart_count "$service_name"
        log "$service_name restarted successfully"
        
        # Wait for service to come back up
        sleep 30
        
        # Check if restart was successful
        local container_name
        case "$service_name" in
            "runner") container_name="github-runner" ;;
            "health_monitor") container_name="runner-health-monitor" ;;
            "metrics_collector") container_name="runner-metrics-collector" ;;
            *) container_name="$service_name" ;;
        esac
        
        if docker ps --filter "name=$container_name" --filter "status=running" --format "{{.Names}}" | grep -q "$container_name"; then
            log "$service_name is now running"
            return 0
        else
            error "$service_name failed to start after restart"
            return 1
        fi
    else
        error "Failed to restart $service_name"
        return 1
    fi
}

# Function to send alert
send_alert() {
    local service_name="$1"
    local status="$2"
    local message="$3"
    
    # Log the alert
    log "ALERT: $service_name - $status - $message"
    
    # Send webhook notification if configured
    if [ -n "${WEBHOOK_URL:-}" ]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"service\":\"$service_name\",\"status\":\"$status\",\"message\":\"$message\",\"timestamp\":\"$(date -Iseconds)\"}" \
            2>/dev/null || true
    fi
    
    # Send email notification if configured
    if [ -n "${ALERT_EMAIL:-}" ] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "GitHub Runner Alert: $service_name - $status" "$ALERT_EMAIL" || true
    fi
}

# Main watchdog function
run_watchdog() {
    log "Starting watchdog monitoring..."
    
    # Parse endpoints
    IFS=',' read -ra ENDPOINTS <<< "$WATCHDOG_ENDPOINTS"
    
    for endpoint in "${ENDPOINTS[@]}"; do
        # Extract service name from endpoint
        service_name=""
        if [[ "$endpoint" == *"runner"* ]]; then
            service_name="runner"
        elif [[ "$endpoint" == *"health_monitor"* ]]; then
            service_name="health_monitor"
        elif [[ "$endpoint" == *"metrics_collector"* ]]; then
            service_name="metrics_collector"
        else
            service_name="unknown"
        fi
        
        # Check service health
        if check_service_health "$endpoint" "$service_name"; then
            # Service is healthy, reset restart count
            reset_restart_count "$service_name"
        else
            # Service is unhealthy
            send_alert "$service_name" "unhealthy" "Service $service_name is not responding at $endpoint"
            
            if [ "$RESTART_UNHEALTHY" = "true" ]; then
                if restart_service "$service_name"; then
                    send_alert "$service_name" "restarted" "Service $service_name has been restarted successfully"
                else
                    send_alert "$service_name" "failed" "Failed to restart service $service_name - manual intervention required"
                fi
            fi
        fi
    done
    
    log "Watchdog monitoring cycle completed"
}

# Function to check Docker daemon
check_docker_daemon() {
    if ! docker info > /dev/null 2>&1; then
        error "Docker daemon is not responding"
        send_alert "docker" "unhealthy" "Docker daemon is not responding"
        return 1
    fi
    return 0
}

# Function to check system resources
check_system_resources() {
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [ "$disk_usage" -gt 90 ]; then
        error "Disk usage is critical: ${disk_usage}%"
        send_alert "system" "critical" "Disk usage is at ${disk_usage}%"
    fi
    
    if [ "$memory_usage" -gt 90 ]; then
        error "Memory usage is critical: ${memory_usage}%"
        send_alert "system" "critical" "Memory usage is at ${memory_usage}%"
    fi
}

# Main execution
main() {
    log "Watchdog started (PID: $$)"
    
    # Check Docker daemon
    if ! check_docker_daemon; then
        exit 1
    fi
    
    # Check system resources
    check_system_resources
    
    # Run main watchdog
    run_watchdog
    
    log "Watchdog completed successfully"
}

# Run the watchdog
main "$@"