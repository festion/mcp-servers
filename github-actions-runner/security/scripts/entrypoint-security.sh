#!/bin/bash
# Security Hardened Entrypoint Script
# Performs security checks and setup before starting the GitHub Actions runner

set -euo pipefail

# Configuration
SECURITY_LOG="/var/log/entrypoint-security.log"
RUNNER_HOME="/home/runner"
ACTIONS_RUNNER_DIR="${RUNNER_HOME}/actions-runner"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ENTRYPOINT: $1" | tee -a "${SECURITY_LOG}" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ENTRYPOINT: $1"
}

# Security validation function
validate_security() {
    log "Starting security validation"
    
    # Validate running user
    if [[ "$(id -u)" -eq 0 ]]; then
        log "SECURITY ERROR: Cannot run as root user"
        exit 1
    fi
    
    # Validate user ID
    if [[ "$(id -u)" -ne 1001 ]]; then
        log "SECURITY ERROR: Must run as user ID 1001"
        exit 1
    fi
    
    # Validate home directory permissions
    if [[ ! -O "${RUNNER_HOME}" ]]; then
        log "SECURITY ERROR: Runner home directory not owned by current user"
        exit 1
    fi
    
    # Validate actions-runner directory
    if [[ ! -d "${ACTIONS_RUNNER_DIR}" ]]; then
        log "SECURITY ERROR: Actions runner directory not found"
        exit 1
    fi
    
    if [[ ! -O "${ACTIONS_RUNNER_DIR}" ]]; then
        log "SECURITY ERROR: Actions runner directory not owned by current user"
        exit 1
    fi
    
    log "Security validation completed successfully"
}

# Environment security setup
setup_security_environment() {
    log "Setting up security environment"
    
    # Set secure umask
    umask 0077
    
    # Clear potentially dangerous environment variables
    unset LD_PRELOAD LD_LIBRARY_PATH
    
    # Set secure PATH
    export PATH="/usr/local/bin:/usr/bin:/bin"
    
    # Ensure secure tmp directories exist
    if [[ ! -d "/tmp" ]]; then
        mkdir -p /tmp
        chmod 1777 /tmp
    fi
    
    # Set resource limits
    if command -v ulimit >/dev/null 2>&1; then
        # Limit core dumps
        ulimit -c 0
        # Limit number of processes
        ulimit -u 1000
        # Limit file size
        ulimit -f 1048576  # 1GB
        # Limit open files
        ulimit -n 1024
    fi
    
    log "Security environment setup completed"
}

# Validate GitHub token security
validate_github_token() {
    log "Validating GitHub token security"
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log "WARNING: GITHUB_TOKEN not set"
        return 0
    fi
    
    # Check token format
    if [[ ! "${GITHUB_TOKEN}" =~ ^gh[ps]_[A-Za-z0-9_]{36,255}$ ]]; then
        log "SECURITY WARNING: GitHub token format appears invalid"
    fi
    
    # Check token is not empty or placeholder
    if [[ "${GITHUB_TOKEN}" == "your-token-here" ]] || [[ "${GITHUB_TOKEN}" == "placeholder" ]]; then
        log "SECURITY ERROR: GitHub token appears to be a placeholder"
        exit 1
    fi
    
    log "GitHub token validation completed"
}

# Setup monitoring and logging
setup_monitoring() {
    log "Setting up security monitoring"
    
    # Create audit log directory
    local audit_dir="/var/log/audit"
    if [[ ! -d "${audit_dir}" ]]; then
        mkdir -p "${audit_dir}" 2>/dev/null || true
    fi
    
    # Start background security monitoring
    if [[ -x "/usr/local/bin/container-security-check.sh" ]]; then
        # Run security check in background every 5 minutes
        (
            while true; do
                sleep 300
                /usr/local/bin/container-security-check.sh || log "Security check failed"
            done
        ) &
        log "Background security monitoring started"
    fi
    
    log "Security monitoring setup completed"
}

# Validate runner configuration
validate_runner_config() {
    log "Validating runner configuration"
    
    # Check required environment variables
    local required_vars=("RUNNER_NAME" "RUNNER_URL" "RUNNER_TOKEN")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log "CONFIGURATION ERROR: Required environment variable ${var} is not set"
            exit 1
        fi
    done
    
    # Validate runner URL format
    if [[ ! "${RUNNER_URL}" =~ ^https://github\.com/ ]]; then
        log "SECURITY WARNING: Runner URL does not appear to be a GitHub URL"
    fi
    
    # Check for configuration file
    if [[ -f "${ACTIONS_RUNNER_DIR}/.runner" ]]; then
        log "Found existing runner configuration"
        # Validate configuration file permissions
        local config_perms=$(stat -c "%a" "${ACTIONS_RUNNER_DIR}/.runner")
        if [[ "${config_perms}" != "600" ]]; then
            log "SECURITY WARNING: Runner configuration file has insecure permissions (${config_perms})"
            chmod 600 "${ACTIONS_RUNNER_DIR}/.runner"
        fi
    fi
    
    log "Runner configuration validation completed"
}

# Security cleanup function
security_cleanup() {
    log "Performing security cleanup"
    
    # Clear sensitive environment variables from history
    history -c 2>/dev/null || true
    
    # Clear any temporary files in predictable locations
    find /tmp -name ".*" -type f -delete 2>/dev/null || true
    find /var/tmp -name ".*" -type f -delete 2>/dev/null || true
    
    log "Security cleanup completed"
}

# Signal handlers for graceful shutdown
cleanup_and_exit() {
    log "Received shutdown signal, performing cleanup"
    security_cleanup
    exit 0
}

# Set up signal handlers
trap cleanup_and_exit SIGTERM SIGINT

# Main entrypoint function
main() {
    log "Starting security-hardened GitHub Actions runner entrypoint"
    
    # Perform security validations
    validate_security
    setup_security_environment
    validate_github_token
    validate_runner_config
    setup_monitoring
    
    log "Security setup completed, starting GitHub Actions runner"
    
    # Change to actions-runner directory
    cd "${ACTIONS_RUNNER_DIR}"
    
    # Configure runner if not already configured
    if [[ ! -f ".runner" ]]; then
        log "Configuring GitHub Actions runner"
        ./config.sh --url "${RUNNER_URL}" --token "${RUNNER_TOKEN}" --name "${RUNNER_NAME}" --unattended --replace
        
        # Secure the configuration file
        chmod 600 .runner
        log "Runner configuration completed and secured"
    fi
    
    # Start the runner
    log "Starting GitHub Actions runner"
    exec "$@"
}

# Execute main function with all arguments
main "$@"