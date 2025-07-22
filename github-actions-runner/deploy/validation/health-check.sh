#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Running health checks for environment: $ENVIRONMENT"

check_service_health() {
    log_info "Checking service health"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local services=(
        "github-runner-1:$GITHUB_RUNNER_PORT:/health"
        "github-runner-2:$((GITHUB_RUNNER_PORT + 1)):/health"
        "github-runner-3:$((GITHUB_RUNNER_PORT + 2)):/health"
        "monitoring:$MONITORING_PORT:/api/v1/query"
        "metrics:$METRICS_PORT:/metrics"
    )
    
    local failed_services=0
    
    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local service_port="${service#*:}"
        service_port="${service_port%%:*}"
        local health_path="${service##*:}"
        
        local health_url="http://localhost:$service_port$health_path"
        
        log_info "Checking health: $service_name ($health_url)"
        
        if retry_command 3 5 curl -s -f "$health_url" > /dev/null; then
            log_success "Service $service_name is healthy"
        else
            log_error "Service $service_name health check failed"
            ((failed_services++))
        fi
    done
    
    return $failed_services
}

check_container_health() {
    log_info "Checking container health"
    
    local containers
    containers=$(docker ps --filter "label=github-runner" --format "{{.Names}}")
    
    local unhealthy_containers=0
    
    for container in $containers; do
        local health_status
        health_status=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        
        if [[ "$health_status" == "healthy" ]]; then
            log_success "Container $container is healthy"
        else
            log_error "Container $container health status: $health_status"
            ((unhealthy_containers++))
        fi
    done
    
    return $unhealthy_containers
}

check_github_runner_status() {
    log_info "Checking GitHub runner status"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   "https://api.github.com/orgs/$GITHUB_ORG/actions/runners")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to query GitHub API"
        return 1
    fi
    
    local online_runners
    online_runners=$(echo "$response" | jq -r '.runners[] | select(.status == "online") | .name' | wc -l)
    
    local expected_runners="$GITHUB_RUNNER_COUNT"
    
    if (( online_runners >= expected_runners )); then
        log_success "GitHub runners online: $online_runners/$expected_runners"
        return 0
    else
        log_error "Not enough GitHub runners online: $online_runners/$expected_runners"
        return 1
    fi
}

check_network_connectivity() {
    log_info "Checking network connectivity"
    
    local endpoints=(
        "https://api.github.com/zen"
        "https://github.com"
        "https://registry.hub.docker.com"
    )
    
    local failed_endpoints=0
    
    for endpoint in "${endpoints[@]}"; do
        log_info "Checking connectivity to: $endpoint"
        
        if curl -s --max-time 10 "$endpoint" > /dev/null; then
            log_success "Connectivity to $endpoint: OK"
        else
            log_error "Connectivity to $endpoint: FAILED"
            ((failed_endpoints++))
        fi
    done
    
    return $failed_endpoints
}

check_resource_usage() {
    log_info "Checking resource usage"
    
    # Check CPU usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    
    log_info "CPU usage: $cpu_usage%"
    
    # Check memory usage
    local memory_usage
    memory_usage=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
    
    log_info "Memory usage: $memory_usage"
    
    # Check disk usage
    local disk_usage
    disk_usage=$(df -h . | awk 'NR==2 {print $5}')
    
    log_info "Disk usage: $disk_usage"
    
    # Check if any usage is above critical thresholds
    local cpu_threshold=80
    local memory_threshold=90
    local disk_threshold=85
    
    local cpu_value=${cpu_usage%.*}
    local memory_value=${memory_usage%.*}
    local disk_value=${disk_usage%.*}
    
    local resource_warnings=0
    
    if (( cpu_value > cpu_threshold )); then
        log_warn "CPU usage is high: $cpu_usage% (threshold: $cpu_threshold%)"
        ((resource_warnings++))
    fi
    
    if (( memory_value > memory_threshold )); then
        log_warn "Memory usage is high: $memory_usage (threshold: $memory_threshold%)"
        ((resource_warnings++))
    fi
    
    if (( disk_value > disk_threshold )); then
        log_warn "Disk usage is high: $disk_usage (threshold: $disk_threshold%)"
        ((resource_warnings++))
    fi
    
    return $resource_warnings
}

