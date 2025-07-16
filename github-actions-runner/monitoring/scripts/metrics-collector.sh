#!/bin/bash

# GitHub Actions Runner Metrics Collection System
# Collects custom metrics and exposes them in Prometheus format

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(dirname "$MONITORING_DIR")"
METRICS_DIR="$BASE_DIR/data/metrics"
LOG_FILE="$BASE_DIR/logs/metrics-collector.log"
METRICS_PORT="${METRICS_PORT:-9091}"
COLLECTION_INTERVAL="${COLLECTION_INTERVAL:-30}"

# Metric storage
METRICS_FILE="$METRICS_DIR/custom_metrics.prom"
TEMP_METRICS_FILE="$METRICS_DIR/custom_metrics.tmp"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Initialize metrics file
initialize_metrics() {
    mkdir -p "$METRICS_DIR"
    cat > "$METRICS_FILE" << 'EOF'
# HELP github_runner_jobs_total Total number of GitHub Actions jobs processed
# TYPE github_runner_jobs_total counter
# HELP github_runner_jobs_duration_seconds Duration of GitHub Actions jobs in seconds
# TYPE github_runner_jobs_duration_seconds histogram
# HELP github_runner_connection_status Connection status to GitHub (1 = connected, 0 = disconnected)
# TYPE github_runner_connection_status gauge
# HELP github_runner_queue_length Current queue length of pending jobs
# TYPE github_runner_queue_length gauge
# HELP github_runner_system_cpu_usage CPU usage percentage
# TYPE github_runner_system_cpu_usage gauge
# HELP github_runner_system_memory_usage Memory usage percentage
# TYPE github_runner_system_memory_usage gauge
# HELP github_runner_system_disk_usage Disk usage percentage
# TYPE github_runner_system_disk_usage gauge
# HELP github_runner_network_errors_total Total network errors encountered
# TYPE github_runner_network_errors_total counter
# HELP github_runner_container_restarts_total Total container restarts
# TYPE github_runner_container_restarts_total counter
# HELP github_runner_last_job_timestamp Timestamp of the last completed job
# TYPE github_runner_last_job_timestamp gauge
EOF
}

# Collect GitHub runner job metrics
collect_job_metrics() {
    log "Collecting GitHub runner job metrics..."
    
    local jobs_total=0
    local jobs_success=0
    local jobs_failed=0
    local last_job_timestamp=0
    local connection_status=0
    
    # Check if runner container is running
    if docker ps --filter "name=github-runner" --filter "status=running" --format "table {{.Names}}" | grep -q "github-runner"; then
        # Get job statistics from runner logs
        local logs
        logs=$(docker logs --since="1h" github-runner 2>/dev/null || echo "")
        
        # Count completed jobs
        jobs_total=$(echo "$logs" | grep -c "Job .* completed" || echo "0")
        jobs_success=$(echo "$logs" | grep -c "Job .* completed with result: Succeeded" || echo "0")
        jobs_failed=$(echo "$logs" | grep -c "Job .* completed with result: Failed" || echo "0")
        
        # Check connection status
        if echo "$logs" | grep -q "Connected to GitHub"; then
            connection_status=1
        fi
        
        # Get last job timestamp
        local last_job_line
        last_job_line=$(echo "$logs" | grep "Job .* completed" | tail -1 || echo "")
        if [[ -n "$last_job_line" ]]; then
            # Extract timestamp from log line (simplified)
            last_job_timestamp=$(date +%s)
        fi
    fi
    
    # Write job metrics
    cat >> "$TEMP_METRICS_FILE" << EOF
github_runner_jobs_total{status="completed"} $jobs_total
github_runner_jobs_total{status="success"} $jobs_success
github_runner_jobs_total{status="failed"} $jobs_failed
github_runner_connection_status $connection_status
github_runner_last_job_timestamp $last_job_timestamp
EOF
}

# Collect system resource metrics
collect_system_metrics() {
    log "Collecting system resource metrics..."
    
    # CPU usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # Memory usage
    local memory_usage
    memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    # Disk usage
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    # Load average
    local load_1min load_5min load_15min
    read -r load_1min load_5min load_15min < <(uptime | awk -F'load average:' '{print $2}' | sed 's/,//g')
    
    cat >> "$TEMP_METRICS_FILE" << EOF
github_runner_system_cpu_usage $cpu_usage
github_runner_system_memory_usage $memory_usage
github_runner_system_disk_usage $disk_usage
github_runner_system_load_1min $load_1min
github_runner_system_load_5min $load_5min
github_runner_system_load_15min $load_15min
EOF
}

# Collect container metrics
collect_container_metrics() {
    log "Collecting container metrics..."
    
    local containers=("github-runner" "metrics_collector" "health_monitor" "log_aggregator" "nginx_proxy")
    
    for container in "${containers[@]}"; do
        local status=0
        local restarts=0
        local cpu_usage=0
        local memory_usage=0
        
        if docker ps --filter "name=$container" --format "table {{.Names}}" | grep -q "$container"; then
            status=1
            
            # Get restart count
            restarts=$(docker inspect "$container" --format='{{.RestartCount}}' 2>/dev/null || echo "0")
            
            # Get resource usage (simplified)
            local stats
            stats=$(docker stats "$container" --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" 2>/dev/null || echo "0.00%,0.00%")
            cpu_usage=$(echo "$stats" | cut -d',' -f1 | sed 's/%//')
            memory_usage=$(echo "$stats" | cut -d',' -f2 | sed 's/%//')
        fi
        
        cat >> "$TEMP_METRICS_FILE" << EOF
github_runner_container_status{container="$container"} $status
github_runner_container_restarts_total{container="$container"} $restarts
github_runner_container_cpu_usage{container="$container"} $cpu_usage
github_runner_container_memory_usage{container="$container"} $memory_usage
EOF
    done
}

# Collect network connectivity metrics
collect_network_metrics() {
    log "Collecting network connectivity metrics..."
    
    local github_api_status=0
    local homelab_endpoints_reachable=0
    local total_endpoints=3
    local network_errors=0
    
    # Test GitHub API
    if curl -s -f --max-time 10 "https://api.github.com" >/dev/null 2>&1; then
        github_api_status=1
    else
        network_errors=$((network_errors + 1))
    fi
    
    # Test homelab endpoints
    local endpoints=("192.168.1.155:8123" "192.168.1.137:8006" "192.168.1.90:3000")
    
    for endpoint in "${endpoints[@]}"; do
        if nc -z -w 3 ${endpoint/:/ } 2>/dev/null; then
            homelab_endpoints_reachable=$((homelab_endpoints_reachable + 1))
        else
            network_errors=$((network_errors + 1))
        fi
    done
    
    local homelab_connectivity_ratio
    homelab_connectivity_ratio=$(echo "scale=2; $homelab_endpoints_reachable / $total_endpoints" | bc)
    
    cat >> "$TEMP_METRICS_FILE" << EOF
github_runner_github_api_status $github_api_status
github_runner_homelab_endpoints_reachable $homelab_endpoints_reachable
github_runner_homelab_connectivity_ratio $homelab_connectivity_ratio
github_runner_network_errors_total $network_errors
EOF
}

# Collect custom business metrics
collect_business_metrics() {
    log "Collecting business metrics..."
    
    local deployment_success_rate=0
    local avg_job_duration=0
    local workflows_triggered_today=0
    
    # Get deployment statistics from logs (simplified)
    local logs
    logs=$(docker logs --since="24h" github-runner 2>/dev/null || echo "")
    
    if [[ -n "$logs" ]]; then
        local total_deployments success_deployments
        total_deployments=$(echo "$logs" | grep -c "deployment" || echo "0")
        success_deployments=$(echo "$logs" | grep -c "deployment.*success" || echo "0")
        
        if [[ $total_deployments -gt 0 ]]; then
            deployment_success_rate=$(echo "scale=2; $success_deployments / $total_deployments" | bc)
        fi
        
        workflows_triggered_today=$(echo "$logs" | grep -c "workflow.*triggered" || echo "0")
    fi
    
    cat >> "$TEMP_METRICS_FILE" << EOF
github_runner_deployment_success_rate $deployment_success_rate
github_runner_avg_job_duration_seconds $avg_job_duration
github_runner_workflows_triggered_today $workflows_triggered_today
EOF
}

# Add timestamp to all metrics
add_timestamp() {
    local timestamp
    timestamp=$(date +%s)000  # Prometheus expects milliseconds
    
    # Add timestamp to each metric line
    sed "s/$/ $timestamp/" "$TEMP_METRICS_FILE" > "$METRICS_FILE"
    rm -f "$TEMP_METRICS_FILE"
}

# Expose metrics via HTTP
start_metrics_server() {
    log "Starting metrics server on port $METRICS_PORT..."
    
    # Simple HTTP server to expose metrics
    while true; do
        # Create a simple HTTP response
        {
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n"
            cat "$METRICS_FILE"
        } | nc -l -p "$METRICS_PORT" -q 1 2>/dev/null || sleep 1
    done &
    
    echo $! > "$METRICS_DIR/metrics_server.pid"
    log "Metrics server started with PID $(cat "$METRICS_DIR/metrics_server.pid")"
}

# Stop metrics server
stop_metrics_server() {
    if [[ -f "$METRICS_DIR/metrics_server.pid" ]]; then
        local pid
        pid=$(cat "$METRICS_DIR/metrics_server.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log "Metrics server stopped"
        fi
        rm -f "$METRICS_DIR/metrics_server.pid"
    fi
}

# Collect all metrics
collect_all_metrics() {
    log "Starting metrics collection cycle..."
    
    # Initialize temp file
    > "$TEMP_METRICS_FILE"
    
    # Collect all metric types
    collect_job_metrics
    collect_system_metrics
    collect_container_metrics
    collect_network_metrics
    collect_business_metrics
    
    # Add timestamp and finalize
    add_timestamp
    
    log "Metrics collection completed"
}

# Continuous collection mode
run_continuous_collection() {
    log "Starting continuous metrics collection (interval: ${COLLECTION_INTERVAL}s)"
    
    while true; do
        collect_all_metrics
        sleep "$COLLECTION_INTERVAL"
    done
}

# Integration with Prometheus node_exporter textfile collector
export_to_textfile_collector() {
    local textfile_dir="${TEXTFILE_COLLECTOR_DIR:-/var/lib/node_exporter/textfile_collector}"
    
    if [[ -d "$textfile_dir" ]]; then
        cp "$METRICS_FILE" "$textfile_dir/github_runner.prom"
        log "Metrics exported to textfile collector: $textfile_dir/github_runner.prom"
    else
        log "Textfile collector directory not found: $textfile_dir"
    fi
}

# Health check for metrics collector
health_check() {
    local health_status="healthy"
    local last_collection_time=0
    
    if [[ -f "$METRICS_FILE" ]]; then
        last_collection_time=$(stat -c %Y "$METRICS_FILE")
        local current_time
        current_time=$(date +%s)
        local time_diff=$((current_time - last_collection_time))
        
        if [[ $time_diff -gt $((COLLECTION_INTERVAL * 3)) ]]; then
            health_status="stale"
        fi
    else
        health_status="no_metrics"
    fi
    
    echo "{\"status\": \"$health_status\", \"last_collection\": $last_collection_time}"
}

# Main execution
main() {
    case "${1:-collect}" in
        "collect")
            initialize_metrics
            collect_all_metrics
            export_to_textfile_collector
            ;;
        "server")
            initialize_metrics
            start_metrics_server
            trap stop_metrics_server EXIT
            run_continuous_collection
            ;;
        "stop")
            stop_metrics_server
            ;;
        "health")
            health_check
            ;;
        "export")
            export_to_textfile_collector
            ;;
        *)
            echo "Usage: $0 {collect|server|stop|health|export}"
            echo "  collect - Collect metrics once and exit"
            echo "  server  - Start metrics server and continuous collection"
            echo "  stop    - Stop metrics server"
            echo "  health  - Check metrics collector health"
            echo "  export  - Export metrics to textfile collector"
            exit 1
            ;;
    esac
}

# Ensure directories exist
mkdir -p "$METRICS_DIR" "$(dirname "$LOG_FILE")"

# Handle script execution
main "$@"