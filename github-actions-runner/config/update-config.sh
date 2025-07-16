#!/bin/bash

# Configuration Update Management Script
# Handles configuration updates without requiring container rebuilds

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$SCRIPT_DIR"
BACKUP_DIR="$PROJECT_DIR/backups/config"
LOG_FILE="$PROJECT_DIR/logs/config-update.log"

# Lock file for atomic operations
LOCK_FILE="/tmp/config-update.lock"
LOCK_TIMEOUT=300

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
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

# Lock management
acquire_lock() {
    local timeout=${1:-$LOCK_TIMEOUT}
    local count=0
    
    while [ $count -lt $timeout ]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            trap 'rm -f "$LOCK_FILE"; exit $?' INT TERM EXIT
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    error "Failed to acquire lock after $timeout seconds"
    return 1
}

release_lock() {
    rm -f "$LOCK_FILE"
    trap - INT TERM EXIT
}

# Backup functions
backup_config() {
    local config_type="${1:-all}"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/${config_type}_${timestamp}"
    
    info "Creating configuration backup: $backup_path"
    
    mkdir -p "$backup_path"
    
    case "$config_type" in
        "all")
            cp -r "$CONFIG_DIR"/* "$backup_path/"
            cp "$PROJECT_DIR/.env" "$backup_path/" 2>/dev/null || true
            cp "$PROJECT_DIR/docker-compose.yml" "$backup_path/" 2>/dev/null || true
            ;;
        "env")
            cp "$CONFIG_DIR/runner.env" "$backup_path/" 2>/dev/null || true
            cp "$PROJECT_DIR/.env" "$backup_path/" 2>/dev/null || true
            ;;
        "runner")
            cp "$CONFIG_DIR/runner-config.yml" "$backup_path/" 2>/dev/null || true
            ;;
        "network")
            cp "$CONFIG_DIR/network-config.yml" "$backup_path/" 2>/dev/null || true
            ;;
        "integration")
            cp "$CONFIG_DIR/integration-config.yml" "$backup_path/" 2>/dev/null || true
            ;;
        *)
            error "Unknown backup type: $config_type"
            return 1
            ;;
    esac
    
    # Create backup metadata
    cat > "$backup_path/metadata.json" << EOF
{
    "backup_type": "$config_type",
    "timestamp": "$timestamp",
    "created_at": "$(date -Iseconds)",
    "created_by": "$(whoami)",
    "hostname": "$(hostname)",
    "project_dir": "$PROJECT_DIR"
}
EOF
    
    success "Configuration backup created: $backup_path"
    echo "$backup_path"
}

restore_config() {
    local backup_path="$1"
    local force="${2:-false}"
    
    if [ ! -d "$backup_path" ]; then
        error "Backup directory not found: $backup_path"
        return 1
    fi
    
    if [ ! -f "$backup_path/metadata.json" ]; then
        error "Backup metadata not found: $backup_path/metadata.json"
        return 1
    fi
    
    if ! acquire_lock; then
        return 1
    fi
    
    info "Restoring configuration from: $backup_path"
    
    # Create current backup before restore
    if [ "$force" != "true" ]; then
        local current_backup
        current_backup=$(backup_config "all")
        info "Current configuration backed up to: $current_backup"
    fi
    
    # Restore configuration files
    if [ -f "$backup_path/runner.env" ]; then
        cp "$backup_path/runner.env" "$CONFIG_DIR/"
        info "Restored runner.env"
    fi
    
    if [ -f "$backup_path/.env" ]; then
        cp "$backup_path/.env" "$PROJECT_DIR/"
        info "Restored .env"
    fi
    
    if [ -f "$backup_path/runner-config.yml" ]; then
        cp "$backup_path/runner-config.yml" "$CONFIG_DIR/"
        info "Restored runner-config.yml"
    fi
    
    if [ -f "$backup_path/network-config.yml" ]; then
        cp "$backup_path/network-config.yml" "$CONFIG_DIR/"
        info "Restored network-config.yml"
    fi
    
    if [ -f "$backup_path/integration-config.yml" ]; then
        cp "$backup_path/integration-config.yml" "$CONFIG_DIR/"
        info "Restored integration-config.yml"
    fi
    
    if [ -f "$backup_path/docker-compose.yml" ]; then
        cp "$backup_path/docker-compose.yml" "$PROJECT_DIR/"
        info "Restored docker-compose.yml"
    fi
    
    # Validate restored configuration
    if "$CONFIG_DIR/validate-config.sh" config >/dev/null 2>&1; then
        success "Configuration restored and validated successfully"
    else
        error "Configuration validation failed after restore"
        release_lock
        return 1
    fi
    
    release_lock
    return 0
}

# Configuration update functions
update_environment_variable() {
    local var_name="$1"
    local var_value="$2"
    local env_file="${3:-$CONFIG_DIR/runner.env}"
    
    if [ ! -f "$env_file" ]; then
        error "Environment file not found: $env_file"
        return 1
    fi
    
    if ! acquire_lock; then
        return 1
    fi
    
    info "Updating environment variable: $var_name"
    
    # Backup current configuration
    backup_config "env" >/dev/null
    
    # Update the variable
    if grep -q "^$var_name=" "$env_file"; then
        # Variable exists, update it
        sed -i "s/^$var_name=.*/$var_name=\"$var_value\"/" "$env_file"
        info "Updated existing variable: $var_name"
    else
        # Variable doesn't exist, add it
        echo "$var_name=\"$var_value\"" >> "$env_file"
        info "Added new variable: $var_name"
    fi
    
    # Validate configuration
    if "$CONFIG_DIR/validate-config.sh" config >/dev/null 2>&1; then
        success "Environment variable updated and validated"
    else
        error "Configuration validation failed after update"
        release_lock
        return 1
    fi
    
    release_lock
    return 0
}

update_yaml_value() {
    local yaml_file="$1"
    local yaml_path="$2"
    local yaml_value="$3"
    
    if [ ! -f "$yaml_file" ]; then
        error "YAML file not found: $yaml_file"
        return 1
    fi
    
    if ! command -v yq >/dev/null 2>&1; then
        error "yq command not found. Please install yq to update YAML files."
        return 1
    fi
    
    if ! acquire_lock; then
        return 1
    fi
    
    info "Updating YAML value: $yaml_path in $yaml_file"
    
    # Backup current configuration
    local config_type
    case "$(basename "$yaml_file")" in
        "runner-config.yml") config_type="runner" ;;
        "network-config.yml") config_type="network" ;;
        "integration-config.yml") config_type="integration" ;;
        *) config_type="all" ;;
    esac
    
    backup_config "$config_type" >/dev/null
    
    # Update the YAML value
    if yq eval "$yaml_path = \"$yaml_value\"" -i "$yaml_file"; then
        info "Updated YAML value: $yaml_path"
    else
        error "Failed to update YAML value: $yaml_path"
        release_lock
        return 1
    fi
    
    # Validate configuration
    if "$CONFIG_DIR/validate-config.sh" config >/dev/null 2>&1; then
        success "YAML value updated and validated"
    else
        error "Configuration validation failed after update"
        release_lock
        return 1
    fi
    
    release_lock
    return 0
}

# Service management functions
reload_configuration() {
    local service_name="${1:-all}"
    
    info "Reloading configuration for: $service_name"
    
    # Validate configuration before reload
    if ! "$CONFIG_DIR/validate-config.sh" config >/dev/null 2>&1; then
        error "Configuration validation failed. Cannot reload."
        return 1
    fi
    
    case "$service_name" in
        "all")
            reload_all_services
            ;;
        "runner")
            reload_runner_service
            ;;
        "nginx")
            reload_nginx_service
            ;;
        "prometheus")
            reload_prometheus_service
            ;;
        "fluent-bit")
            reload_fluent_bit_service
            ;;
        *)
            error "Unknown service: $service_name"
            return 1
            ;;
    esac
}

reload_all_services() {
    info "Reloading all services..."
    
    cd "$PROJECT_DIR"
    
    # Use docker-compose to reload services
    if docker-compose restart >/dev/null 2>&1; then
        success "All services reloaded successfully"
    else
        error "Failed to reload services"
        return 1
    fi
}

reload_runner_service() {
    info "Reloading runner service..."
    
    cd "$PROJECT_DIR"
    
    if docker-compose restart runner >/dev/null 2>&1; then
        success "Runner service reloaded successfully"
    else
        error "Failed to reload runner service"
        return 1
    fi
}

reload_nginx_service() {
    info "Reloading nginx service..."
    
    cd "$PROJECT_DIR"
    
    # Send HUP signal to nginx for graceful reload
    if docker-compose exec nginx nginx -s reload >/dev/null 2>&1; then
        success "Nginx service reloaded successfully"
    else
        warning "Graceful reload failed, restarting nginx service"
        if docker-compose restart nginx_proxy >/dev/null 2>&1; then
            success "Nginx service restarted successfully"
        else
            error "Failed to restart nginx service"
            return 1
        fi
    fi
}

reload_prometheus_service() {
    info "Reloading prometheus service..."
    
    cd "$PROJECT_DIR"
    
    # Send HUP signal to prometheus for configuration reload
    if docker-compose exec metrics_collector kill -HUP 1 >/dev/null 2>&1; then
        success "Prometheus service reloaded successfully"
    else
        warning "Graceful reload failed, restarting prometheus service"
        if docker-compose restart metrics_collector >/dev/null 2>&1; then
            success "Prometheus service restarted successfully"
        else
            error "Failed to restart prometheus service"
            return 1
        fi
    fi
}

reload_fluent_bit_service() {
    info "Reloading fluent-bit service..."
    
    cd "$PROJECT_DIR"
    
    # Fluent Bit doesn't support graceful reload, restart instead
    if docker-compose restart log_aggregator >/dev/null 2>&1; then
        success "Fluent Bit service restarted successfully"
    else
        error "Failed to restart fluent-bit service"
        return 1
    fi
}

# Configuration migration functions
migrate_configuration() {
    local from_version="$1"
    local to_version="$2"
    
    info "Migrating configuration from version $from_version to $to_version"
    
    # Create backup before migration
    backup_config "all" >/dev/null
    
    case "$from_version" in
        "1.0")
            migrate_from_v1_0 "$to_version"
            ;;
        "1.1")
            migrate_from_v1_1 "$to_version"
            ;;
        *)
            error "Unknown source version: $from_version"
            return 1
            ;;
    esac
    
    # Validate migrated configuration
    if "$CONFIG_DIR/validate-config.sh" config >/dev/null 2>&1; then
        success "Configuration migrated successfully"
    else
        error "Configuration validation failed after migration"
        return 1
    fi
}

migrate_from_v1_0() {
    local to_version="$1"
    
    info "Migrating from version 1.0..."
    
    # Add new environment variables
    if [ -f "$CONFIG_DIR/runner.env" ]; then
        echo "RUNNER_ENVIRONMENT=production" >> "$CONFIG_DIR/runner.env"
        echo "FEATURE_FLAG_ENHANCED_LOGGING=true" >> "$CONFIG_DIR/runner.env"
    fi
    
    # Update YAML configurations
    if [ -f "$CONFIG_DIR/runner-config.yml" ]; then
        # Add new sections or update existing ones
        yq eval '.features.beta.improved_caching = true' -i "$CONFIG_DIR/runner-config.yml"
    fi
    
    success "Migration from version 1.0 completed"
}

migrate_from_v1_1() {
    local to_version="$1"
    
    info "Migrating from version 1.1..."
    
    # Update specific configurations for version 1.1 to newer
    if [ -f "$CONFIG_DIR/integration-config.yml" ]; then
        # Update integration settings
        yq eval '.monitoring.prometheus.enabled = true' -i "$CONFIG_DIR/integration-config.yml"
    fi
    
    success "Migration from version 1.1 completed"
}

# Configuration templating functions
generate_config_from_template() {
    local template_name="$1"
    local environment="${2:-production}"
    
    info "Generating configuration from template: $template_name"
    
    case "$template_name" in
        "development")
            generate_development_config
            ;;
        "staging")
            generate_staging_config
            ;;
        "production")
            generate_production_config
            ;;
        *)
            error "Unknown template: $template_name"
            return 1
            ;;
    esac
    
    success "Configuration generated from template: $template_name"
}

generate_development_config() {
    info "Generating development configuration..."
    
    # Copy example configuration
    cp "$CONFIG_DIR/runner.env.example" "$CONFIG_DIR/runner.env"
    
    # Update for development
    update_environment_variable "RUNNER_ENVIRONMENT" "development"
    update_environment_variable "RUNNER_DEBUG" "true"
    update_environment_variable "RUNNER_VERBOSE_LOGGING" "true"
    update_environment_variable "RUNNER_LOG_LEVEL" "DEBUG"
    
    # Update YAML configurations
    if [ -f "$CONFIG_DIR/runner-config.yml" ]; then
        yq eval '.troubleshooting.debug.enabled = true' -i "$CONFIG_DIR/runner-config.yml"
        yq eval '.logging.level = "DEBUG"' -i "$CONFIG_DIR/runner-config.yml"
    fi
}

generate_staging_config() {
    info "Generating staging configuration..."
    
    # Copy example configuration
    cp "$CONFIG_DIR/runner.env.example" "$CONFIG_DIR/runner.env"
    
    # Update for staging
    update_environment_variable "RUNNER_ENVIRONMENT" "staging"
    update_environment_variable "RUNNER_DEBUG" "false"
    update_environment_variable "RUNNER_VERBOSE_LOGGING" "true"
    update_environment_variable "RUNNER_LOG_LEVEL" "INFO"
    
    # Update YAML configurations
    if [ -f "$CONFIG_DIR/runner-config.yml" ]; then
        yq eval '.troubleshooting.debug.enabled = false' -i "$CONFIG_DIR/runner-config.yml"
        yq eval '.logging.level = "INFO"' -i "$CONFIG_DIR/runner-config.yml"
    fi
}

generate_production_config() {
    info "Generating production configuration..."
    
    # Copy example configuration
    cp "$CONFIG_DIR/runner.env.example" "$CONFIG_DIR/runner.env"
    
    # Update for production
    update_environment_variable "RUNNER_ENVIRONMENT" "production"
    update_environment_variable "RUNNER_DEBUG" "false"
    update_environment_variable "RUNNER_VERBOSE_LOGGING" "false"
    update_environment_variable "RUNNER_LOG_LEVEL" "INFO"
    
    # Update YAML configurations
    if [ -f "$CONFIG_DIR/runner-config.yml" ]; then
        yq eval '.troubleshooting.debug.enabled = false' -i "$CONFIG_DIR/runner-config.yml"
        yq eval '.logging.level = "INFO"' -i "$CONFIG_DIR/runner-config.yml"
        yq eval '.security.enabled = true' -i "$CONFIG_DIR/runner-config.yml"
    fi
}

# Configuration status functions
show_config_status() {
    info "Configuration Status:"
    echo
    
    # Check configuration files
    echo "Configuration Files:"
    for file in "runner.env" "runner-config.yml" "network-config.yml" "integration-config.yml"; do
        if [ -f "$CONFIG_DIR/$file" ]; then
            echo -e "  ${GREEN}✓${NC} $file"
        else
            echo -e "  ${RED}✗${NC} $file"
        fi
    done
    echo
    
    # Check service status
    echo "Service Status:"
    cd "$PROJECT_DIR"
    docker-compose ps --format table
    echo
    
    # Check recent backups
    echo "Recent Backups:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR" | tail -5
    else
        echo "  No backups found"
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    backup <type>                     Create configuration backup
    restore <backup_path>             Restore configuration from backup
    update-env <var> <value>          Update environment variable
    update-yaml <file> <path> <value> Update YAML configuration
    reload [service]                  Reload service configuration
    migrate <from> <to>               Migrate configuration between versions
    generate <template>               Generate configuration from template
    status                           Show configuration status
    validate                         Validate current configuration

Backup Types:
    all, env, runner, network, integration

Services:
    all, runner, nginx, prometheus, fluent-bit

Templates:
    development, staging, production

Examples:
    $0 backup all
    $0 restore /path/to/backup
    $0 update-env RUNNER_DEBUG true
    $0 update-yaml runner-config.yml '.logging.level' 'DEBUG'
    $0 reload runner
    $0 migrate 1.0 1.1
    $0 generate development
    $0 status
    $0 validate
EOF
}

# Main function
main() {
    local command="${1:-}"
    
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    
    case "$command" in
        "backup")
            local backup_type="${2:-all}"
            backup_config "$backup_type"
            ;;
        "restore")
            local backup_path="${2:-}"
            local force="${3:-false}"
            if [ -z "$backup_path" ]; then
                error "Backup path is required"
                usage
                exit 1
            fi
            restore_config "$backup_path" "$force"
            ;;
        "update-env")
            local var_name="${2:-}"
            local var_value="${3:-}"
            if [ -z "$var_name" ] || [ -z "$var_value" ]; then
                error "Variable name and value are required"
                usage
                exit 1
            fi
            update_environment_variable "$var_name" "$var_value"
            ;;
        "update-yaml")
            local yaml_file="${2:-}"
            local yaml_path="${3:-}"
            local yaml_value="${4:-}"
            if [ -z "$yaml_file" ] || [ -z "$yaml_path" ] || [ -z "$yaml_value" ]; then
                error "YAML file, path, and value are required"
                usage
                exit 1
            fi
            update_yaml_value "$CONFIG_DIR/$yaml_file" "$yaml_path" "$yaml_value"
            ;;
        "reload")
            local service_name="${2:-all}"
            reload_configuration "$service_name"
            ;;
        "migrate")
            local from_version="${2:-}"
            local to_version="${3:-}"
            if [ -z "$from_version" ] || [ -z "$to_version" ]; then
                error "Source and target versions are required"
                usage
                exit 1
            fi
            migrate_configuration "$from_version" "$to_version"
            ;;
        "generate")
            local template_name="${2:-production}"
            generate_config_from_template "$template_name"
            ;;
        "status")
            show_config_status
            ;;
        "validate")
            "$CONFIG_DIR/validate-config.sh"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"