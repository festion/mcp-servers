#!/bin/bash
# Container Security Health Check Script
# Performs runtime security validations

set -euo pipefail

# Configuration
LOG_FILE="/var/log/security-check.log"
SECURITY_CHECKS=(
    "check_user_privileges"
    "check_file_permissions"
    "check_network_config"
    "check_running_processes"
    "check_mounted_filesystems"
)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as non-root user
check_user_privileges() {
    local current_user=$(id -u)
    local current_group=$(id -g)
    
    if [[ "${current_user}" -eq 0 ]]; then
        log "SECURITY VIOLATION: Container is running as root user"
        return 1
    fi
    
    if [[ "${current_user}" -ne 1001 ]]; then
        log "WARNING: Container is not running as expected user ID (1001)"
        return 1
    fi
    
    log "PASS: Container running as non-root user (UID: ${current_user}, GID: ${current_group})"
    return 0
}

# Check critical file permissions
check_file_permissions() {
    local critical_files=(
        "/home/runner/.ssh"
        "/home/runner/actions-runner"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -e "${file}" ]]; then
            local perms=$(stat -c "%a" "${file}" 2>/dev/null || echo "000")
            local owner=$(stat -c "%U" "${file}" 2>/dev/null || echo "unknown")
            
            if [[ "${owner}" != "runner" ]]; then
                log "SECURITY VIOLATION: ${file} not owned by runner user"
                return 1
            fi
            
            # Check if file is world-readable or world-writable
            if [[ "${perms}" =~ [0-9][0-9][1-9] ]]; then
                log "SECURITY VIOLATION: ${file} has world permissions (${perms})"
                return 1
            fi
        fi
    done
    
    log "PASS: File permissions are secure"
    return 0
}

# Check network configuration
check_network_config() {
    # Check if unnecessary network services are running
    local suspicious_ports=(21 23 25 53 80 135 139 445 993 995)
    
    for port in "${suspicious_ports[@]}"; do
        if netstat -ln 2>/dev/null | grep -q ":${port} "; then
            log "WARNING: Suspicious service listening on port ${port}"
        fi
    done
    
    # Check for outbound connections to suspicious destinations
    local connections=$(netstat -tn 2>/dev/null | grep ESTABLISHED | wc -l)
    if [[ "${connections}" -gt 10 ]]; then
        log "WARNING: High number of established connections (${connections})"
    fi
    
    log "PASS: Network configuration check completed"
    return 0
}

# Check running processes
check_running_processes() {
    local process_count=$(ps aux --no-headers | wc -l)
    local suspicious_processes=("nc" "netcat" "telnet" "rsh" "rlogin")
    
    # Check process count
    if [[ "${process_count}" -gt 20 ]]; then
        log "WARNING: High number of running processes (${process_count})"
    fi
    
    # Check for suspicious processes
    for proc in "${suspicious_processes[@]}"; do
        if pgrep -f "${proc}" >/dev/null 2>&1; then
            log "SECURITY VIOLATION: Suspicious process detected: ${proc}"
            return 1
        fi
    done
    
    log "PASS: Process security check completed"
    return 0
}

# Check mounted filesystems
check_mounted_filesystems() {
    # Check for writable mounted filesystems that should be read-only
    local writable_mounts=$(mount | grep -v "type tmpfs" | grep -v "ro," | grep -c "rw," || echo "0")
    
    # Check for suspicious mount points
    if mount | grep -q "/proc/sys.*rw"; then
        log "SECURITY VIOLATION: /proc/sys mounted as writable"
        return 1
    fi
    
    # Check for nosuid and noexec on temp directories
    if ! mount | grep "/tmp.*nosuid" >/dev/null 2>&1; then
        log "WARNING: /tmp not mounted with nosuid option"
    fi
    
    if ! mount | grep "/tmp.*noexec" >/dev/null 2>&1; then
        log "WARNING: /tmp not mounted with noexec option"
    fi
    
    log "PASS: Filesystem security check completed"
    return 0
}

# Main security check function
main() {
    log "Starting container security health check"
    
    local failed_checks=0
    
    for check in "${SECURITY_CHECKS[@]}"; do
        log "Running security check: ${check}"
        if ! "${check}"; then
            ((failed_checks++))
            log "FAILED: Security check ${check}"
        else
            log "PASSED: Security check ${check}"
        fi
    done
    
    if [[ "${failed_checks}" -gt 0 ]]; then
        log "SECURITY CHECK FAILED: ${failed_checks} checks failed"
        exit 1
    else
        log "SECURITY CHECK PASSED: All security checks completed successfully"
        exit 0
    fi
}

# Run main function
main "$@"