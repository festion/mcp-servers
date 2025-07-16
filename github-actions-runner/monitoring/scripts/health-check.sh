#!/bin/bash

# GitHub Actions Runner Health Check System
# Comprehensive health monitoring and validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(dirname "$MONITORING_DIR")"
CONFIG_FILE="$MONITORING_DIR/health-checks.yml"
METRICS_DIR="$BASE_DIR/data/metrics"
LOG_FILE="$BASE_DIR/logs/health-check.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check results
declare -A HEALTH_RESULTS
OVERALL_STATUS="HEALTHY"
CRITICAL_FAILURES=0
WARNING_COUNT=0

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Status display function
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Check container health
check_container_health() {
    log "Checking container health..."
    
    local containers=("github-runner" "metrics_collector" "health_monitor" "log_aggregator" "nginx_proxy")
    
    for container in "${containers[@]}"; do
        if docker ps --filter "name=$container" --filter "status=running" --format "table {{.Names}}" | grep -q "$container"; then
            HEALTH_RESULTS["container_$container"]="HEALTHY"
            print_status "PASS" "Container $container is running"
        else
            HEALTH_RESULTS["container_$container"]="UNHEALTHY"
            print_status "FAIL" "Container $container is not running"
            CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
        fi
    done
}

# Check GitHub API connectivity
check_github_api() {
    log "Checking GitHub API connectivity..."
    
    local github_api_url="https://api.github.com"
    local response_code
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "$github_api_url" || echo "000")
    
    if [[ "$response_code" == "200" ]]; then
        HEALTH_RESULTS["github_api"]="HEALTHY"
        print_status "PASS" "GitHub API is reachable"
    else
        HEALTH_RESULTS["github_api"]="UNHEALTHY"
        print_status "FAIL" "GitHub API unreachable (HTTP $response_code)"
        CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    fi
}

# Check private network connectivity
check_private_network() {
    log "Checking private network connectivity..."
    
    local private_endpoints=("192.168.1.155:8123" "192.168.1.137:8006" "192.168.1.90:3000")
    local healthy_endpoints=0
    
    for endpoint in "${private_endpoints[@]}"; do
        if nc -z -w 3 ${endpoint/:/ } 2>/dev/null; then
            print_status "PASS" "Private endpoint $endpoint is reachable"
            healthy_endpoints=$((healthy_endpoints + 1))
        else
            print_status "WARN" "Private endpoint $endpoint is unreachable"
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    done
    
    if [[ $healthy_endpoints -gt 0 ]]; then
        HEALTH_RESULTS["private_network"]="HEALTHY"
    else
        HEALTH_RESULTS["private_network"]="DEGRADED"
        print_status "WARN" "No private endpoints reachable"
    fi
}

# Check resource utilization
check_resource_utilization() {
    log "Checking resource utilization..."
    
    # CPU usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        HEALTH_RESULTS["cpu_usage"]="CRITICAL"
        print_status "FAIL" "CPU usage critical: ${cpu_usage}%"
        CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    elif (( $(echo "$cpu_usage > 60" | bc -l) )); then
        HEALTH_RESULTS["cpu_usage"]="WARNING"
        print_status "WARN" "CPU usage high: ${cpu_usage}%"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    else
        HEALTH_RESULTS["cpu_usage"]="HEALTHY"
        print_status "PASS" "CPU usage normal: ${cpu_usage}%"
    fi
    
    # Memory usage
    local memory_usage
    memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        HEALTH_RESULTS["memory_usage"]="CRITICAL"
        print_status "FAIL" "Memory usage critical: ${memory_usage}%"
        CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    elif (( $(echo "$memory_usage > 70" | bc -l) )); then
        HEALTH_RESULTS["memory_usage"]="WARNING"
        print_status "WARN" "Memory usage high: ${memory_usage}%"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    else
        HEALTH_RESULTS["memory_usage"]="HEALTHY"
        print_status "PASS" "Memory usage normal: ${memory_usage}%"
    fi
    
    # Disk usage
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 90 ]]; then
        HEALTH_RESULTS["disk_usage"]="CRITICAL"
        print_status "FAIL" "Disk usage critical: ${disk_usage}%"
        CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    elif [[ $disk_usage -gt 80 ]]; then
        HEALTH_RESULTS["disk_usage"]="WARNING"
        print_status "WARN" "Disk usage high: ${disk_usage}%"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    else
        HEALTH_RESULTS["disk_usage"]="HEALTHY"
        print_status "PASS" "Disk usage normal: ${disk_usage}%"
    fi
}

# Check service dependencies
check_service_dependencies() {
    log "Checking service dependencies..."
    
    # Check if required services are accessible
    local services=("prometheus:9090" "node-exporter:9100" "fluent-bit:2020")
    
    for service in "${services[@]}"; do
        local service_name=${service%:*}
        local service_port=${service#*:}
        
        if curl -s -f "http://localhost:$service_port/health" >/dev/null 2>&1 || \
           curl -s -f "http://localhost:$service_port/" >/dev/null 2>&1; then
            HEALTH_RESULTS["service_$service_name"]="HEALTHY"
            print_status "PASS" "Service $service_name is healthy"
        else
            HEALTH_RESULTS["service_$service_name"]="UNHEALTHY"
            print_status "FAIL" "Service $service_name is unhealthy"
            CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
        fi
    done
}

# Check GitHub runner job metrics
check_runner_metrics() {
    log "Checking GitHub runner metrics..."
    
    # Check if runner is registered and active
    if docker logs github-runner 2>/dev/null | grep -q "Connected to GitHub"; then
        HEALTH_RESULTS["runner_connection"]="HEALTHY"
        print_status "PASS" "GitHub runner is connected"
    else
        HEALTH_RESULTS["runner_connection"]="UNHEALTHY"
        print_status "FAIL" "GitHub runner is not connected"
        CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
    fi
    
    # Check recent job activity
    local recent_jobs
    recent_jobs=$(docker logs --since="1h" github-runner 2>/dev/null | grep -c "Job .* completed" || echo "0")
    
    if [[ $recent_jobs -gt 0 ]]; then
        HEALTH_RESULTS["recent_activity"]="HEALTHY"
        print_status "PASS" "Recent job activity detected: $recent_jobs jobs"
    else
        HEALTH_RESULTS["recent_activity"]="IDLE"
        print_status "INFO" "No recent job activity (last 1 hour)"
    fi
}

# Generate health report
generate_health_report() {
    log "Generating health report..."
    
    local report_file="$METRICS_DIR/health-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "overall_status": "$OVERALL_STATUS",
    "critical_failures": $CRITICAL_FAILURES,
    "warning_count": $WARNING_COUNT,
    "health_checks": {
EOF

    local first=true
    for check in "${!HEALTH_RESULTS[@]}"; do
        if [[ $first == false ]]; then
            echo "," >> "$report_file"
        fi
        echo "        \"$check\": \"${HEALTH_RESULTS[$check]}\"" >> "$report_file"
        first=false
    done

    cat >> "$report_file" << EOF
    },
    "system_info": {
        "hostname": "$(hostname)",
        "uptime": "$(uptime -p)",
        "load_average": "$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')",
        "docker_version": "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')"
    }
}
EOF

    echo "Health report saved to: $report_file"
}

# Auto-recovery actions
perform_auto_recovery() {
    log "Performing auto-recovery actions..."
    
    # Restart failed containers
    for check in "${!HEALTH_RESULTS[@]}"; do
        if [[ $check == container_* && ${HEALTH_RESULTS[$check]} == "UNHEALTHY" ]]; then
            local container_name=${check#container_}
            print_status "INFO" "Attempting to restart container: $container_name"
            docker restart "$container_name" || true
        fi
    done
    
    # Clear old logs if disk usage is critical
    if [[ ${HEALTH_RESULTS["disk_usage"]} == "CRITICAL" ]]; then
        print_status "INFO" "Cleaning old logs due to critical disk usage"
        find "$BASE_DIR/logs" -name "*.log" -mtime +7 -exec rm -f {} \; || true
        docker system prune -f || true
    fi
}

# Send alerts
send_alerts() {
    if [[ $CRITICAL_FAILURES -gt 0 ]]; then
        log "Sending critical failure alerts..."
        
        # Integration with existing homelab-gitops-auditor
        if [[ -f "/home/dev/workspace/homelab-gitops-auditor/scripts/send-alert.sh" ]]; then
            /home/dev/workspace/homelab-gitops-auditor/scripts/send-alert.sh \
                "GitHub Actions Runner Critical Failure" \
                "Critical failures detected: $CRITICAL_FAILURES. Check health report for details." \
                "critical" || true
        fi
    fi
}

# Main execution
main() {
    echo "=== GitHub Actions Runner Health Check ==="
    echo "Started at: $(date)"
    echo
    
    # Ensure directories exist
    mkdir -p "$METRICS_DIR" "$(dirname "$LOG_FILE")"
    
    # Run health checks
    check_container_health
    check_github_api
    check_private_network
    check_resource_utilization
    check_service_dependencies
    check_runner_metrics
    
    # Determine overall status
    if [[ $CRITICAL_FAILURES -gt 0 ]]; then
        OVERALL_STATUS="CRITICAL"
    elif [[ $WARNING_COUNT -gt 0 ]]; then
        OVERALL_STATUS="WARNING"
    else
        OVERALL_STATUS="HEALTHY"
    fi
    
    echo
    echo "=== Health Check Summary ==="
    print_status "INFO" "Overall Status: $OVERALL_STATUS"
    print_status "INFO" "Critical Failures: $CRITICAL_FAILURES"
    print_status "INFO" "Warnings: $WARNING_COUNT"
    echo
    
    # Generate report
    generate_health_report
    
    # Auto-recovery if enabled
    if [[ "${AUTO_RECOVERY:-false}" == "true" ]]; then
        perform_auto_recovery
    fi
    
    # Send alerts
    send_alerts
    
    log "Health check completed with status: $OVERALL_STATUS"
    
    # Exit with appropriate code
    case $OVERALL_STATUS in
        "HEALTHY") exit 0 ;;
        "WARNING") exit 1 ;;
        "CRITICAL") exit 2 ;;
    esac
}

# Command line options
case "${1:-}" in
    "--auto-recovery")
        AUTO_RECOVERY=true
        main
        ;;
    "--report-only")
        AUTO_RECOVERY=false
        main
        ;;
    *)
        main
        ;;
esac