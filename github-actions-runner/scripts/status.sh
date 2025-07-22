#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Display GitHub Actions runner status information

OPTIONS:
    -h, --help          Show this help message
    -j, --json          Output in JSON format
    -s, --summary       Show summary only
    -d, --detailed      Show detailed information
    -w, --watch         Watch mode (refresh every N seconds)
    --refresh SECONDS   Refresh interval for watch mode [default: 5]
    -q, --quiet         Quiet mode (minimal output)
    -v, --verbose       Verbose output

Examples:
    $0                  # Show standard status
    $0 --json          # JSON output
    $0 --detailed      # Detailed information
    $0 --watch         # Watch mode
EOF
}

JSON_OUTPUT=false
SUMMARY_ONLY=false
DETAILED=false
WATCH_MODE=false
REFRESH_INTERVAL=5
QUIET=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -s|--summary)
            SUMMARY_ONLY=true
            shift
            ;;
        -d|--detailed)
            DETAILED=true
            shift
            ;;
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        --refresh)
            REFRESH_INTERVAL="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ "$SUMMARY_ONLY" == true ]] && [[ "$DETAILED" == true ]]; then
    log_error "Cannot specify both --summary and --detailed"
    exit 1
fi

load_configuration() {
    local config_file="/etc/github-runner/config.env"
    if [[ ! -f "$config_file" ]]; then
        config_file="$PROJECT_ROOT/config/runner.env"
    fi
    
    if [[ -f "$config_file" ]]; then
        set -a
        source "$config_file"
        set +a
    fi
}

get_systemd_status() {
    local status_info="{}"
    
    if command -v systemctl >/dev/null 2>&1; then
        local active_state
        active_state=$(systemctl is-active github-runner.service 2>/dev/null || echo "unknown")
        
        local enabled_state
        enabled_state=$(systemctl is-enabled github-runner.service 2>/dev/null || echo "unknown")
        
        local failed_state
        failed_state=$(systemctl is-failed github-runner.service 2>/dev/null || echo "unknown")
        
        local uptime=""
        if [[ "$active_state" == "active" ]]; then
            uptime=$(systemctl show github-runner.service --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
            if [[ -n "$uptime" ]]; then
                uptime=$(date -d "$uptime" +%s 2>/dev/null || echo "")
                if [[ -n "$uptime" ]]; then
                    local current_time=$(date +%s)
                    uptime=$((current_time - uptime))
                fi
            fi
        fi
        
        local memory_usage=""
        local cpu_usage=""
        if [[ "$active_state" == "active" ]]; then
            memory_usage=$(systemctl show github-runner.service --property=MemoryCurrent --value 2>/dev/null || echo "")
            
            # Get CPU usage from recent journalctl entries
            local main_pid
            main_pid=$(systemctl show github-runner.service --property=MainPID --value 2>/dev/null || echo "")
            if [[ -n "$main_pid" ]] && [[ "$main_pid" != "0" ]]; then
                cpu_usage=$(ps -p "$main_pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "")
            fi
        fi
        
        status_info=$(cat << EOF
{
    "active": "$active_state",
    "enabled": "$enabled_state",
    "failed": "$failed_state",
    "uptime_seconds": ${uptime:-null},
    "memory_bytes": ${memory_usage:-null},
    "cpu_percent": ${cpu_usage:-null}
}
EOF
)
    fi
    
    echo "$status_info"
}

get_docker_status() {
    local status_info="{}"
    
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]] && command -v docker-compose >/dev/null 2>&1; then
        cd "$PROJECT_ROOT"
        
        local containers_info="[]"
        if docker-compose config >/dev/null 2>&1; then
            local container_data=""
            
            while IFS= read -r service; do
                local container_id
                container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
                
                local container_status="not-found"
                local health_status="unknown"
                local uptime=""
                local memory_usage=""
                local cpu_usage=""
                
                if [[ -n "$container_id" ]]; then
                    container_status=$(docker inspect "$container_id" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
                    health_status=$(docker inspect "$container_id" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
                    
                    if [[ "$container_status" == "running" ]]; then
                        local started_at
                        started_at=$(docker inspect "$container_id" --format='{{.State.StartedAt}}' 2>/dev/null || echo "")
                        if [[ -n "$started_at" ]]; then
                            local started_timestamp
                            started_timestamp=$(date -d "$started_at" +%s 2>/dev/null || echo "")
                            if [[ -n "$started_timestamp" ]]; then
                                local current_time=$(date +%s)
                                uptime=$((current_time - started_timestamp))
                            fi
                        fi
                        
                        # Get resource usage
                        local stats
                        stats=$(docker stats "$container_id" --no-stream --format "{{.MemUsage}},{{.CPUPerc}}" 2>/dev/null || echo ",")
                        IFS=',' read -r mem_info cpu_info <<< "$stats"
                        
                        if [[ -n "$mem_info" ]] && [[ "$mem_info" != " " ]]; then
                            memory_usage=$(echo "$mem_info" | cut -d'/' -f1 | tr -d ' ')
                        fi
                        
                        if [[ -n "$cpu_info" ]] && [[ "$cpu_info" != " " ]]; then
                            cpu_usage=$(echo "$cpu_info" | tr -d '%' | tr -d ' ')
                        fi
                    fi
                fi
                
                local container_json
                container_json=$(cat << EOF
{
    "service": "$service",
    "container_id": "${container_id:-null}",
    "status": "$container_status",
    "health": "$health_status",
    "uptime_seconds": ${uptime:-null},
    "memory_usage": "${memory_usage:-null}",
    "cpu_percent": "${cpu_usage:-null}"
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
                containers_info="[$container_data]"
            fi
        fi
        
        local running_count=0
        local total_count=0
        if command -v jq >/dev/null 2>&1; then
            running_count=$(echo "$containers_info" | jq '[.[] | select(.status == "running")] | length' 2>/dev/null || echo 0)
            total_count=$(echo "$containers_info" | jq 'length' 2>/dev/null || echo 0)
        fi
        
        status_info=$(cat << EOF
{
    "containers": $containers_info,
    "running_count": $running_count,
    "total_count": $total_count
}
EOF
)
    fi
    
    echo "$status_info"
}

get_runner_status() {
    local status_info="{}"
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    
    if [[ -d "$install_path" ]]; then
        local runner_config=""
        local is_configured=false
        local is_registered=false
        local runner_name=""
        local repository_url=""
        local labels=""
        
        if [[ -f "$install_path/.runner" ]]; then
            is_configured=true
            runner_config=$(cat "$install_path/.runner" 2>/dev/null || echo "{}")
            
            if command -v jq >/dev/null 2>&1 && validate_json "$runner_config"; then
                runner_name=$(echo "$runner_config" | jq -r '.agentName // ""')
                repository_url=$(echo "$runner_config" | jq -r '.repositoryUrl // ""')
                labels=$(echo "$runner_config" | jq -r '.labels // []' | jq -c .)
            fi
            
            # Check if runner is registered
            if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
                is_registered=true
            fi
        fi
        
        local work_dir_size=""
        if [[ -d "$install_path/_work" ]]; then
            work_dir_size=$(du -sh "$install_path/_work" 2>/dev/null | cut -f1 || echo "unknown")
        fi
        
        local log_file_size=""
        if [[ -f "/var/log/github-runner/runner.log" ]]; then
            log_file_size=$(du -sh "/var/log/github-runner/runner.log" 2>/dev/null | cut -f1 || echo "unknown")
        fi
        
        status_info=$(cat << EOF
{
    "configured": $is_configured,
    "registered": $is_registered,
    "name": "${runner_name:-null}",
    "repository": "${repository_url:-null}",
    "labels": ${labels:-null},
    "install_path": "$install_path",
    "work_directory_size": "${work_dir_size:-null}",
    "log_file_size": "${log_file_size:-null}"
}
EOF
)
    fi
    
    echo "$status_info"
}

get_system_status() {
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    local memory_info
    memory_info=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//' | cut -d',' -f1)
    
    local network_status="unknown"
    if curl -s --connect-timeout 5 https://api.github.com/rate_limit >/dev/null 2>&1; then
        network_status="connected"
    else
        network_status="disconnected"
    fi
    
    cat << EOF
{
    "hostname": "$(hostname)",
    "uptime": "$(uptime -p 2>/dev/null || echo 'unknown')",
    "load_average": "${load_avg:-unknown}",
    "disk_usage_percent": $disk_usage,
    "memory_usage_percent": $memory_info,
    "github_connectivity": "$network_status",
    "timestamp": "$(date -Iseconds)"
}
EOF
}

get_health_summary() {
    local health_status="unknown"
    local health_details="{}"
    
    local health_script="$SCRIPT_DIR/health-check.sh"
    if [[ -x "$health_script" ]]; then
        if "$health_script" --quick --json >/dev/null 2>&1; then
            health_status="healthy"
            health_details=$("$health_script" --quick --json 2>/dev/null || echo "{}")
        else
            health_status="unhealthy"
        fi
    fi
    
    cat << EOF
{
    "status": "$health_status",
    "details": $health_details
}
EOF
}

display_json_status() {
    local systemd_status
    systemd_status=$(get_systemd_status)
    
    local docker_status
    docker_status=$(get_docker_status)
    
    local runner_status
    runner_status=$(get_runner_status)
    
    local system_status
    system_status=$(get_system_status)
    
    local health_status
    health_status=$(get_health_summary)
    
    cat << EOF
{
    "systemd": $systemd_status,
    "docker": $docker_status,
    "runner": $runner_status,
    "system": $system_status,
    "health": $health_status
}
EOF
}

display_summary_status() {
    load_configuration
    
    local systemd_state="unknown"
    if command -v systemctl >/dev/null 2>&1; then
        systemd_state=$(systemctl is-active github-runner.service 2>/dev/null || echo "inactive")
    fi
    
    local docker_state="unknown"
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        local running_containers
        running_containers=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        local total_containers
        total_containers=$(docker-compose config --services 2>/dev/null | wc -l)
        
        if [[ $total_containers -eq 0 ]]; then
            docker_state="no-containers"
        elif [[ $running_containers -eq $total_containers ]]; then
            docker_state="running"
        elif [[ $running_containers -gt 0 ]]; then
            docker_state="partial"
        else
            docker_state="stopped"
        fi
    fi
    
    local runner_state="unknown"
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ -f "$install_path/.runner" ]]; then
        if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
            runner_state="registered"
        else
            runner_state="configured"
        fi
    else
        runner_state="not-configured"
    fi
    
    echo "GitHub Actions Runner Status Summary"
    echo "=================================="
    echo "Systemd Service: $systemd_state"
    echo "Docker Containers: $docker_state"
    echo "Runner Registration: $runner_state"
    echo "Hostname: $(hostname)"
    echo "Timestamp: $(date)"
}

display_detailed_status() {
    load_configuration
    
    echo "GitHub Actions Runner Detailed Status"
    echo "===================================="
    echo
    
    # Systemd Service Status
    echo "Systemd Service:"
    echo "---------------"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status github-runner.service --no-pager || echo "Service not found"
    else
        echo "systemctl not available"
    fi
    echo
    
    # Docker Container Status
    echo "Docker Containers:"
    echo "-----------------"
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        docker-compose ps || echo "Failed to get container status"
    else
        echo "No docker-compose.yml found"
    fi
    echo
    
    # Runner Configuration
    echo "Runner Configuration:"
    echo "-------------------"
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ -f "$install_path/.runner" ]]; then
        local runner_config
        runner_config=$(cat "$install_path/.runner" 2>/dev/null || echo "{}")
        
        if command -v jq >/dev/null 2>&1 && validate_json "$runner_config"; then
            echo "Name: $(echo "$runner_config" | jq -r '.agentName // "unknown"')"
            echo "Repository: $(echo "$runner_config" | jq -r '.repositoryUrl // "unknown"')"
            echo "Labels: $(echo "$runner_config" | jq -r '.labels // [] | join(", ")')"
            echo "Agent ID: $(echo "$runner_config" | jq -r '.agentId // "unknown"')"
        else
            echo "Invalid or missing runner configuration"
        fi
        
        echo "Configuration check:"
        if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
            echo "  ✓ Runner is registered and accessible"
        else
            echo "  ✗ Runner registration check failed"
        fi
    else
        echo "Runner not configured"
    fi
    echo
    
    # System Resources
    echo "System Resources:"
    echo "----------------"
    echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"
    echo "Memory Usage: $(free -h | awk 'NR==2{printf "%s/%s (%.0f%%)", $3, $2, $3*100/$2}')"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')"
    echo "Uptime: $(uptime -p 2>/dev/null || echo 'unknown')"
    echo
    
    # Network Connectivity
    echo "Network Connectivity:"
    echo "--------------------"
    if curl -s --connect-timeout 5 https://api.github.com/rate_limit >/dev/null; then
        echo "GitHub API: ✓ Connected"
    else
        echo "GitHub API: ✗ Not accessible"
    fi
    
    # Additional diagnostics if verbose
    if [[ "$VERBOSE" == true ]]; then
        echo
        echo "Recent Logs:"
        echo "-----------"
        if command -v journalctl >/dev/null 2>&1; then
            echo "Systemd service logs (last 10 lines):"
            journalctl -u github-runner.service --no-pager -n 10 2>/dev/null || echo "No logs available"
        fi
        
        if [[ -f "/var/log/github-runner/runner.log" ]]; then
            echo
            echo "Runner logs (last 10 lines):"
            tail -n 10 /var/log/github-runner/runner.log 2>/dev/null || echo "No runner logs available"
        fi
    fi
}

display_standard_status() {
    load_configuration
    
    echo "GitHub Actions Runner Status"
    echo "============================"
    
    # Service Status
    local systemd_state="unknown"
    if command -v systemctl >/dev/null 2>&1; then
        systemd_state=$(systemctl is-active github-runner.service 2>/dev/null || echo "inactive")
        local status_icon="✗"
        if [[ "$systemd_state" == "active" ]]; then
            status_icon="✓"
        fi
        echo "Systemd Service: $status_icon $systemd_state"
    fi
    
    # Docker Status
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT"
        local running_containers
        running_containers=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        local total_containers
        total_containers=$(docker-compose config --services 2>/dev/null | wc -l)
        
        local docker_icon="✗"
        if [[ $running_containers -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
            docker_icon="✓"
        elif [[ $running_containers -gt 0 ]]; then
            docker_icon="⚠"
        fi
        echo "Docker Containers: $docker_icon $running_containers/$total_containers running"
    fi
    
    # Runner Status
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if [[ -f "$install_path/.runner" ]]; then
        local runner_config
        runner_config=$(cat "$install_path/.runner" 2>/dev/null || echo "{}")
        
        if command -v jq >/dev/null 2>&1 && validate_json "$runner_config"; then
            local runner_name
            runner_name=$(echo "$runner_config" | jq -r '.agentName // "unknown"')
            echo "Runner Name: $runner_name"
            
            local repository_url
            repository_url=$(echo "$runner_config" | jq -r '.repositoryUrl // "unknown"')
            echo "Repository: $repository_url"
        fi
        
        local registration_icon="✗"
        if cd "$install_path" && sudo -u "${USER:-github-runner}" ./config.sh --check >/dev/null 2>&1; then
            registration_icon="✓"
        fi
        echo "Registration: $registration_icon $(if [[ "$registration_icon" == "✓" ]]; then echo "active"; else echo "inactive"; fi)"
    else
        echo "Runner: ✗ not configured"
    fi
    
    # System Info
    echo "System: $(hostname) | $(uptime -p 2>/dev/null || echo 'unknown uptime')"
    
    # Quick health status
    local health_script="$SCRIPT_DIR/health-check.sh"
    if [[ -x "$health_script" ]]; then
        local health_icon="✗"
        if "$health_script" --quick >/dev/null 2>&1; then
            health_icon="✓"
        fi
        echo "Health: $health_icon $(if [[ "$health_icon" == "✓" ]]; then echo "healthy"; else echo "issues detected"; fi)"
    fi
    
    echo "Timestamp: $(date)"
}

watch_status() {
    if [[ "$JSON_OUTPUT" == true ]]; then
        while true; do
            clear
            display_json_status | jq . 2>/dev/null || display_json_status
            echo
            echo "Refreshing every ${REFRESH_INTERVAL}s... (Ctrl+C to exit)"
            sleep "$REFRESH_INTERVAL"
        done
    else
        while true; do
            clear
            if [[ "$SUMMARY_ONLY" == true ]]; then
                display_summary_status
            elif [[ "$DETAILED" == true ]]; then
                display_detailed_status
            else
                display_standard_status
            fi
            echo
            echo "Refreshing every ${REFRESH_INTERVAL}s... (Ctrl+C to exit)"
            sleep "$REFRESH_INTERVAL"
        done
    fi
}

main() {
    if [[ "$WATCH_MODE" == true ]]; then
        trap 'echo; echo "Watch mode stopped."; exit 0' INT TERM
        watch_status
    elif [[ "$JSON_OUTPUT" == true ]]; then
        display_json_status | jq . 2>/dev/null || display_json_status
    elif [[ "$SUMMARY_ONLY" == true ]]; then
        display_summary_status
    elif [[ "$DETAILED" == true ]]; then
        display_detailed_status
    else
        display_standard_status
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi