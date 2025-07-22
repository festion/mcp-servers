#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENVIRONMENT="${1:-dev}"

log_info "Starting pre-deployment validation for environment: $ENVIRONMENT"

validate_prerequisites() {
    log_info "Validating prerequisites"
    
    local required_commands=("docker" "docker-compose" "git" "curl" "jq" "nc")
    
    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            log_error "Missing required command: $cmd"
            exit 1
        fi
    done
    
    log_success "All required commands are available"
}

validate_environment_config() {
    log_info "Validating environment configuration"
    
    local env_file="$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if ! check_file "$env_file"; then
        exit 1
    fi
    
    source "$env_file"
    
    local required_vars=(
        "DEPLOY_HOST"
        "DEPLOY_PORT"
        "DEPLOY_USER"
        "DEPLOY_PATH"
        "GITHUB_RUNNER_VERSION"
        "GITHUB_RUNNER_COUNT"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Missing required environment variable: $var"
            exit 1
        fi
    done
    
    log_success "Environment configuration is valid"
}

validate_network_connectivity() {
    log_info "Validating network connectivity"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if ! check_port "$DEPLOY_PORT" "$DEPLOY_HOST"; then
        log_error "Cannot connect to deployment host: $DEPLOY_HOST:$DEPLOY_PORT"
        exit 1
    fi
    
    if ! curl -s --max-time 10 https://api.github.com/zen > /dev/null; then
        log_error "Cannot connect to GitHub API"
        exit 1
    fi
    
    log_success "Network connectivity validated"
}

validate_github_credentials() {
    log_info "Validating GitHub credentials"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN is not set"
        exit 1
    fi
    
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   https://api.github.com/user)
    
    if ! echo "$response" | jq -e '.login' > /dev/null; then
        log_error "Invalid GitHub token"
        exit 1
    fi
    
    local username
    username=$(echo "$response" | jq -r '.login')
    log_success "GitHub credentials validated for user: $username"
}

validate_docker_environment() {
    log_info "Validating Docker environment"
    
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}')
    log_info "Docker version: $docker_version"
    
    if ! docker-compose version > /dev/null 2>&1; then
        log_error "Docker Compose is not available"
        exit 1
    fi
    
    log_success "Docker environment validated"
}

validate_deployment_files() {
    log_info "Validating deployment files"
    
    local required_files=(
        "$SCRIPT_DIR/deploy-config.sh"
        "$SCRIPT_DIR/deploy-app.sh"
        "$SCRIPT_DIR/post-deploy.sh"
        "$SCRIPT_DIR/rollback.sh"
        "$SCRIPT_DIR/../infrastructure/docker-compose.yml"
    )
    
    for file in "${required_files[@]}"; do
        if ! check_file "$file"; then
            exit 1
        fi
    done
    
    if ! validate_yaml "$SCRIPT_DIR/../infrastructure/docker-compose.yml"; then
        exit 1
    fi
    
    log_success "All deployment files are valid"
}

validate_storage_space() {
    log_info "Validating storage space"
    
    local required_space_gb=10
    local available_space_gb
    available_space_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if (( available_space_gb < required_space_gb )); then
        log_error "Insufficient storage space. Required: ${required_space_gb}GB, Available: ${available_space_gb}GB"
        exit 1
    fi
    
    log_success "Storage space validated: ${available_space_gb}GB available"
}

validate_port_availability() {
    log_info "Validating port availability"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local required_ports=(
        "${GITHUB_RUNNER_PORT:-8080}"
        "${MONITORING_PORT:-9090}"
        "${METRICS_PORT:-8081}"
    )
    
    for port in "${required_ports[@]}"; do
        if check_port "$port"; then
            log_warn "Port $port is already in use"
        else
            log_success "Port $port is available"
        fi
    done
}

validate_security_settings() {
    log_info "Validating security settings"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        if [[ "${ENABLE_DEBUG:-false}" == "true" ]]; then
            log_error "Debug mode should not be enabled in production"
            exit 1
        fi
        
        if [[ -z "${SSL_CERT_PATH:-}" ]] || [[ -z "${SSL_KEY_PATH:-}" ]]; then
            log_error "SSL certificates are required for production"
            exit 1
        fi
    fi
    
    log_success "Security settings validated"
}

validate_backup_availability() {
    log_info "Validating backup availability"
    
    source "$SCRIPT_DIR/../environments/$ENVIRONMENT.env"
    
    local backup_dir="${BACKUP_DIR:-/tmp/deployment-backups}"
    
    if [[ ! -d "$backup_dir" ]]; then
        mkdir -p "$backup_dir"
        log_info "Created backup directory: $backup_dir"
    fi
    
    if [[ ! -w "$backup_dir" ]]; then
        log_error "Backup directory is not writable: $backup_dir"
        exit 1
    fi
    
    log_success "Backup availability validated"
}

generate_pre_deploy_report() {
    log_info "Generating pre-deployment report"
    
    local report_file="/tmp/pre-deploy-report-$ENVIRONMENT-$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "environment": "$ENVIRONMENT",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "validation_status": "passed",
    "system_info": {
        "hostname": "$(hostname)",
        "os": "$(uname -o)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "docker_version": "$(docker version --format '{{.Server.Version}}')",
        "available_memory": "$(free -h | awk '/^Mem:/ {print $7}')",
        "available_storage": "$(df -h . | awk 'NR==2 {print $4}')"
    },
    "validations": {
        "prerequisites": "passed",
        "environment_config": "passed",
        "network_connectivity": "passed",
        "github_credentials": "passed",
        "docker_environment": "passed",
        "deployment_files": "passed",
        "storage_space": "passed",
        "port_availability": "passed",
        "security_settings": "passed",
        "backup_availability": "passed"
    }
}
EOF
    
    log_success "Pre-deployment report generated: $report_file"
}

main() {
    validate_prerequisites
    validate_environment_config
    validate_network_connectivity
    validate_github_credentials
    validate_docker_environment
    validate_deployment_files
    validate_storage_space
    validate_port_availability
    validate_security_settings
    validate_backup_availability
    generate_pre_deploy_report
    
    log_success "Pre-deployment validation completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi