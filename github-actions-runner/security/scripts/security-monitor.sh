#!/bin/bash
# Security Monitoring Script for GitHub Actions Runner
# Provides real-time security monitoring, compliance checking, and incident response

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${SECURITY_DIR}/config/monitoring-compliance.yml"
LOG_FILE="/var/log/security-monitor.log"
ALERT_LOG="/var/log/security-alerts.log"
COMPLIANCE_LOG="/var/log/compliance-check.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
MONITORING_PID=""
WEBHOOK_URL="${SECURITY_WEBHOOK_URL:-}"

# Logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Alert logging function
log_alert() {
    local severity="$1"
    local event="$2"
    local details="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local alert_entry=$(jq -n \
        --arg timestamp "${timestamp}" \
        --arg severity "${severity}" \
        --arg event "${event}" \
        --arg details "${details}" \
        '{
            timestamp: $timestamp,
            severity: $severity,
            event: $event,
            details: $details,
            source: "security-monitor"
        }')
    
    echo "${alert_entry}" >> "${ALERT_LOG}"
    
    # Send webhook notification if configured
    if [[ -n "${WEBHOOK_URL}" ]]; then
        send_webhook_alert "${severity}" "${event}" "${details}"
    fi
}

# Send webhook alert
send_webhook_alert() {
    local severity="$1"
    local event="$2"
    local details="$3"
    
    local payload=$(jq -n \
        --arg severity "${severity}" \
        --arg event "${event}" \
        --arg details "${details}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            text: "Security Alert [\($severity)]: \($event)",
            attachments: [{
                color: (if $severity == "critical" then "danger" elif $severity == "high" then "warning" else "good" end),
                fields: [
                    {title: "Event", value: $event, short: true},
                    {title: "Severity", value: $severity, short: true},
                    {title: "Details", value: $details, short: false},
                    {title: "Timestamp", value: $timestamp, short: true}
                ]
            }]
        }')
    
    curl -s -X POST "${WEBHOOK_URL}" \
         -H "Content-Type: application/json" \
         -d "${payload}" >/dev/null 2>&1 || true
}

# Check authentication security
check_authentication_security() {
    local auth_log="/var/log/auth.log"
    local failed_logins
    local sudo_usage
    
    # Check for failed login attempts
    if [[ -f "${auth_log}" ]]; then
        failed_logins=$(grep "authentication failure\|failed password\|invalid user" "${auth_log}" | tail -50 | wc -l)
        if [[ ${failed_logins} -gt 5 ]]; then
            log_alert "medium" "Multiple failed login attempts" "${failed_logins} failed login attempts detected"
        fi
        
        # Check for sudo usage by runner user
        sudo_usage=$(grep "sudo.*runner" "${auth_log}" | tail -10 | wc -l)
        if [[ ${sudo_usage} -gt 0 ]]; then
            log_alert "high" "Sudo usage by runner" "Runner user executed sudo commands"
        fi
    fi
}

# Check network security
check_network_security() {
    # Check for suspicious network connections
    local established_connections=$(netstat -tn 2>/dev/null | grep ESTABLISHED | wc -l)
    if [[ ${established_connections} -gt 20 ]]; then
        log_alert "medium" "High number of network connections" "${established_connections} established connections"
    fi
    
    # Check for listening services
    local listening_services=$(netstat -ln 2>/dev/null | grep LISTEN | grep -v "127.0.0.1\|::1" | wc -l)
    if [[ ${listening_services} -gt 0 ]]; then
        log_alert "high" "Unexpected listening services" "${listening_services} services listening on external interfaces"
    fi
    
    # Check iptables rules
    if ! iptables -L -n | grep -q "DROP"; then
        log_alert "critical" "Firewall rules missing" "iptables DROP rules not found"
    fi
}

# Check filesystem security
check_filesystem_security() {
    local runner_home="/home/runner"
    
    # Check home directory permissions
    if [[ -d "${runner_home}" ]]; then
        local home_perms=$(stat -c "%a" "${runner_home}")
        if [[ "${home_perms}" != "750" ]] && [[ "${home_perms}" != "700" ]]; then
            log_alert "medium" "Insecure home directory permissions" "Home directory permissions: ${home_perms}"
        fi
    fi
    
    # Check for world-writable files
    local world_writable=$(find "${runner_home}" -type f -perm -002 2>/dev/null | wc -l)
    if [[ ${world_writable} -gt 0 ]]; then
        log_alert "high" "World-writable files detected" "${world_writable} world-writable files found"
    fi
    
    # Check for setuid/setgid files
    local setuid_files=$(find "${runner_home}" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
    if [[ ${setuid_files} -gt 0 ]]; then
        log_alert "critical" "Setuid/setgid files detected" "${setuid_files} setuid/setgid files found in runner home"
    fi
}

# Check process security
check_process_security() {
    # Check for suspicious processes
    local suspicious_processes=("nc" "netcat" "telnet" "ncat" "socat")
    for proc in "${suspicious_processes[@]}"; do
        if pgrep -f "${proc}" >/dev/null 2>&1; then
            log_alert "critical" "Suspicious process detected" "Process: ${proc}"
        fi
    done
    
    # Check process count for runner user
    local runner_processes=$(ps -u runner --no-headers 2>/dev/null | wc -l)
    if [[ ${runner_processes} -gt 50 ]]; then
        log_alert "medium" "High process count for runner" "${runner_processes} processes running as runner user"
    fi
    
    # Check for processes running as root
    local root_processes=$(ps -u root --no-headers | grep -v "\[.*\]" | wc -l)
    if [[ ${root_processes} -gt 30 ]]; then
        log_alert "medium" "High root process count" "${root_processes} processes running as root"
    fi
}

# Check container security
check_container_security() {
    # Check if containers are running as root
    if command -v docker >/dev/null 2>&1; then
        local containers_as_root=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -c "github-runner" || echo "0")
        
        # Check container resource usage
        if docker stats --no-stream github-runner >/dev/null 2>&1; then
            local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" github-runner | sed 's/%//')
            local mem_usage=$(docker stats --no-stream --format "{{.MemPerc}}" github-runner | sed 's/%//')
            
            if (( $(echo "${cpu_usage} > 80" | bc -l 2>/dev/null || echo "0") )); then
                log_alert "medium" "High container CPU usage" "CPU usage: ${cpu_usage}%"
            fi
            
            if (( $(echo "${mem_usage} > 90" | bc -l 2>/dev/null || echo "0") )); then
                log_alert "high" "High container memory usage" "Memory usage: ${mem_usage}%"
            fi
        fi
    fi
}

# Run vulnerability scan
run_vulnerability_scan() {
    log "${YELLOW}Running vulnerability scan...${NC}"
    
    # Container vulnerability scan using trivy (if available)
    if command -v trivy >/dev/null 2>&1; then
        local scan_result=$(trivy image --severity HIGH,CRITICAL --quiet github-runner:latest 2>/dev/null | wc -l)
        if [[ ${scan_result} -gt 0 ]]; then
            log_alert "high" "Container vulnerabilities detected" "${scan_result} high/critical vulnerabilities found"
        fi
    fi
    
    # System package vulnerability check
    if command -v apt >/dev/null 2>&1; then
        local upgradable=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
        if [[ ${upgradable} -gt 10 ]]; then
            log_alert "medium" "Multiple package updates available" "${upgradable} packages can be upgraded"
        fi
    fi
}

# Check CIS Docker Benchmark compliance
check_cis_docker_compliance() {
    log "${YELLOW}Checking CIS Docker Benchmark compliance...${NC}"
    
    local compliance_issues=0
    
    # CIS 2.1 - Ensure network traffic is restricted between containers on the default bridge
    if docker network ls | grep -q "bridge.*bridge"; then
        if ! docker network inspect bridge | grep -q '"EnableICC": false'; then
            log_alert "medium" "CIS 2.1: Inter-container communication not disabled" "Default bridge allows ICC"
            ((compliance_issues++))
        fi
    fi
    
    # CIS 2.5 - Ensure aufs storage driver is not used
    if docker info 2>/dev/null | grep -q "Storage Driver: aufs"; then
        log_alert "high" "CIS 2.5: AUFS storage driver in use" "AUFS storage driver is deprecated"
        ((compliance_issues++))
    fi
    
    # CIS 4.1 - Ensure that a user for the container has been created
    if docker ps --format "{{.Names}}" | grep -q "github-runner"; then
        local user_check=$(docker exec github-runner id -u 2>/dev/null || echo "0")
        if [[ "${user_check}" == "0" ]]; then
            log_alert "critical" "CIS 4.1: Container running as root" "GitHub runner container running as root user"
            ((compliance_issues++))
        fi
    fi
    
    # CIS 5.3 - Ensure that Linux kernel capabilities are restricted within containers
    if docker inspect github-runner 2>/dev/null | grep -q '"CapAdd": \[\]'; then
        log_alert "medium" "CIS 5.3: Additional capabilities granted" "Container has additional Linux capabilities"
        ((compliance_issues++))
    fi
    
    echo "${compliance_issues}" > "/tmp/cis_compliance_issues"
    
    if [[ ${compliance_issues} -eq 0 ]]; then
        log "${GREEN}CIS Docker Benchmark compliance check passed${NC}"
    else
        log "${YELLOW}CIS Docker Benchmark compliance check found ${compliance_issues} issues${NC}"
    fi
}

# Generate compliance report
generate_compliance_report() {
    local report_file="/var/log/compliance-report-$(date +%Y%m%d_%H%M%S).json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log "${YELLOW}Generating compliance report...${NC}"
    
    # Get CIS compliance issues
    local cis_issues=$(cat "/tmp/cis_compliance_issues" 2>/dev/null || echo "0")
    
    # Count recent security alerts
    local security_alerts=$(grep "$(date +%Y-%m-%d)" "${ALERT_LOG}" 2>/dev/null | wc -l)
    
    # Check audit log status
    local audit_status="enabled"
    if ! systemctl is-active --quiet auditd; then
        audit_status="disabled"
    fi
    
    # Generate report
    local report=$(jq -n \
        --arg timestamp "${timestamp}" \
        --arg cis_issues "${cis_issues}" \
        --arg security_alerts "${security_alerts}" \
        --arg audit_status "${audit_status}" \
        '{
            report_timestamp: $timestamp,
            compliance_status: {
                cis_docker_benchmark: {
                    issues_found: ($cis_issues | tonumber),
                    compliance_score: (100 - (($cis_issues | tonumber) * 10)),
                    status: (if ($cis_issues | tonumber) == 0 then "compliant" else "non-compliant" end)
                },
                audit_logging: {
                    status: $audit_status,
                    compliant: ($audit_status == "enabled")
                }
            },
            security_metrics: {
                alerts_last_24h: ($security_alerts | tonumber),
                system_status: "operational"
            },
            recommendations: [
                (if ($cis_issues | tonumber) > 0 then "Address CIS Docker Benchmark violations" else empty end),
                (if $audit_status != "enabled" then "Enable audit logging" else empty end),
                (if ($security_alerts | tonumber) > 10 then "Investigate high alert volume" else empty end)
            ]
        }')
    
    echo "${report}" > "${report_file}"
    chmod 600 "${report_file}"
    
    log "${GREEN}Compliance report generated: ${report_file}${NC}"
}

# Main monitoring loop
monitoring_loop() {
    log "${GREEN}Starting security monitoring loop${NC}"
    
    while true; do
        log "${BLUE}Running security checks...${NC}"
        
        # Run security checks
        check_authentication_security
        check_network_security
        check_filesystem_security
        check_process_security
        check_container_security
        
        # Run periodic checks
        local hour=$(date +%H)
        local minute=$(date +%M)
        
        # Run vulnerability scan every 6 hours
        if [[ $((hour % 6)) -eq 0 ]] && [[ ${minute} -eq 0 ]]; then
            run_vulnerability_scan
        fi
        
        # Run compliance check daily at 2 AM
        if [[ ${hour} -eq 2 ]] && [[ ${minute} -eq 0 ]]; then
            check_cis_docker_compliance
            generate_compliance_report
        fi
        
        log "${BLUE}Security check cycle completed${NC}"
        sleep 60  # Check every minute
    done
}

# Start monitoring daemon
start_monitoring() {
    log "${YELLOW}Starting security monitoring daemon...${NC}"
    
    # Check if already running
    if [[ -f "/var/run/security-monitor.pid" ]]; then
        local existing_pid=$(cat "/var/run/security-monitor.pid")
        if kill -0 "${existing_pid}" 2>/dev/null; then
            log "${YELLOW}Security monitor already running (PID: ${existing_pid})${NC}"
            return 0
        fi
    fi
    
    # Start monitoring in background
    monitoring_loop &
    MONITORING_PID=$!
    echo "${MONITORING_PID}" > "/var/run/security-monitor.pid"
    
    log "${GREEN}Security monitoring started (PID: ${MONITORING_PID})${NC}"
}

# Stop monitoring daemon
stop_monitoring() {
    log "${YELLOW}Stopping security monitoring daemon...${NC}"
    
    if [[ -f "/var/run/security-monitor.pid" ]]; then
        local pid=$(cat "/var/run/security-monitor.pid")
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}"
            rm -f "/var/run/security-monitor.pid"
            log "${GREEN}Security monitoring stopped${NC}"
        else
            log "${YELLOW}Security monitor not running${NC}"
            rm -f "/var/run/security-monitor.pid"
        fi
    else
        log "${YELLOW}Security monitor PID file not found${NC}"
    fi
}

# Check monitoring status
check_status() {
    if [[ -f "/var/run/security-monitor.pid" ]]; then
        local pid=$(cat "/var/run/security-monitor.pid")
        if kill -0 "${pid}" 2>/dev/null; then
            log "${GREEN}Security monitoring is running (PID: ${pid})${NC}"
            return 0
        else
            log "${RED}Security monitor PID file exists but process is not running${NC}"
            rm -f "/var/run/security-monitor.pid"
            return 1
        fi
    else
        log "${YELLOW}Security monitoring is not running${NC}"
        return 1
    fi
}

# Run immediate security check
immediate_check() {
    log "${YELLOW}Running immediate security check...${NC}"
    
    check_authentication_security
    check_network_security
    check_filesystem_security
    check_process_security
    check_container_security
    run_vulnerability_scan
    check_cis_docker_compliance
    
    log "${GREEN}Immediate security check completed${NC}"
}

# Show help
show_help() {
    cat << EOF
GitHub Actions Runner Security Monitor

Usage: $0 [COMMAND]

Commands:
    start           Start security monitoring daemon
    stop            Stop security monitoring daemon
    restart         Restart security monitoring daemon
    status          Check monitoring daemon status
    check           Run immediate security check
    compliance      Run compliance check and generate report
    logs            Show recent security alerts
    help            Show this help message

Environment Variables:
    SECURITY_WEBHOOK_URL    Webhook URL for security alerts

Examples:
    $0 start                # Start monitoring daemon
    $0 check                # Run immediate security check
    $0 compliance           # Generate compliance report
    $0 logs                 # Show recent alerts

Security Checks:
    - Authentication security (failed logins, sudo usage)
    - Network security (connections, firewall rules)
    - Filesystem security (permissions, world-writable files)
    - Process security (suspicious processes, resource usage)
    - Container security (root execution, resource limits)
    - Vulnerability scanning (container and system packages)
    - CIS Docker Benchmark compliance

EOF
}

# Main function
main() {
    local command="${1:-help}"
    
    case "${command}" in
        "start")
            start_monitoring
            ;;
        "stop")
            stop_monitoring
            ;;
        "restart")
            stop_monitoring
            sleep 2
            start_monitoring
            ;;
        "status")
            check_status
            ;;
        "check")
            immediate_check
            ;;
        "compliance")
            check_cis_docker_compliance
            generate_compliance_report
            ;;
        "logs")
            if [[ -f "${ALERT_LOG}" ]]; then
                tail -20 "${ALERT_LOG}" | jq -r '[.timestamp, .severity, .event, .details] | @tsv'
            else
                log "${YELLOW}No security alerts found${NC}"
            fi
            ;;
        "help"|"--help")
            show_help
            ;;
        *)
            log "${RED}Unknown command: ${command}${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Trap signals for graceful shutdown
trap 'stop_monitoring; exit 0' SIGTERM SIGINT

# Execute main function
main "$@"