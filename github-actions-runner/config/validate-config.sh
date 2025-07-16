#!/bin/bash

# Configuration Validation Script for GitHub Actions Runner
# Validates all configuration files and environment settings

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$SCRIPT_DIR"
LOG_FILE="$PROJECT_DIR/logs/config-validation.log"

# Validation results
VALIDATION_PASSED=true
VALIDATION_ERRORS=()
VALIDATION_WARNINGS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    VALIDATION_ERRORS+=("$*")
    VALIDATION_PASSED=false
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
    VALIDATION_WARNINGS+=("$*")
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

# Validation functions
validate_required_file() {
    local file_path="$1"
    local description="$2"
    
    if [ ! -f "$file_path" ]; then
        error "Required file missing: $file_path ($description)"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        error "Required file not readable: $file_path ($description)"
        return 1
    fi
    
    info "Found required file: $file_path"
    return 0
}

validate_optional_file() {
    local file_path="$1"
    local description="$2"
    
    if [ ! -f "$file_path" ]; then
        warning "Optional file missing: $file_path ($description)"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        warning "Optional file not readable: $file_path ($description)"
        return 1
    fi
    
    info "Found optional file: $file_path"
    return 0
}

validate_yaml_syntax() {
    local file_path="$1"
    local description="$2"
    
    if ! command -v yq >/dev/null 2>&1; then
        warning "yq not available, skipping YAML validation for $file_path"
        return 0
    fi
    
    if ! yq eval '.' "$file_path" >/dev/null 2>&1; then
        error "Invalid YAML syntax in $file_path ($description)"
        return 1
    fi
    
    success "Valid YAML syntax: $file_path"
    return 0
}

validate_json_syntax() {
    local file_path="$1"
    local description="$2"
    
    if ! command -v jq >/dev/null 2>&1; then
        warning "jq not available, skipping JSON validation for $file_path"
        return 0
    fi
    
    if ! jq . "$file_path" >/dev/null 2>&1; then
        error "Invalid JSON syntax in $file_path ($description)"
        return 1
    fi
    
    success "Valid JSON syntax: $file_path"
    return 0
}

validate_environment_variables() {
    local env_file="$1"
    
    info "Validating environment variables in $env_file"
    
    if [ ! -f "$env_file" ]; then
        error "Environment file not found: $env_file"
        return 1
    fi
    
    # Source the environment file safely
    local temp_env_file=$(mktemp)
    grep -v '^#' "$env_file" | grep -v '^$' > "$temp_env_file" || true
    
    # Check required variables
    local required_vars=(
        "GITHUB_REPOSITORY_URL"
        "RUNNER_NAME"
        "RUNNER_ENVIRONMENT"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$temp_env_file"; then
            error "Required environment variable missing: $var"
        else
            info "Found required variable: $var"
        fi
    done
    
    # Validate specific variable formats
    validate_env_var_format "$temp_env_file" "GITHUB_REPOSITORY_URL" '^https://github\.com/[^/]+/[^/]+$'
    validate_env_var_format "$temp_env_file" "RUNNER_NAME" '^[a-zA-Z0-9_-]+$'
    validate_env_var_format "$temp_env_file" "RUNNER_ENVIRONMENT" '^(development|staging|production)$'
    
    # Validate numeric variables
    validate_env_var_numeric "$temp_env_file" "RUNNER_CPU_LIMIT" 0.1 16.0
    validate_env_var_numeric "$temp_env_file" "RUNNER_MEMORY_LIMIT" 1 64
    validate_env_var_numeric "$temp_env_file" "BACKUP_RETENTION_DAYS" 1 365
    
    # Validate boolean variables
    validate_env_var_boolean "$temp_env_file" "RUNNER_DEBUG"
    validate_env_var_boolean "$temp_env_file" "HEALTH_CHECK_ENABLED"
    validate_env_var_boolean "$temp_env_file" "METRICS_ENABLED"
    
    rm -f "$temp_env_file"
    success "Environment variables validation completed"
}

validate_env_var_format() {
    local env_file="$1"
    local var_name="$2"
    local pattern="$3"
    
    local value
    value=$(grep "^$var_name=" "$env_file" | cut -d'=' -f2- | tr -d '"' || echo "")
    
    if [ -n "$value" ]; then
        if [[ "$value" =~ $pattern ]]; then
            success "Valid format for $var_name: $value"
        else
            error "Invalid format for $var_name: $value (expected pattern: $pattern)"
        fi
    fi
}

validate_env_var_numeric() {
    local env_file="$1"
    local var_name="$2"
    local min_value="$3"
    local max_value="$4"
    
    local value
    value=$(grep "^$var_name=" "$env_file" | cut -d'=' -f2- | tr -d '"' || echo "")
    
    if [ -n "$value" ]; then
        # Remove unit suffixes (G, M, K)
        local numeric_value
        numeric_value=$(echo "$value" | sed 's/[GMK]i\?$//')
        
        if [[ "$numeric_value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            if (( $(echo "$numeric_value >= $min_value" | bc -l) )) && (( $(echo "$numeric_value <= $max_value" | bc -l) )); then
                success "Valid numeric value for $var_name: $value"
            else
                error "Numeric value out of range for $var_name: $value (expected: $min_value - $max_value)"
            fi
        else
            error "Invalid numeric format for $var_name: $value"
        fi
    fi
}

validate_env_var_boolean() {
    local env_file="$1"
    local var_name="$2"
    
    local value
    value=$(grep "^$var_name=" "$env_file" | cut -d'=' -f2- | tr -d '"' || echo "")
    
    if [ -n "$value" ]; then
        if [[ "$value" =~ ^(true|false|True|False|TRUE|FALSE|yes|no|Yes|No|YES|NO|1|0)$ ]]; then
            success "Valid boolean value for $var_name: $value"
        else
            error "Invalid boolean format for $var_name: $value (expected: true/false)"
        fi
    fi
}

validate_network_connectivity() {
    info "Validating network connectivity"
    
    # Test GitHub API connectivity
    if curl -s --max-time 10 "https://api.github.com/rate_limit" >/dev/null 2>&1; then
        success "GitHub API connectivity: OK"
    else
        error "GitHub API connectivity: FAILED"
    fi
    
    # Test private network connectivity
    if ping -c 1 -W 5 192.168.1.155 >/dev/null 2>&1; then
        success "Private network connectivity (192.168.1.155): OK"
    else
        warning "Private network connectivity (192.168.1.155): FAILED"
    fi
    
    # Test DNS resolution
    if nslookup api.github.com >/dev/null 2>&1; then
        success "DNS resolution: OK"
    else
        error "DNS resolution: FAILED"
    fi
}

validate_docker_environment() {
    info "Validating Docker environment"
    
    # Check Docker installation
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker not installed or not in PATH"
        return 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon not running or not accessible"
        return 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        error "Docker Compose not installed or not in PATH"
        return 1
    fi
    
    # Check Docker Compose file
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        if docker-compose -f "$PROJECT_DIR/docker-compose.yml" config >/dev/null 2>&1; then
            success "Docker Compose configuration: OK"
        else
            error "Docker Compose configuration: INVALID"
        fi
    else
        error "Docker Compose file not found"
    fi
    
    success "Docker environment validation completed"
}

validate_file_permissions() {
    info "Validating file permissions"
    
    # Check script permissions
    local scripts_dir="$PROJECT_DIR/scripts"
    if [ -d "$scripts_dir" ]; then
        for script in "$scripts_dir"/*.sh; do
            if [ -f "$script" ]; then
                if [ -x "$script" ]; then
                    success "Script executable: $(basename "$script")"
                else
                    error "Script not executable: $(basename "$script")"
                fi
            fi
        done
    fi
    
    # Check configuration permissions
    if [ -f "$CONFIG_DIR/runner.env" ]; then
        local perms
        perms=$(stat -c "%a" "$CONFIG_DIR/runner.env")
        if [ "$perms" = "600" ] || [ "$perms" = "644" ]; then
            success "Configuration file permissions: OK"
        else
            warning "Configuration file permissions may be too open: $perms"
        fi
    fi
    
    # Check token manager permissions
    if [ -f "$CONFIG_DIR/token-manager.sh" ]; then
        if [ -x "$CONFIG_DIR/token-manager.sh" ]; then
            success "Token manager executable: OK"
        else
            error "Token manager not executable"
        fi
    fi
}

validate_system_requirements() {
    info "Validating system requirements"
    
    # Check available disk space
    local disk_usage
    disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -lt 80 ]; then
        success "Disk space: OK ($disk_usage% used)"
    else
        warning "Disk space: LOW ($disk_usage% used)"
    fi
    
    # Check available memory
    local mem_total
    mem_total=$(free -m | awk 'NR==2{printf "%d", $2}')
    
    if [ "$mem_total" -gt 2048 ]; then
        success "Memory: OK (${mem_total}MB available)"
    else
        warning "Memory: LOW (${mem_total}MB available, minimum 2GB recommended)"
    fi
    
    # Check CPU cores
    local cpu_cores
    cpu_cores=$(nproc)
    
    if [ "$cpu_cores" -gt 1 ]; then
        success "CPU cores: OK ($cpu_cores cores)"
    else
        warning "CPU cores: LOW ($cpu_cores core, minimum 2 cores recommended)"
    fi
}

validate_security_configuration() {
    info "Validating security configuration"
    
    # Check for secure token storage
    if [ -d "/run/secrets" ]; then
        success "Secure token storage directory exists"
    else
        warning "Secure token storage directory not found"
    fi
    
    # Check SSL certificates
    if [ -f "$PROJECT_DIR/nginx/ssl/cert.pem" ] && [ -f "$PROJECT_DIR/nginx/ssl/key.pem" ]; then
        success "SSL certificates found"
        
        # Validate certificate
        if openssl x509 -in "$PROJECT_DIR/nginx/ssl/cert.pem" -text -noout >/dev/null 2>&1; then
            success "SSL certificate is valid"
        else
            error "SSL certificate is invalid"
        fi
    else
        warning "SSL certificates not found"
    fi
}

validate_configuration_files() {
    info "Validating configuration files"
    
    # Required files
    validate_required_file "$CONFIG_DIR/runner.env.example" "Environment template"
    validate_required_file "$CONFIG_DIR/token-manager.sh" "Token manager script"
    validate_required_file "$CONFIG_DIR/runner-config.yml" "Runner configuration"
    validate_required_file "$CONFIG_DIR/network-config.yml" "Network configuration"
    validate_required_file "$PROJECT_DIR/docker-compose.yml" "Docker Compose file"
    
    # Optional files
    validate_optional_file "$CONFIG_DIR/runner.env" "Environment configuration"
    validate_optional_file "$PROJECT_DIR/.env" "Docker environment file"
    
    # Validate YAML files
    validate_yaml_syntax "$CONFIG_DIR/runner-config.yml" "Runner configuration"
    validate_yaml_syntax "$CONFIG_DIR/network-config.yml" "Network configuration"
    
    # Validate environment files
    if [ -f "$CONFIG_DIR/runner.env" ]; then
        validate_environment_variables "$CONFIG_DIR/runner.env"
    fi
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        validate_environment_variables "$PROJECT_DIR/.env"
    fi
}

# Main validation function
run_validation() {
    local validation_type="${1:-all}"
    
    log "Starting configuration validation ($validation_type)"
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "$validation_type" in
        "all")
            validate_configuration_files
            validate_docker_environment
            validate_network_connectivity
            validate_file_permissions
            validate_system_requirements
            validate_security_configuration
            ;;
        "config")
            validate_configuration_files
            ;;
        "docker")
            validate_docker_environment
            ;;
        "network")
            validate_network_connectivity
            ;;
        "security")
            validate_security_configuration
            ;;
        "system")
            validate_system_requirements
            ;;
        *)
            error "Unknown validation type: $validation_type"
            exit 1
            ;;
    esac
    
    # Print summary
    echo
    echo "================================="
    echo "VALIDATION SUMMARY"
    echo "================================="
    
    if [ ${#VALIDATION_ERRORS[@]} -gt 0 ]; then
        echo -e "${RED}ERRORS (${#VALIDATION_ERRORS[@]}):${NC}"
        for error in "${VALIDATION_ERRORS[@]}"; do
            echo -e "  ${RED}✗${NC} $error"
        done
        echo
    fi
    
    if [ ${#VALIDATION_WARNINGS[@]} -gt 0 ]; then
        echo -e "${YELLOW}WARNINGS (${#VALIDATION_WARNINGS[@]}):${NC}"
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $warning"
        done
        echo
    fi
    
    if [ "$VALIDATION_PASSED" = true ]; then
        echo -e "${GREEN}✓ VALIDATION PASSED${NC}"
        echo "All critical validations passed successfully."
    else
        echo -e "${RED}✗ VALIDATION FAILED${NC}"
        echo "Critical issues found. Please fix errors before proceeding."
    fi
    
    echo
    echo "Full validation log: $LOG_FILE"
    
    # Return appropriate exit code
    if [ "$VALIDATION_PASSED" = true ]; then
        return 0
    else
        return 1
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [validation_type]

Validation Types:
    all       Run all validations (default)
    config    Validate configuration files only
    docker    Validate Docker environment only
    network   Validate network connectivity only
    security  Validate security configuration only
    system    Validate system requirements only

Examples:
    $0              # Run all validations
    $0 config       # Validate configuration files only
    $0 network      # Test network connectivity only
    $0 security     # Check security configuration only
EOF
}

# Main execution
main() {
    local validation_type="${1:-all}"
    
    case "$validation_type" in
        "-h"|"--help")
            usage
            exit 0
            ;;
        *)
            run_validation "$validation_type"
            ;;
    esac
}

# Run main function
main "$@"