check_log_health() {
    log_info "Checking log health"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local log_files=(
        "$LOG_DIR/github-runner/runner-1.log"
        "$LOG_DIR/github-runner/runner-2.log"
        "$LOG_DIR/github-runner/runner-3.log"
        "$LOG_DIR/monitoring/prometheus.log"
    )
    
    local log_issues=0
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local log_size
            log_size=$(stat -c%s "$log_file")
            
            if (( log_size > 0 )); then
                log_success "Log file OK: $log_file ($log_size bytes)"
                
                # Check for recent errors
                local recent_errors
                recent_errors=$(tail -100 "$log_file" | grep -i error | wc -l)
                
                if (( recent_errors > 10 )); then
                    log_warn "High error count in $log_file: $recent_errors errors"
                    ((log_issues++))
                fi
            else
                log_warn "Log file is empty: $log_file"
                ((log_issues++))
            fi
        else
            log_warn "Log file not found: $log_file"
            ((log_issues++))
        fi
    done
    
    return $log_issues
}

check_backup_health() {
    log_info "Checking backup health"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    local backup_count
    backup_count=$(find "$backup_dir" -type d -name "version-*" | wc -l)
    
    if (( backup_count > 0 )); then
        log_success "Backup system healthy: $backup_count versions available"
        return 0
    else
        log_error "No backups found in: $backup_dir"
        return 1
    fi
}

check_security_status() {
    log_info "Checking security status"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local security_issues=0
    
    # Check for exposed credentials
    if docker secret ls 2>/dev/null | grep -q "github-token"; then
        log_success "GitHub token is properly secured"
    else
        log_warn "GitHub token secret not found"
        ((security_issues++))
    fi
    
    # Check SSL configuration for production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        if [[ "$ENABLE_SSL" == "true" ]]; then
            log_success "SSL is enabled for production"
        else
            log_error "SSL is not enabled for production environment"
            ((security_issues++))
        fi
    fi
    
    # Check for default passwords
    if [[ "${GRAFANA_PASSWORD:-admin}" == "admin" ]]; then
        log_warn "Default Grafana password is being used"
        ((security_issues++))
    fi
    
    return $security_issues
}

generate_health_report() {
    log_info "Generating health report"
    
    local report_file="/tmp/health-report-$ENVIRONMENT-$(date +%Y%m%d_%H%M%S).json"
    
    # Get current metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
    local disk_usage=$(df -h . | awk 'NR==2 {print $5}')
    local container_count=$(docker ps --filter "label=github-runner" | wc -l)
    
    cat > "$report_file" << EOF
{
    "environment": "$ENVIRONMENT",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "overall_health": "healthy",
    "checks": {
        "service_health": "$service_health_status",
        "container_health": "$container_health_status",
        "github_runner_status": "$github_runner_status",
        "network_connectivity": "$network_connectivity_status",
        "resource_usage": "$resource_usage_status",
        "log_health": "$log_health_status",
        "backup_health": "$backup_health_status",
        "security_status": "$security_status"
    },
    "metrics": {
        "cpu_usage": "$cpu_usage",
        "memory_usage": "$memory_usage",
        "disk_usage": "$disk_usage",
        "container_count": $container_count
    },
    "issues": [],
    "recommendations": []
}
EOF
    
    log_success "Health report generated: $report_file"
}

main() {
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local total_failures=0
    
    # Run all health checks
    check_service_health
    service_health_status=$?
    total_failures=$((total_failures + service_health_status))
    
    check_container_health
    container_health_status=$?
    total_failures=$((total_failures + container_health_status))
    
    check_github_runner_status
    github_runner_status=$?
    total_failures=$((total_failures + github_runner_status))
    
    check_network_connectivity
    network_connectivity_status=$?
    total_failures=$((total_failures + network_connectivity_status))
    
    check_resource_usage
    resource_usage_status=$?
    total_failures=$((total_failures + resource_usage_status))
    
    check_log_health
    log_health_status=$?
    total_failures=$((total_failures + log_health_status))
    
    check_backup_health
    backup_health_status=$?
    total_failures=$((total_failures + backup_health_status))
    
    check_security_status
    security_status=$?
    total_failures=$((total_failures + security_status))
    
    generate_health_report
    
    if (( total_failures == 0 )); then
        log_success "All health checks passed"
        exit 0
    else
        log_error "Health checks failed: $total_failures issues found"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi