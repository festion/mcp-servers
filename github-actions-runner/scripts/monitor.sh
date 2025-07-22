#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-monitor.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Monitor GitHub Actions runner services

COMMANDS:
    check           Run monitoring checks once
    start           Start continuous monitoring
    stop            Stop continuous monitoring
    status          Show monitoring status
    alerts          Check and process alerts
    report          Generate monitoring report

OPTIONS:
    -h, --help              Show this help message
    -i, --interval SECONDS  Monitoring interval [default: 60]
    -c, --config FILE       Configuration file path
    --alert-threshold TYPE  Set alert thresholds (disk:90,memory:85,cpu:90)
    --webhook-url URL       Webhook URL for notifications
    --email EMAIL           Email address for alerts
    -j, --json              JSON output format
    -v, --verbose           Verbose output

Examples:
    $0 check                        # Run checks once
    $0 start --interval 30          # Monitor every 30 seconds
    $0 alerts --webhook-url https://hooks.slack.com/...
    $0 report --json                # JSON report
EOF
}

COMMAND=""
INTERVAL=60
CONFIG_FILE=""
ALERT_THRESHOLDS=""
WEBHOOK_URL=""
EMAIL=""
JSON_OUTPUT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --alert-threshold)
            ALERT_THRESHOLDS="$2"
            shift 2
            ;;
        --webhook-url)
            WEBHOOK_URL="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            LOG_LEVEL="DEBUG"
            shift
            ;;
        check|start|stop|status|alerts|report)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    log_error "Command is required"
    usage
    exit 1
fi

MONITOR_PID_FILE="/var/run/github-runner-monitor.pid"
MONITOR_STATUS_FILE="/var/lib/github-runner/monitor-status.json"
ALERTS_FILE="/var/lib/github-runner/alerts.json"

# Default thresholds
DISK_THRESHOLD=90
MEMORY_THRESHOLD=85
CPU_THRESHOLD=90
NETWORK_TIMEOUT=10

load_configuration() {
    local config_file
    if [[ -n "$CONFIG_FILE" ]]; then
        config_file="$CONFIG_FILE"
    else
        config_file="/etc/github-runner/config.env"
        if [[ ! -f "$config_file" ]]; then
            config_file="$PROJECT_ROOT/config/runner.env"
        fi
    fi
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading configuration from: $config_file"
        set -a
        source "$config_file"
        set +a
    fi
    
    # Parse alert thresholds if provided
    if [[ -n "$ALERT_THRESHOLDS" ]]; then
        IFS=',' read -ra THRESHOLD_PAIRS <<< "$ALERT_THRESHOLDS"
        for pair in "${THRESHOLD_PAIRS[@]}"; do
            IFS=':' read -r key value <<< "$pair"
            case "$key" in
                disk) DISK_THRESHOLD="$value" ;;
                memory) MEMORY_THRESHOLD="$value" ;;
                cpu) CPU_THRESHOLD="$value" ;;
            esac
        done
    fi
    
    # Override with environment variables
    DISK_THRESHOLD="${DISK_SPACE_WARNING_THRESHOLD:-$DISK_THRESHOLD}"
    MEMORY_THRESHOLD="${MEMORY_WARNING_THRESHOLD:-$MEMORY_THRESHOLD}"
    WEBHOOK_URL="${WEBHOOK_URL:-$WEBHOOK_URL}"
    EMAIL="${ALERT_EMAIL:-$EMAIL}"
}

check_systemd_service() {
    local status="unknown"
    local uptime_seconds=0
    local memory_mb=0
    local cpu_percent=0.0
    local restart_count=0
    local last_status_change=""
    
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active github-runner.service >/dev/null 2>&1; then
            status="active"
            
            # Get uptime
            local started_at
            started_at=$(systemctl show github-runner.service --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
            if [[ -n "$started_at" ]]; then
                local started_timestamp
                started_timestamp=$(date -d "$started_at" +%s 2>/dev/null || echo "")
                if [[ -n "$started_timestamp" ]]; then
                    uptime_seconds=$(($(date +%s) - started_timestamp))
                fi
            fi
            
            # Get memory usage
            local memory_bytes
            memory_bytes=$(systemctl show github-runner.service --property=MemoryCurrent --value 2>/dev/null || echo "0")
            if [[ "$memory_bytes" != "[not set]" ]] && [[ -n "$memory_bytes" ]] && [[ "$memory_bytes" -gt 0 ]]; then
                memory_mb=$((memory_bytes / 1024 / 1024))
            fi
            
            # Get CPU usage
            local main_pid
            main_pid=$(systemctl show github-runner.service --property=MainPID --value 2>/dev/null || echo "0")
            if [[ "$main_pid" -gt 0 ]]; then
                cpu_percent=$(ps -p "$main_pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0.0")
            fi
            
            # Get restart count
            restart_count=$(systemctl show github-runner.service --property=NRestarts --value 2>/dev/null || echo "0")
            
        elif systemctl is-enabled github-runner.service >/dev/null 2>&1; then
            status="inactive"
        else
            status="disabled"
        fi
        
        # Get last status change
        last_status_change=$(systemctl show github-runner.service --property=StateChangeTimestamp --value 2>/dev/null || echo "")
    fi
    
    cat << EOF
{
    "status": "$status",
    "uptime_seconds": $uptime_seconds,
    "memory_mb": $memory_mb,
    "cpu_percent": $cpu_percent,
    "restart_count": $restart_count,
    "last_status_change": "${last_status_change:-null}"
}
EOF
}

check_docker_containers() {
    local containers_status="[]"
    
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]] && command -v docker-compose >/dev/null 2>&1; then
        cd "$PROJECT_ROOT"
        
        local container_data=""
        
        while IFS= read -r service; do
            local container_id
            container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
            
            local status="not-found"
            local health="unknown"
            local uptime_seconds=0
            local memory_mb=0
            local cpu_percent=0.0
            local restart_count=0
            
            if [[ -n "$container_id" ]]; then
                status=$(docker inspect "$container_id" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
                health=$(docker inspect "$container_id" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
                restart_count=$(docker inspect "$container_id" --format='{{.RestartCount}}' 2>/dev/null || echo "0")
                
                if [[ "$status" == "running" ]]; then
                    # Get uptime
                    local started_at
                    started_at=$(docker inspect "$container_id" --format='{{.State.StartedAt}}' 2>/dev/null || echo "")
                    if [[ -n "$started_at" ]]; then
                        local started_timestamp
                        started_timestamp=$(date -d "$started_at" +%s 2>/dev/null || echo "")
                        if [[ -n "$started_timestamp" ]]; then
                            uptime_seconds=$(($(date +%s) - started_timestamp))
                        fi
                    fi
                    
                    # Get resource usage
                    local stats
                    stats=$(timeout 5 docker stats "$container_id" --no-stream --format "{{.MemUsage}},{{.CPUPerc}}" 2>/dev/null || echo ",")
                    IFS=',' read -r mem_info cpu_info <<< "$stats"
                    
                    if [[ -n "$mem_info" ]] && [[ "$mem_info" != " " ]]; then
                        local memory_raw
                        memory_raw=$(echo "$mem_info" | cut -d'/' -f1 | tr -d ' ')
                        if [[ "$memory_raw" =~ ([0-9.]+)([KMGT]?)i?B? ]]; then
                            local value="${BASH_REMATCH[1]}"
                            local unit="${BASH_REMATCH[2]}"
                            case "$unit" in
                                K) memory_mb=$(echo "$value / 1024" | bc -l 2>/dev/null || echo "0") ;;
                                M) memory_mb=$(echo "$value" | cut -d'.' -f1) ;;
                                G) memory_mb=$(echo "$value * 1024" | bc -l 2>/dev/null || echo "0") ;;
                                *) memory_mb=0 ;;
                            esac
                        fi
                    fi
                    
                    if [[ -n "$cpu_info" ]] && [[ "$cpu_info" != " " ]]; then
                        cpu_percent=$(echo "$cpu_info" | tr -d '%' | tr -d ' ')
                    fi
                fi
            fi
            
            local container_json
            container_json=$(cat << EOF
{
    "service": "$service",
    "container_id": "${container_id:-null}",
    "status": "$status",
    "health": "$health",
    "uptime_seconds": $uptime_seconds,
    "memory_mb": $(printf "%.0f" "${memory_mb:-0}"),
    "cpu_percent": $cpu_percent,
    "restart_count": $restart_count
}
EOF
)
            
            if [[ -z "$container_data" ]]; then
                container_data="$container_json"
            else
                container_data="$container_data,$container_json"
            fi
            
        done < <(docker-compose config --services 2>/dev/null)
        
        if [[ -n "$container_data" ]]; then
            containers_status="[$container_data]"
        fi
    fi
    
    echo "$containers_status"
}

check_runner_health() {
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    local is_configured=false
    local is_registered=false
    local runner_name=""
    local repository_url=""
    local last_job_time=""
    local running_jobs=0
    local work_dir_size_mb=0
    
    if [[ -f "$install_path/.runner" ]]; then
        is_configured=true
        
        local runner_config
        runner_config=$(cat "$install_path/.runner" 2>/dev/null || echo "{}")
        
        if command -v jq >/dev/null 2>&1 && validate_json "$runner_config"; then
            runner_name=$(echo "$runner_config" | jq -r '.agentName // ""')
            repository_url=$(echo "$runner_config" | jq -r '.repositoryUrl // ""')
        fi
        
        # Check registration
        if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
            is_registered=true
        fi
        
        # Check for running jobs
        if [[ -d "$install_path/_work" ]]; then
            running_jobs=$(find "$install_path/_work" -name "*.pid" 2>/dev/null | wc -l)
            
            # Get work directory size
            local work_size
            work_size=$(du -sm "$install_path/_work" 2>/dev/null | cut -f1 || echo "0")
            work_dir_size_mb=$work_size
            
            # Get last job time from work directory
            local latest_file
            latest_file=$(find "$install_path/_work" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || echo "")
            if [[ -n "$latest_file" ]]; then
                last_job_time=$(stat -c %Y "$latest_file" 2>/dev/null || echo "")
            fi
        fi
    fi
    
    cat << EOF
{
    "configured": $is_configured,
    "registered": $is_registered,
    "name": "${runner_name:-null}",
    "repository": "${repository_url:-null}",
    "running_jobs": $running_jobs,
    "work_directory_size_mb": $work_dir_size_mb,
    "last_job_timestamp": ${last_job_time:-null}
}
EOF
}

check_system_resources() {
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    local memory_usage
    memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//' | cut -d',' -f1 | tr -d ' ')
    
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | tr -d ' ' || echo "0")
    
    local total_memory_mb
    total_memory_mb=$(free -m | awk 'NR==2{print $2}')
    
    local used_memory_mb
    used_memory_mb=$(free -m | awk 'NR==2{print $3}')
    
    local disk_total_gb
    disk_total_gb=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    
    local disk_used_gb
    disk_used_gb=$(df -BG / | awk 'NR==2 {print $3}' | sed 's/G//')
    
    cat << EOF
{
    "disk_usage_percent": $disk_usage,
    "disk_total_gb": $disk_total_gb,
    "disk_used_gb": $disk_used_gb,
    "memory_usage_percent": $memory_usage,
    "memory_total_mb": $total_memory_mb,
    "memory_used_mb": $used_memory_mb,
    "cpu_usage_percent": $cpu_usage,
    "load_average": "${load_avg:-0}"
}
EOF
}

check_network_connectivity() {
    local github_status="unknown"
    local github_response_time=0
    local dns_status="unknown"
    local internet_status="unknown"
    
    # Test GitHub API
    local start_time=$(date +%s%3N)
    if curl -s --connect-timeout "$NETWORK_TIMEOUT" https://api.github.com/rate_limit >/dev/null 2>&1; then
        github_status="connected"
        local end_time=$(date +%s%3N)
        github_response_time=$((end_time - start_time))
    else
        github_status="disconnected"
    fi
    
    # Test DNS resolution
    if nslookup github.com >/dev/null 2>&1; then
        dns_status="working"
    else
        dns_status="failed"
    fi
    
    # Test general internet connectivity
    if curl -s --connect-timeout 5 https://1.1.1.1 >/dev/null 2>&1; then
        internet_status="connected"
    else
        internet_status="disconnected"
    fi
    
    cat << EOF
{
    "github_api": "$github_status",
    "github_response_time_ms": $github_response_time,
    "dns_resolution": "$dns_status",
    "internet_connectivity": "$internet_status"
}
EOF
}

generate_alerts() {
    local alerts="[]"
    local current_time=$(date +%s)
    
    # Get current status
    local systemd_status
    systemd_status=$(check_systemd_service)
    
    local system_resources
    system_resources=$(check_system_resources)
    
    local network_status
    network_status=$(check_network_connectivity)
    
    local alert_data=""
    
    # Service down alert
    local service_status
    service_status=$(echo "$systemd_status" | jq -r '.status')
    if [[ "$service_status" != "active" ]]; then
        local alert_json
        alert_json=$(cat << EOF
{
    "id": "service-down",
    "severity": "critical",
    "message": "GitHub Actions runner service is not active (status: $service_status)",
    "timestamp": $current_time,
    "category": "service"
}
EOF
)
        alert_data="$alert_json"
    fi
    
    # Disk space alert
    local disk_usage
    disk_usage=$(echo "$system_resources" | jq -r '.disk_usage_percent')
    if [[ "$disk_usage" -gt "$DISK_THRESHOLD" ]]; then
        local alert_json
        alert_json=$(cat << EOF
{
    "id": "disk-space-high",
    "severity": "warning",
    "message": "Disk usage is ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)",
    "timestamp": $current_time,
    "category": "resources",
    "value": $disk_usage,
    "threshold": $DISK_THRESHOLD
}
EOF
)
        if [[ -n "$alert_data" ]]; then
            alert_data="$alert_data,$alert_json"
        else
            alert_data="$alert_json"
        fi
    fi
    
    # Memory usage alert
    local memory_usage
    memory_usage=$(echo "$system_resources" | jq -r '.memory_usage_percent')
    if [[ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]]; then
        local alert_json
        alert_json=$(cat << EOF
{
    "id": "memory-usage-high",
    "severity": "warning",
    "message": "Memory usage is ${memory_usage}% (threshold: ${MEMORY_THRESHOLD}%)",
    "timestamp": $current_time,
    "category": "resources",
    "value": $memory_usage,
    "threshold": $MEMORY_THRESHOLD
}
EOF
)
        if [[ -n "$alert_data" ]]; then
            alert_data="$alert_data,$alert_json"
        else
            alert_data="$alert_json"
        fi
    fi
    
    # CPU usage alert
    local cpu_usage
    cpu_usage=$(echo "$system_resources" | jq -r '.cpu_usage_percent')
    if [[ $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        local alert_json
        alert_json=$(cat << EOF
{
    "id": "cpu-usage-high",
    "severity": "warning",
    "message": "CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)",
    "timestamp": $current_time,
    "category": "resources",
    "value": $cpu_usage,
    "threshold": $CPU_THRESHOLD
}
EOF
)
        if [[ -n "$alert_data" ]]; then
            alert_data="$alert_data,$alert_json"
        else
            alert_data="$alert_json"
        fi
    fi
    
    # Network connectivity alert
    local github_status
    github_status=$(echo "$network_status" | jq -r '.github_api')
    if [[ "$github_status" != "connected" ]]; then
        local alert_json
        alert_json=$(cat << EOF
{
    "id": "github-connectivity",
    "severity": "critical",
    "message": "Cannot connect to GitHub API",
    "timestamp": $current_time,
    "category": "network"
}
EOF
)
        if [[ -n "$alert_data" ]]; then
            alert_data="$alert_data,$alert_json"
        else
            alert_data="$alert_json"
        fi
    fi
    
    if [[ -n "$alert_data" ]]; then
        alerts="[$alert_data]"
    fi
    
    echo "$alerts"
}

send_alert_notifications() {
    local alerts="$1"
    
    if [[ "$alerts" == "[]" ]]; then
        return 0
    fi
    
    local alert_count
    alert_count=$(echo "$alerts" | jq length)
    
    if [[ "$alert_count" -gt 0 ]]; then
        log_warn "$alert_count alert(s) detected"
        
        # Send webhook notification
        if [[ -n "$WEBHOOK_URL" ]]; then
            local hostname=$(hostname)
            local message="GitHub Actions Runner Alert on $hostname"
            local details
            details=$(echo "$alerts" | jq -r '.[] | "- \(.severity | ascii_upcase): \(.message)"' | head -5)
            
            send_notification "error" "$message" "$details"
        fi
        
        # Send email if configured
        if [[ -n "$EMAIL" ]] && command -v mail >/dev/null 2>&1; then
            local subject="GitHub Actions Runner Alert - $(hostname)"
            local body
            body=$(echo "$alerts" | jq -r '.[] | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")): \(.severity | ascii_upcase): \(.message)"')
            
            echo "$body" | mail -s "$subject" "$EMAIL" 2>/dev/null || log_warn "Failed to send email alert"
        fi
        
        # Log to system
        echo "$alerts" | jq -r '.[] | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")): \(.severity | ascii_upcase): \(.message)"' | while read -r alert_line; do
            log_warn "$alert_line"
        done
    fi
}

run_monitoring_check() {
    local timestamp=$(date +%s)
    
    log_debug "Running monitoring check..."
    
    local systemd_status
    systemd_status=$(check_systemd_service)
    
    local docker_status
    docker_status=$(check_docker_containers)
    
    local runner_status
    runner_status=$(check_runner_health)
    
    local system_resources
    system_resources=$(check_system_resources)
    
    local network_status
    network_status=$(check_network_connectivity)
    
    local alerts
    alerts=$(generate_alerts)
    
    local monitoring_data
    monitoring_data=$(cat << EOF
{
    "timestamp": $timestamp,
    "systemd": $systemd_status,
    "docker": $docker_status,
    "runner": $runner_status,
    "system": $system_resources,
    "network": $network_status,
    "alerts": $alerts,
    "thresholds": {
        "disk_percent": $DISK_THRESHOLD,
        "memory_percent": $MEMORY_THRESHOLD,
        "cpu_percent": $CPU_THRESHOLD
    }
}
EOF
)
    
    # Save monitoring status
    mkdir -p "$(dirname "$MONITOR_STATUS_FILE")"
    echo "$monitoring_data" > "$MONITOR_STATUS_FILE"
    
    # Save alerts separately
    mkdir -p "$(dirname "$ALERTS_FILE")"
    echo "$alerts" > "$ALERTS_FILE"
    
    # Send notifications if alerts exist
    send_alert_notifications "$alerts"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$monitoring_data" | jq .
    else
        local alert_count
        alert_count=$(echo "$alerts" | jq length)
        
        if [[ "$alert_count" -gt 0 ]]; then
            log_warn "Monitoring check completed with $alert_count alert(s)"
        else
            log_success "Monitoring check completed - all systems healthy"
        fi
    fi
}

start_monitoring() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_error "Monitoring is already running (PID: $existing_pid)"
            exit 1
        else
            log_warn "Removing stale PID file"
            rm -f "$MONITOR_PID_FILE"
        fi
    fi
    
    log_info "Starting continuous monitoring (interval: ${INTERVAL}s)"
    
    # Background monitoring loop
    (
        echo $$ > "$MONITOR_PID_FILE"
        
        while true; do
            run_monitoring_check
            sleep "$INTERVAL"
        done
    ) &
    
    local monitor_pid=$!
    echo "$monitor_pid" > "$MONITOR_PID_FILE"
    
    log_success "Monitoring started (PID: $monitor_pid)"
}

stop_monitoring() {
    if [[ ! -f "$MONITOR_PID_FILE" ]]; then
        log_warn "Monitoring is not running"
        return 0
    fi
    
    local monitor_pid
    monitor_pid=$(cat "$MONITOR_PID_FILE")
    
    if kill -0 "$monitor_pid" 2>/dev/null; then
        log_info "Stopping monitoring (PID: $monitor_pid)"
        kill "$monitor_pid"
        
        # Wait for process to stop
        local count=0
        while kill -0 "$monitor_pid" 2>/dev/null && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        if kill -0 "$monitor_pid" 2>/dev/null; then
            log_warn "Force killing monitoring process"
            kill -9 "$monitor_pid"
        fi
        
        rm -f "$MONITOR_PID_FILE"
        log_success "Monitoring stopped"
    else
        log_warn "Monitoring process not found, removing PID file"
        rm -f "$MONITOR_PID_FILE"
    fi
}

show_monitoring_status() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local monitor_pid
        monitor_pid=$(cat "$MONITOR_PID_FILE")
        
        if kill -0 "$monitor_pid" 2>/dev/null; then
            log_info "Monitoring is running (PID: $monitor_pid, interval: ${INTERVAL}s)"
            
            if [[ -f "$MONITOR_STATUS_FILE" ]]; then
                local last_check
                last_check=$(jq -r '.timestamp' "$MONITOR_STATUS_FILE" 2>/dev/null || echo "")
                if [[ -n "$last_check" ]]; then
                    local last_check_human
                    last_check_human=$(date -d "@$last_check" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
                    log_info "Last check: $last_check_human"
                fi
            fi
        else
            log_warn "Monitoring process not found (stale PID file)"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        log_info "Monitoring is not running"
    fi
    
    # Show recent alerts
    if [[ -f "$ALERTS_FILE" ]]; then
        local alert_count
        alert_count=$(jq length "$ALERTS_FILE" 2>/dev/null || echo "0")
        if [[ "$alert_count" -gt 0 ]]; then
            log_warn "Active alerts: $alert_count"
            if [[ "$VERBOSE" == true ]]; then
                jq -r '.[] | "  - \(.severity | ascii_upcase): \(.message)"' "$ALERTS_FILE" 2>/dev/null || true
            fi
        else
            log_success "No active alerts"
        fi
    fi
}

check_alerts() {
    if [[ ! -f "$ALERTS_FILE" ]]; then
        log_info "No alerts file found"
        return 0
    fi
    
    local alerts
    alerts=$(cat "$ALERTS_FILE")
    local alert_count
    alert_count=$(echo "$alerts" | jq length)
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$alerts" | jq .
    else
        if [[ "$alert_count" -gt 0 ]]; then
            log_warn "$alert_count active alert(s):"
            echo "$alerts" | jq -r '.[] | "  [\(.timestamp | strftime("%H:%M:%S"))] \(.severity | ascii_upcase): \(.message)"'
        else
            log_success "No active alerts"
        fi
    fi
}

generate_report() {
    local report_data="{}"
    
    if [[ -f "$MONITOR_STATUS_FILE" ]]; then
        report_data=$(cat "$MONITOR_STATUS_FILE")
    else
        # Generate fresh report
        report_data=$(cat << EOF
{
    "timestamp": $(date +%s),
    "systemd": $(check_systemd_service),
    "docker": $(check_docker_containers),
    "runner": $(check_runner_health),
    "system": $(check_system_resources),
    "network": $(check_network_connectivity),
    "alerts": $(generate_alerts)
}
EOF
)
    fi
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$report_data" | jq .
    else
        echo "GitHub Actions Runner Monitoring Report"
        echo "======================================="
        echo
        
        local timestamp
        timestamp=$(echo "$report_data" | jq -r '.timestamp')
        echo "Generated: $(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')"
        echo
        
        # Service status
        local systemd_status
        systemd_status=$(echo "$report_data" | jq -r '.systemd.status')
        echo "Service Status: $systemd_status"
        
        # Resource usage
        local disk_usage
        disk_usage=$(echo "$report_data" | jq -r '.system.disk_usage_percent')
        local memory_usage
        memory_usage=$(echo "$report_data" | jq -r '.system.memory_usage_percent')
        echo "Disk Usage: ${disk_usage}%"
        echo "Memory Usage: ${memory_usage}%"
        
        # Network status
        local github_status
        github_status=$(echo "$report_data" | jq -r '.network.github_api')
        echo "GitHub Connectivity: $github_status"
        
        # Alerts
        local alert_count
        alert_count=$(echo "$report_data" | jq '.alerts | length')
        echo "Active Alerts: $alert_count"
        
        if [[ "$alert_count" -gt 0 ]]; then
            echo
            echo "Alert Details:"
            echo "$report_data" | jq -r '.alerts[] | "  - \(.severity | ascii_upcase): \(.message)"'
        fi
    fi
}

main() {
    load_configuration
    
    case "$COMMAND" in
        check)
            run_monitoring_check
            ;;
        start)
            start_monitoring
            ;;
        stop)
            stop_monitoring
            ;;
        status)
            show_monitoring_status
            ;;
        alerts)
            check_alerts
            ;;
        report)
            generate_report
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi