#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/github-runner-diagnostics.log"

source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/utils.sh"

setup_logging

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Collect and analyze GitHub Actions runner diagnostics

COMMANDS:
    collect         Collect all diagnostic information
    system          System information only
    service         Service status and logs
    network         Network connectivity tests
    performance     Performance metrics
    logs            Collect and analyze logs
    package         Create diagnostic package

OPTIONS:
    -h, --help          Show this help message
    -o, --output DIR    Output directory [default: /tmp/github-runner-diagnostics]
    --include-logs      Include log files in output
    --log-lines LINES   Number of log lines to include [default: 1000]
    --since DURATION    Collect logs since duration (1h, 1d, 1w) [default: 24h]
    -j, --json          JSON output format
    -v, --verbose       Verbose output
    --sensitive         Include potentially sensitive information

Examples:
    $0 collect                          # Full diagnostic collection
    $0 system --json                   # System info in JSON
    $0 logs --since 1h                 # Last hour of logs
    $0 package --output /tmp/diag      # Create diagnostic package
EOF
}

COMMAND="collect"
OUTPUT_DIR="/tmp/github-runner-diagnostics"
INCLUDE_LOGS=false
LOG_LINES=1000
SINCE="24h"
JSON_OUTPUT=false
VERBOSE=false
INCLUDE_SENSITIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --include-logs)
            INCLUDE_LOGS=true
            shift
            ;;
        --log-lines)
            LOG_LINES="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
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
        --sensitive)
            INCLUDE_SENSITIVE=true
            shift
            ;;
        collect|system|service|network|performance|logs|package)
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

collect_system_info() {
    log_debug "Collecting system information..."
    
    local system_info
    system_info=$(cat << EOF
{
    "hostname": "$(hostname)",
    "timestamp": "$(date -Iseconds)",
    "os": {
        "distribution": "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "uptime": "$(uptime -p 2>/dev/null || echo 'Unknown')"
    },
    "hardware": {
        "cpu_info": "$(lscpu | grep 'Model name' | cut -d':' -f2 | sed 's/^ *//' || echo 'Unknown')",
        "cpu_cores": $(nproc),
        "memory_total_gb": $(free -g | awk 'NR==2{print $2}'),
        "disk_total_gb": $(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//'),
        "load_average": "$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//' || echo 'Unknown')"
    },
    "environment": {
        "user": "$(whoami)",
        "home": "$HOME",
        "path": "$PATH",
        "shell": "$SHELL",
        "term": "${TERM:-unknown}"
    }
}
EOF
)
    
    if [[ "$INCLUDE_SENSITIVE" == true ]]; then
        # Add environment variables (filtered)
        local env_vars
        env_vars=$(env | grep -E '^(GITHUB_|RUNNER_|ACTIONS_)' | while IFS='=' read -r key value; do
            # Mask sensitive values
            if [[ "$key" =~ (TOKEN|SECRET|KEY|PASSWORD) ]]; then
                value="***REDACTED***"
            fi
            printf '"%s": "%s",' "$key" "$value"
        done | sed 's/,$//')
        
        if [[ -n "$env_vars" ]]; then
            system_info=$(echo "$system_info" | jq --argjson env "{$env_vars}" '. + {"environment_vars": $env}')
        fi
    fi
    
    echo "$system_info"
}

collect_service_status() {
    log_debug "Collecting service status..."
    
    local systemd_info="{}"
    
    if command -v systemctl >/dev/null 2>&1; then
        local active_state
        active_state=$(systemctl is-active github-runner.service 2>/dev/null || echo "unknown")
        
        local enabled_state
        enabled_state=$(systemctl is-enabled github-runner.service 2>/dev/null || echo "unknown")
        
        local service_status
        service_status=$(systemctl status github-runner.service --no-pager 2>/dev/null || echo "Service not found")
        
        local service_properties=""
        if systemctl show github-runner.service >/dev/null 2>&1; then
            local main_pid
            main_pid=$(systemctl show github-runner.service --property=MainPID --value 2>/dev/null || echo "0")
            
            local memory_usage
            memory_usage=$(systemctl show github-runner.service --property=MemoryCurrent --value 2>/dev/null || echo "0")
            
            local restart_count
            restart_count=$(systemctl show github-runner.service --property=NRestarts --value 2>/dev/null || echo "0")
            
            local start_time
            start_time=$(systemctl show github-runner.service --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
            
            service_properties=$(cat << EOF
{
    "main_pid": $main_pid,
    "memory_current": $memory_usage,
    "restart_count": $restart_count,
    "start_time": "${start_time:-null}"
}
EOF
)
        fi
        
        systemd_info=$(cat << EOF
{
    "active_state": "$active_state",
    "enabled_state": "$enabled_state",
    "status_output": $(echo "$service_status" | jq -Rs .),
    "properties": $service_properties
}
EOF
)
    fi
    
    # Docker container status
    local docker_info="[]"
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]] && command -v docker-compose >/dev/null 2>&1; then
        cd "$PROJECT_ROOT"
        
        local container_data=""
        while IFS= read -r service; do
            local container_id
            container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
            
            local container_status="not-found"
            local container_details="{}"
            
            if [[ -n "$container_id" ]]; then
                container_status=$(docker inspect "$container_id" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
                
                local container_info
                container_info=$(docker inspect "$container_id" 2>/dev/null || echo "{}")
                
                if [[ "$container_info" != "{}" ]]; then
                    container_details=$(echo "$container_info" | jq '.[0] | {
                        "id": .Id[0:12],
                        "name": .Name,
                        "status": .State.Status,
                        "health": .State.Health.Status // "no-health-check",
                        "started_at": .State.StartedAt,
                        "restart_count": .RestartCount,
                        "exit_code": .State.ExitCode,
                        "error": .State.Error
                    }')
                fi
            fi
            
            local service_json
            service_json=$(cat << EOF
{
    "service_name": "$service",
    "container_id": "${container_id:-null}",
    "status": "$container_status",
    "details": $container_details
}
EOF
)
            
            if [[ -z "$container_data" ]]; then
                container_data="$service_json"
            else
                container_data="$container_data,$service_json"
            fi
            
        done < <(docker-compose config --services 2>/dev/null)
        
        if [[ -n "$container_data" ]]; then
            docker_info="[$container_data]"
        fi
    fi
    
    cat << EOF
{
    "systemd": $systemd_info,
    "docker": $docker_info
}
EOF
}

collect_network_info() {
    log_debug "Collecting network information..."
    
    # GitHub API connectivity
    local github_test="{}"
    local start_time=$(date +%s%3N)
    if curl -s --connect-timeout 10 -w "%{http_code},%{time_total}" https://api.github.com/rate_limit > /tmp/github_test.out 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        local curl_output=$(cat /tmp/github_test.out)
        local http_code=$(echo "$curl_output" | tail -1 | cut -d',' -f1)
        local time_total=$(echo "$curl_output" | tail -1 | cut -d',' -f2)
        
        github_test=$(cat << EOF
{
    "status": "success",
    "http_code": "$http_code",
    "response_time_ms": $response_time,
    "curl_time_total": "$time_total"
}
EOF
)
    else
        github_test=$(cat << EOF
{
    "status": "failed",
    "error": "$(cat /tmp/github_test.out 2>/dev/null || echo 'Connection failed')"
}
EOF
)
    fi
    rm -f /tmp/github_test.out
    
    # DNS resolution
    local dns_test="{}"
    if nslookup github.com > /tmp/dns_test.out 2>&1; then
        local dns_servers
        dns_servers=$(grep 'Server:' /tmp/dns_test.out | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
        
        dns_test=$(cat << EOF
{
    "status": "success",
    "servers": "$dns_servers"
}
EOF
)
    else
        dns_test=$(cat << EOF
{
    "status": "failed",
    "error": "$(cat /tmp/dns_test.out 2>/dev/null || echo 'DNS resolution failed')"
}
EOF
)
    fi
    rm -f /tmp/dns_test.out
    
    # Network interfaces
    local interfaces_info="[]"
    if command -v ip >/dev/null 2>&1; then
        interfaces_info=$(ip -j addr show 2>/dev/null || echo "[]")
    fi
    
    # Network routes
    local routes_info="[]"
    if command -v ip >/dev/null 2>&1; then
        local routes_text
        routes_text=$(ip route show 2>/dev/null || echo "")
        if [[ -n "$routes_text" ]]; then
            routes_info=$(echo "$routes_text" | jq -R . | jq -s .)
        fi
    fi
    
    cat << EOF
{
    "github_api": $github_test,
    "dns": $dns_test,
    "interfaces": $interfaces_info,
    "routes": $routes_info
}
EOF
}

collect_performance_metrics() {
    log_debug "Collecting performance metrics..."
    
    # CPU usage (sample over 3 seconds)
    local cpu_usage
    cpu_usage=$(top -bn2 -d1 | grep "Cpu(s)" | tail -1 | awk '{print $2}' | sed 's/%us,//' || echo "0")
    
    # Memory information
    local memory_info
    memory_info=$(free -j 2>/dev/null || free | awk 'NR==2{printf "{\"total\":%d,\"used\":%d,\"free\":%d,\"available\":%d}", $2, $3, $4, $7}')
    
    # Disk I/O statistics
    local disk_io="{}"
    if command -v iostat >/dev/null 2>&1; then
        local iostat_output
        iostat_output=$(iostat -d 1 2 | tail -n +4 | awk 'NF>0' | tail -1)
        if [[ -n "$iostat_output" ]]; then
            disk_io=$(echo "$iostat_output" | awk '{printf "{\"device\":\"%s\",\"reads_per_sec\":%.2f,\"writes_per_sec\":%.2f}", $1, $4, $5}')
        fi
    fi
    
    # Load average breakdown
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//' | tr ',' ' ')
    local load_1min load_5min load_15min
    read -r load_1min load_5min load_15min <<< "$load_avg"
    
    # Process information for runner processes
    local runner_processes="[]"
    local install_path="${INSTALL_PATH:-/opt/github-runner}"
    if pgrep -f "$install_path" >/dev/null 2>&1; then
        local proc_data=""
        while IFS= read -r pid; do
            local proc_info
            proc_info=$(ps -p "$pid" -o pid,ppid,pcpu,pmem,etime,cmd --no-headers 2>/dev/null || echo "")
            if [[ -n "$proc_info" ]]; then
                local proc_json
                proc_json=$(echo "$proc_info" | awk '{printf "{\"pid\":%d,\"ppid\":%d,\"cpu\":%.1f,\"memory\":%.1f,\"etime\":\"%s\",\"command\":\"%s\"}", $1, $2, $3, $4, $5, $6}')
                
                if [[ -z "$proc_data" ]]; then
                    proc_data="$proc_json"
                else
                    proc_data="$proc_data,$proc_json"
                fi
            fi
        done < <(pgrep -f "$install_path")
        
        if [[ -n "$proc_data" ]]; then
            runner_processes="[$proc_data]"
        fi
    fi
    
    cat << EOF
{
    "cpu_usage_percent": $cpu_usage,
    "memory": $memory_info,
    "disk_io": $disk_io,
    "load_average": {
        "1min": ${load_1min:-0},
        "5min": ${load_5min:-0},
        "15min": ${load_15min:-0}
    },
    "runner_processes": $runner_processes
}
EOF
}

collect_log_info() {
    log_debug "Collecting log information..."
    
    # Calculate since timestamp
    local since_timestamp
    case "$SINCE" in
        *h) since_timestamp=$(date -d "-${SINCE%h} hours" '+%Y-%m-%d %H:%M:%S') ;;
        *d) since_timestamp=$(date -d "-${SINCE%d} days" '+%Y-%m-%d %H:%M:%S') ;;
        *w) since_timestamp=$(date -d "-${SINCE%w} weeks" '+%Y-%m-%d %H:%M:%S') ;;
        *) since_timestamp=$(date -d "-$SINCE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "-1 day" '+%Y-%m-%d %H:%M:%S') ;;
    esac
    
    # Systemd service logs
    local systemd_logs=""
    if command -v journalctl >/dev/null 2>&1; then
        systemd_logs=$(journalctl -u github-runner.service --since "$since_timestamp" --lines "$LOG_LINES" --no-pager 2>/dev/null || echo "No systemd logs available")
    fi
    
    # Application logs
    local app_logs=""
    local log_files=(
        "/var/log/github-runner/runner.log"
        "/var/log/github-runner/health.log"
        "/var/log/github-runner/monitor.log"
        "$PROJECT_ROOT/logs/runner.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local file_logs
            file_logs=$(find "$log_file" -newermt "$since_timestamp" -exec tail -n "$LOG_LINES" {} \; 2>/dev/null || echo "")
            if [[ -n "$file_logs" ]]; then
                app_logs="$app_logs\n\n=== $log_file ===\n$file_logs"
            fi
        fi
    done
    
    # Docker logs
    local docker_logs=""
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]] && command -v docker-compose >/dev/null 2>&1; then
        cd "$PROJECT_ROOT"
        docker_logs=$(docker-compose logs --tail="$LOG_LINES" --since "${SINCE%h}h" 2>/dev/null || echo "No docker logs available")
    fi
    
    # Log file sizes and locations
    local log_files_info="[]"
    local log_data=""
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local size
            size=$(du -h "$log_file" | cut -f1)
            local modified
            modified=$(stat -c %Y "$log_file" 2>/dev/null || echo "0")
            
            local file_json
            file_json=$(cat << EOF
{
    "path": "$log_file",
    "size": "$size",
    "last_modified": $modified,
    "exists": true
}
EOF
)
            
            if [[ -z "$log_data" ]]; then
                log_data="$file_json"
            else
                log_data="$log_data,$file_json"
            fi
        fi
    done
    
    if [[ -n "$log_data" ]]; then
        log_files_info="[$log_data]"
    fi
    
    cat << EOF
{
    "collection_period": "$SINCE",
    "since_timestamp": "$since_timestamp",
    "log_files": $log_files_info,
    "systemd_logs": $(echo "$systemd_logs" | jq -Rs .),
    "application_logs": $(echo -e "$app_logs" | jq -Rs .),
    "docker_logs": $(echo "$docker_logs" | jq -Rs .)
}
EOF
}

create_diagnostic_package() {
    log_section "Creating Diagnostic Package"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local package_dir="$OUTPUT_DIR/github-runner-diagnostics-$timestamp"
    
    mkdir -p "$package_dir"
    
    log_info "Collecting diagnostics to: $package_dir"
    
    # Collect all diagnostic information
    log_info "Collecting system information..."
    collect_system_info > "$package_dir/system.json"
    
    log_info "Collecting service status..."
    collect_service_status > "$package_dir/service.json"
    
    log_info "Collecting network information..."
    collect_network_info > "$package_dir/network.json"
    
    log_info "Collecting performance metrics..."
    collect_performance_metrics > "$package_dir/performance.json"
    
    log_info "Collecting log information..."
    collect_log_info > "$package_dir/logs.json"
    
    # Copy configuration files (redacted)
    if [[ -d "/etc/github-runner" ]]; then
        log_info "Copying configuration files..."
        mkdir -p "$package_dir/config"
        
        for config_file in /etc/github-runner/*; do
            if [[ -f "$config_file" ]]; then
                local basename_file
                basename_file=$(basename "$config_file")
                
                if [[ "$INCLUDE_SENSITIVE" == true ]]; then
                    cp "$config_file" "$package_dir/config/$basename_file"
                else
                    # Redact sensitive information
                    sed -E 's/(TOKEN|SECRET|KEY|PASSWORD)=.*/\1=***REDACTED***/' "$config_file" > "$package_dir/config/$basename_file"
                fi
            fi
        done
    fi
    
    # Copy log files if requested
    if [[ "$INCLUDE_LOGS" == true ]]; then
        log_info "Copying log files..."
        mkdir -p "$package_dir/logs"
        
        local log_files=(
            "/var/log/github-runner"
            "$PROJECT_ROOT/logs"
        )
        
        for log_dir in "${log_files[@]}"; do
            if [[ -d "$log_dir" ]]; then
                local target_dir="$package_dir/logs/$(basename "$log_dir")"
                mkdir -p "$target_dir"
                
                find "$log_dir" -name "*.log" -type f -exec cp {} "$target_dir/" \; 2>/dev/null || true
            fi
        done
        
        # Copy recent systemd logs
        if command -v journalctl >/dev/null 2>&1; then
            journalctl -u github-runner.service --since "$SINCE" --no-pager > "$package_dir/logs/systemd.log" 2>/dev/null || true
        fi
    fi
    
    # Create summary report
    log_info "Creating summary report..."
    cat > "$package_dir/README.md" << EOF
# GitHub Actions Runner Diagnostics

Generated: $(date)
Hostname: $(hostname)
Collection Period: $SINCE

## Contents

- \`system.json\` - System information and environment
- \`service.json\` - Service status and container information
- \`network.json\` - Network connectivity tests
- \`performance.json\` - Performance metrics and resource usage
- \`logs.json\` - Log analysis and recent entries
- \`config/\` - Configuration files (sensitive data redacted)
$(if [[ "$INCLUDE_LOGS" == true ]]; then echo "- \`logs/\` - Complete log files"; fi)

## Usage

Review the JSON files for detailed diagnostic information. The logs.json file contains recent log entries, while the logs/ directory (if present) contains complete log files.

## Security Note

$(if [[ "$INCLUDE_SENSITIVE" == true ]]; then
    echo "⚠️ **WARNING**: This package may contain sensitive information including tokens and secrets."
else
    echo "🔒 Sensitive information has been redacted from configuration files."
fi)
EOF
    
    # Create archive
    local archive_name="github-runner-diagnostics-$timestamp.tar.gz"
    local archive_path="$OUTPUT_DIR/$archive_name"
    
    log_info "Creating archive: $archive_path"
    tar -czf "$archive_path" -C "$OUTPUT_DIR" "$(basename "$package_dir")"
    
    # Cleanup temporary directory
    rm -rf "$package_dir"
    
    log_success "Diagnostic package created: $archive_path"
    
    # Show package contents
    log_info "Package contents:"
    tar -tzf "$archive_path" | head -20
    
    local file_size
    file_size=$(du -h "$archive_path" | cut -f1)
    log_info "Package size: $file_size"
    
    echo "$archive_path"
}

output_result() {
    local data="$1"
    local title="$2"
    
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "$data" | jq .
    else
        echo "$title"
        echo "$(printf '=%.0s' $(seq 1 ${#title}))"
        echo
        
        # Pretty print based on command
        case "$COMMAND" in
            system)
                echo "$data" | jq -r '
                    "Hostname: " + .hostname,
                    "OS: " + .os.distribution,
                    "Kernel: " + .os.kernel,
                    "Architecture: " + .os.architecture,
                    "Uptime: " + .os.uptime,
                    "CPU: " + .hardware.cpu_info,
                    "CPU Cores: " + (.hardware.cpu_cores | tostring),
                    "Memory: " + (.hardware.memory_total_gb | tostring) + " GB",
                    "Disk: " + (.hardware.disk_total_gb | tostring) + " GB",
                    "Load Average: " + .hardware.load_average
                '
                ;;
            service)
                echo "$data" | jq -r '
                    "Systemd Service: " + .systemd.active_state + " (" + .systemd.enabled_state + ")",
                    "Docker Containers: " + (.docker | length | tostring) + " configured"
                '
                if [[ "$VERBOSE" == true ]]; then
                    echo
                    echo "Container Details:"
                    echo "$data" | jq -r '.docker[] | "  " + .service_name + ": " + .status'
                fi
                ;;
            network)
                echo "$data" | jq -r '
                    "GitHub API: " + .github_api.status,
                    "DNS Resolution: " + .dns.status,
                    "Interfaces: " + (.interfaces | length | tostring) + " configured"
                '
                ;;
            performance)
                echo "$data" | jq -r '
                    "CPU Usage: " + (.cpu_usage_percent | tostring) + "%",
                    "Memory Usage: " + ((.memory.used / .memory.total * 100) | floor | tostring) + "%",
                    "Load Average: " + (.load_average."1min" | tostring) + " (1m)",
                    "Runner Processes: " + (.runner_processes | length | tostring)
                '
                ;;
            logs)
                local log_count
                log_count=$(echo "$data" | jq '.log_files | length')
                echo "Log Files Found: $log_count"
                echo "Collection Period: $(echo "$data" | jq -r '.collection_period')"
                
                if [[ "$VERBOSE" == true ]]; then
                    echo
                    echo "Log Files:"
                    echo "$data" | jq -r '.log_files[] | "  " + .path + " (" + .size + ")"'
                fi
                ;;
        esac
        echo
    fi
}

main() {
    load_configuration
    mkdir -p "$OUTPUT_DIR"
    
    case "$COMMAND" in
        collect)
            log_section "Full Diagnostic Collection"
            
            local all_diagnostics
            all_diagnostics=$(cat << EOF
{
    "timestamp": "$(date -Iseconds)",
    "system": $(collect_system_info),
    "service": $(collect_service_status),
    "network": $(collect_network_info),
    "performance": $(collect_performance_metrics),
    "logs": $(collect_log_info)
}
EOF
)
            
            output_result "$all_diagnostics" "GitHub Actions Runner Diagnostics"
            ;;
        system)
            output_result "$(collect_system_info)" "System Information"
            ;;
        service)
            output_result "$(collect_service_status)" "Service Status"
            ;;
        network)
            output_result "$(collect_network_info)" "Network Information"
            ;;
        performance)
            output_result "$(collect_performance_metrics)" "Performance Metrics"
            ;;
        logs)
            output_result "$(collect_log_info)" "Log Information"
            ;;
        package)
            create_diagnostic_package
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