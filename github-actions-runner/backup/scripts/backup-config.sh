#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKUP_ROOT")"

source "$SCRIPT_DIR/common/backup-functions.sh"
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/utils.sh"

setup_logging "/var/log/github-runner-backup-config.log"

usage() {
    cat << 'EOF'
Usage: backup-config.sh [OPTIONS]

Backup configuration files only for GitHub Actions runner

OPTIONS:
    -h, --help              Show this help message
    -d, --destination DIR   Backup destination [default: /var/backups/github-runner/config]
    -c, --config FILE       Backup configuration file
    -e, --encrypt           Encrypt backup files
    -r, --remote            Include remote storage backup
    --include-secrets       Include sensitive configuration files
    --include-env           Include environment files
    --include-docker        Include Docker configurations
    --include-systemd       Include systemd service files
    --format FORMAT         Output format (tar, zip, directory) [default: tar]
    --compression LEVEL     Compression level 0-9 [default: 6]
    --dry-run               Show what would be backed up without creating backup
    --verify                Verify configuration files before backup

Examples:
    ./backup-config.sh                              # Basic config backup
    ./backup-config.sh --include-secrets            # Include sensitive files
    ./backup-config.sh --format zip                 # Create ZIP archive
    ./backup-config.sh --dry-run                    # Preview backup contents
EOF
}

DESTINATION="/var/backups/github-runner/config"
CONFIG_FILE="$BACKUP_ROOT/config/backup.conf"
ENCRYPT=false
REMOTE_BACKUP=false
INCLUDE_SECRETS=false
INCLUDE_ENV=false
INCLUDE_DOCKER=false
INCLUDE_SYSTEMD=false
FORMAT="tar"
COMPRESSION_LEVEL=6
DRY_RUN=false
VERIFY_CONFIG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -e|--encrypt)
            ENCRYPT=true
            shift
            ;;
        -r|--remote)
            REMOTE_BACKUP=true
            shift
            ;;
        --include-secrets)
            INCLUDE_SECRETS=true
            shift
            ;;
        --include-env)
            INCLUDE_ENV=true
            shift
            ;;
        --include-docker)
            INCLUDE_DOCKER=true
            shift
            ;;
        --include-systemd)
            INCLUDE_SYSTEMD=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --compression)
            COMPRESSION_LEVEL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verify)
            VERIFY_CONFIG=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

main() {
    log_section "GitHub Actions Runner - Configuration Backup"
    
    load_backup_config "$CONFIG_FILE"
    validate_backup_environment
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_id="config-backup-$timestamp"
    
    log_info "Starting configuration backup: $backup_id"
    log_info "Destination: $DESTINATION"
    log_info "Format: $FORMAT"
    
    create_backup_directory "$DESTINATION"
    
    if [[ "$VERIFY_CONFIG" == true ]]; then
        verify_configuration_files
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No actual backup will be created"
        preview_config_backup "$backup_id"
        exit 0
    fi
    
    local backup_manifest="$DESTINATION/$backup_id.manifest.json"
    init_backup_manifest "$backup_manifest" "$backup_id" "configuration"
    
    backup_core_configuration "$backup_id"
    backup_runner_configuration "$backup_id"
    
    if [[ "$INCLUDE_ENV" == true ]]; then
        backup_environment_configuration "$backup_id"
    fi
    
    if [[ "$INCLUDE_DOCKER" == true ]]; then
        backup_docker_configuration "$backup_id"
    fi
    
    if [[ "$INCLUDE_SYSTEMD" == true ]]; then
        backup_systemd_configuration "$backup_id"
    fi
    
    if [[ "$INCLUDE_SECRETS" == true ]]; then
        backup_sensitive_configuration "$backup_id"
    fi
    
    backup_monitoring_configuration "$backup_id"
    backup_script_configuration "$backup_id"
    
    create_configuration_archive "$backup_id" "$FORMAT" "$COMPRESSION_LEVEL"
    
    if [[ "$ENCRYPT" == true ]]; then
        encrypt_backup_archive "$backup_id"
    fi
    
    finalize_backup_manifest "$backup_manifest" "$backup_id"
    
    if [[ "$REMOTE_BACKUP" == true ]]; then
        sync_to_remote_storage "$backup_id"
    fi
    
    log_section "Configuration Backup Complete"
    log_success "Backup ID: $backup_id"
    log_info "Location: $DESTINATION/$backup_id"
    
    send_backup_notification "configuration" "$backup_id" "success"
    
    return 0
}

verify_configuration_files() {
    log_info "Verifying configuration files..."
    
    local verification_errors=0
    
    # Check runner configuration
    local runner_config="/opt/github-runner/.runner"
    if [[ -f "$runner_config" ]]; then
        if ! jq . "$runner_config" >/dev/null 2>&1; then
            log_warn "Runner configuration is not valid JSON: $runner_config"
            ((verification_errors++))
        else
            log_debug "Runner configuration verified: $runner_config"
        fi
    fi
    
    # Check docker-compose.yml
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        if command -v docker-compose >/dev/null 2>&1; then
            if ! docker-compose -f "$PROJECT_ROOT/docker-compose.yml" config >/dev/null 2>&1; then
                log_warn "Docker Compose configuration is invalid"
                ((verification_errors++))
            else
                log_debug "Docker Compose configuration verified"
            fi
        fi
    fi
    
    # Check systemd service files
    local service_files=(
        "/etc/systemd/system/github-runner.service"
        "/etc/systemd/system/actions-runner.service"
    )
    
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            if ! systemd-analyze verify "$service_file" >/dev/null 2>&1; then
                log_warn "Systemd service file has issues: $service_file"
                ((verification_errors++))
            else
                log_debug "Systemd service file verified: $service_file"
            fi
        fi
    done
    
    # Check environment files
    local env_files=(
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/config/runner.env"
        "/etc/github-runner/runner.env"
    )
    
    for env_file in "${env_files[@]}"; do
        if [[ -f "$env_file" ]]; then
            # Basic syntax check for env files
            if grep -q "^[A-Z_][A-Z0-9_]*=" "$env_file"; then
                log_debug "Environment file verified: $env_file"
            else
                log_warn "Environment file may have syntax issues: $env_file"
                ((verification_errors++))
            fi
        fi
    done
    
    if [[ "$verification_errors" -gt 0 ]]; then
        log_warn "Found $verification_errors configuration issue(s)"
        log_warn "Backup will continue but you should review these files"
    else
        log_success "All configuration files verified successfully"
    fi
}

backup_core_configuration() {
    local backup_id="$1"
    
    log_info "Backing up core configuration files..."
    
    local temp_dir="/tmp/$backup_id/core"
    mkdir -p "$temp_dir"
    
    local core_configs=(
        "$PROJECT_ROOT/config/runner-config.yml"
        "$PROJECT_ROOT/config/runner.env.example"
        "$PROJECT_ROOT/config/integration-config.yml"
        "$PROJECT_ROOT/config/network-config.yml"
        "$PROJECT_ROOT/config/fluent-bit.conf"
    )
    
    for config_file in "${core_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            local dest_name=$(basename "$config_file")
            cp "$config_file" "$temp_dir/$dest_name"
            
            log_debug "Backed up: $config_file"
            update_backup_manifest "$backup_manifest" "core_config" "$config_file" "$(stat -c%s "$config_file")"
        fi
    done
    
    # Backup configuration directories
    local config_dirs=(
        "$PROJECT_ROOT/config/nginx"
        "$PROJECT_ROOT/config/systemd"
        "$PROJECT_ROOT/config/environments"
    )
    
    for config_dir in "${config_dirs[@]}"; do
        if [[ -d "$config_dir" ]]; then
            local dest_name=$(basename "$config_dir")
            cp -r "$config_dir" "$temp_dir/$dest_name"
            
            log_debug "Backed up directory: $config_dir"
            update_backup_manifest "$backup_manifest" "core_config" "$config_dir" "$(du -sb "$temp_dir/$dest_name" | cut -f1)"
        fi
    done
    
    log_success "Core configuration backed up"
}

backup_runner_configuration() {
    local backup_id="$1"
    
    log_info "Backing up runner-specific configuration..."
    
    local temp_dir="/tmp/$backup_id/runner"
    mkdir -p "$temp_dir"
    
    local runner_configs=(
        "/opt/github-runner/.runner"
        "/opt/github-runner/.credentials"
        "/opt/actions-runner/.runner"
        "/opt/actions-runner/.credentials"
        "/etc/github-runner/config.yml"
        "/etc/actions-runner/config.yml"
    )
    
    for runner_config in "${runner_configs[@]}"; do
        if [[ -f "$runner_config" ]]; then
            local dest_name=$(echo "$runner_config" | sed 's|/|-|g' | sed 's|^-||')
            
            if [[ "$INCLUDE_SECRETS" == true || ! "$runner_config" =~ \.(credentials|token)$ ]]; then
                cp "$runner_config" "$temp_dir/$dest_name"
                
                # Secure sensitive files
                if [[ "$runner_config" =~ \.(credentials|token)$ ]]; then
                    chmod 600 "$temp_dir/$dest_name"
                fi
                
                log_debug "Backed up runner config: $runner_config"
                update_backup_manifest "$backup_manifest" "runner_config" "$runner_config" "$(stat -c%s "$runner_config")"
            fi
        fi
    done
    
    log_success "Runner configuration backed up"
}

backup_environment_configuration() {
    local backup_id="$1"
    
    log_info "Backing up environment configuration..."
    
    local temp_dir="/tmp/$backup_id/environment"
    mkdir -p "$temp_dir"
    
    local env_files=(
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/config/runner.env"
        "$PROJECT_ROOT/config/environments/development.env"
        "$PROJECT_ROOT/config/environments/production.env"
        "/etc/github-runner/runner.env"
        "/etc/default/github-runner"
    )
    
    for env_file in "${env_files[@]}"; do
        if [[ -f "$env_file" ]]; then
            local dest_name=$(echo "$env_file" | sed 's|/|-|g' | sed 's|^-||')
            
            if [[ "$INCLUDE_SECRETS" == true ]]; then
                cp "$env_file" "$temp_dir/$dest_name"
            else
                # Sanitize environment file to remove sensitive values
                sanitize_env_file "$env_file" "$temp_dir/$dest_name"
            fi
            
            log_debug "Backed up environment: $env_file"
            update_backup_manifest "$backup_manifest" "environment_config" "$env_file" "$(stat -c%s "$temp_dir/$dest_name")"
        fi
    done
    
    # Backup current environment variables
    env | grep -E "(GITHUB|RUNNER|ACTIONS)" | sort > "$temp_dir/current-environment.txt" || true
    
    log_success "Environment configuration backed up"
}

backup_docker_configuration() {
    local backup_id="$1"
    
    log_info "Backing up Docker configuration..."
    
    local temp_dir="/tmp/$backup_id/docker"
    mkdir -p "$temp_dir"
    
    local docker_configs=(
        "$PROJECT_ROOT/docker-compose.yml"
        "$PROJECT_ROOT/Dockerfile"
        "$PROJECT_ROOT/security/Dockerfile.hardened"
        "$PROJECT_ROOT/.dockerignore"
    )
    
    for docker_config in "${docker_configs[@]}"; do
        if [[ -f "$docker_config" ]]; then
            local dest_name=$(basename "$docker_config")
            cp "$docker_config" "$temp_dir/$dest_name"
            
            log_debug "Backed up Docker config: $docker_config"
            update_backup_manifest "$backup_manifest" "docker_config" "$docker_config" "$(stat -c%s "$docker_config")"
        fi
    done
    
    # Backup Docker daemon configuration if available
    if [[ -f "/etc/docker/daemon.json" ]]; then
        cp "/etc/docker/daemon.json" "$temp_dir/daemon.json"
    fi
    
    # Export current Docker configuration
    if command -v docker >/dev/null 2>&1; then
        docker info > "$temp_dir/docker-info.txt" 2>/dev/null || true
        docker version > "$temp_dir/docker-version.txt" 2>/dev/null || true
    fi
    
    log_success "Docker configuration backed up"
}

backup_systemd_configuration() {
    local backup_id="$1"
    
    log_info "Backing up systemd configuration..."
    
    local temp_dir="/tmp/$backup_id/systemd"
    mkdir -p "$temp_dir"
    
    local systemd_files=(
        "/etc/systemd/system/github-runner.service"
        "/etc/systemd/system/actions-runner.service"
        "/etc/systemd/system/github-runner.timer"
        "/usr/lib/systemd/system/github-runner.service"
    )
    
    for systemd_file in "${systemd_files[@]}"; do
        if [[ -f "$systemd_file" ]]; then
            local dest_name=$(basename "$systemd_file")
            cp "$systemd_file" "$temp_dir/$dest_name"
            
            log_debug "Backed up systemd file: $systemd_file"
            update_backup_manifest "$backup_manifest" "systemd_config" "$systemd_file" "$(stat -c%s "$systemd_file")"
        fi
    done
    
    # Export current service status
    systemctl status github-runner > "$temp_dir/service-status.txt" 2>&1 || true
    systemctl list-unit-files | grep -E "(runner|github)" > "$temp_dir/unit-files.txt" || true
    
    log_success "Systemd configuration backed up"
}

backup_sensitive_configuration() {
    local backup_id="$1"
    
    log_info "Backing up sensitive configuration files..."
    
    local temp_dir="/tmp/$backup_id/sensitive"
    mkdir -p "$temp_dir"
    chmod 700 "$temp_dir"
    
    local sensitive_files=(
        "/opt/github-runner/.credentials"
        "/opt/github-runner/.runner"
        "/etc/github-runner/token"
        "$HOME/.github_token"
        "$PROJECT_ROOT/config/token-manager.sh"
    )
    
    for sensitive_file in "${sensitive_files[@]}"; do
        if [[ -f "$sensitive_file" ]]; then
            local dest_name=$(echo "$sensitive_file" | sed 's|/|-|g' | sed 's|^-||')
            cp "$sensitive_file" "$temp_dir/$dest_name"
            chmod 600 "$temp_dir/$dest_name"
            
            log_debug "Backed up sensitive file: $sensitive_file"
            update_backup_manifest "$backup_manifest" "sensitive_config" "$sensitive_file" "$(stat -c%s "$sensitive_file")"
        fi
    done
    
    # Backup SSH keys if they exist
    if [[ -d "$HOME/.ssh" ]]; then
        mkdir -p "$temp_dir/ssh"
        find "$HOME/.ssh" -name "id_*" -o -name "*.pem" -o -name "authorized_keys" | while read -r key_file; do
            if [[ -f "$key_file" ]]; then
                cp "$key_file" "$temp_dir/ssh/"
                chmod 600 "$temp_dir/ssh/$(basename "$key_file")"
            fi
        done
    fi
    
    log_success "Sensitive configuration backed up"
}

backup_monitoring_configuration() {
    local backup_id="$1"
    
    log_info "Backing up monitoring configuration..."
    
    local temp_dir="/tmp/$backup_id/monitoring"
    mkdir -p "$temp_dir"
    
    local monitoring_configs=(
        "$PROJECT_ROOT/monitoring/prometheus.yml"
        "$PROJECT_ROOT/monitoring/alerting/runner-alerts.yml"
        "$PROJECT_ROOT/monitoring/health-checks.yml"
        "$PROJECT_ROOT/fluent-bit/fluent-bit.conf"
        "$PROJECT_ROOT/fluent-bit/parsers.conf"
    )
    
    for monitoring_config in "${monitoring_configs[@]}"; do
        if [[ -f "$monitoring_config" ]]; then
            local dest_name=$(echo "$monitoring_config" | sed 's|.*/||' | sed 's|/|-|g')
            cp "$monitoring_config" "$temp_dir/$dest_name"
            
            log_debug "Backed up monitoring config: $monitoring_config"
            update_backup_manifest "$backup_manifest" "monitoring_config" "$monitoring_config" "$(stat -c%s "$monitoring_config")"
        fi
    done
    
    # Backup monitoring directories
    local monitoring_dirs=(
        "$PROJECT_ROOT/monitoring/dashboards"
        "$PROJECT_ROOT/monitoring/configs"
        "$PROJECT_ROOT/prometheus/rules"
    )
    
    for monitoring_dir in "${monitoring_dirs[@]}"; do
        if [[ -d "$monitoring_dir" ]]; then
            local dest_name=$(basename "$monitoring_dir")
            cp -r "$monitoring_dir" "$temp_dir/$dest_name"
            
            log_debug "Backed up monitoring directory: $monitoring_dir"
        fi
    done
    
    log_success "Monitoring configuration backed up"
}

backup_script_configuration() {
    local backup_id="$1"
    
    log_info "Backing up script configuration..."
    
    local temp_dir="/tmp/$backup_id/scripts"
    mkdir -p "$temp_dir"
    
    # Backup all configuration scripts
    find "$PROJECT_ROOT/scripts" -name "*.sh" -o -name "*.yml" -o -name "*.json" | while read -r script_file; do
        if [[ -f "$script_file" ]]; then
            local relative_path="${script_file#$PROJECT_ROOT/scripts/}"
            local dest_file="$temp_dir/$relative_path"
            local dest_dir="$(dirname "$dest_file")"
            
            mkdir -p "$dest_dir"
            cp "$script_file" "$dest_file"
        fi
    done
    
    # Backup cron configurations
    if command -v crontab >/dev/null 2>&1; then
        crontab -l > "$temp_dir/crontab.txt" 2>/dev/null || echo "No crontab" > "$temp_dir/crontab.txt"
    fi
    
    log_success "Script configuration backed up"
}

create_configuration_archive() {
    local backup_id="$1"
    local format="$2"
    local compression_level="$3"
    
    log_info "Creating configuration archive (format: $format)..."
    
    local temp_dir="/tmp/$backup_id"
    local archive_file="$DESTINATION/$backup_id"
    
    cd "$temp_dir"
    
    case "$format" in
        "tar")
            GZIP="-$compression_level" tar -czf "$archive_file.tar.gz" .
            log_info "Created tar archive: $archive_file.tar.gz"
            ;;
        "zip")
            zip -r -"$compression_level" "$archive_file.zip" .
            log_info "Created zip archive: $archive_file.zip"
            ;;
        "directory")
            cp -r "$temp_dir" "$archive_file"
            log_info "Created directory archive: $archive_file"
            ;;
        *)
            log_error "Unsupported format: $format"
            exit 1
            ;;
    esac
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
    
    log_success "Configuration archive created"
}

sanitize_env_file() {
    local source_file="$1"
    local dest_file="$2"
    
    # Create sanitized version of environment file
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            # Keep comments and empty lines
            echo "$line"
        elif [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            
            # Sanitize sensitive variables
            if [[ "$var_name" =~ (TOKEN|PASSWORD|SECRET|KEY|CREDENTIAL) ]]; then
                echo "$var_name=***REDACTED***"
            else
                echo "$line"
            fi
        else
            echo "$line"
        fi
    done < "$source_file" > "$dest_file"
}

preview_config_backup() {
    local backup_id="$1"
    
    log_section "Configuration Backup Preview"
    
    echo "Backup ID: $backup_id"
    echo "Format: $FORMAT"
    echo "Encryption: $ENCRYPT"
    echo "Include secrets: $INCLUDE_SECRETS"
    echo "Include environment: $INCLUDE_ENV"
    echo "Include Docker: $INCLUDE_DOCKER"
    echo "Include systemd: $INCLUDE_SYSTEMD"
    echo
    
    echo "Files that would be backed up:"
    echo "================================"
    
    # Show core config files
    echo "Core configuration:"
    local core_configs=(
        "$PROJECT_ROOT/config/runner-config.yml"
        "$PROJECT_ROOT/config/runner.env.example"
        "$PROJECT_ROOT/config/integration-config.yml"
    )
    
    for config_file in "${core_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            echo "  ✓ $config_file"
        else
            echo "  ✗ $config_file (not found)"
        fi
    done
    
    # Show other categories based on options
    if [[ "$INCLUDE_ENV" == true ]]; then
        echo "Environment files:"
        echo "  ✓ Environment variables and .env files"
    fi
    
    if [[ "$INCLUDE_DOCKER" == true ]]; then
        echo "Docker configuration:"
        echo "  ✓ docker-compose.yml and Dockerfiles"
    fi
    
    if [[ "$INCLUDE_SYSTEMD" == true ]]; then
        echo "Systemd configuration:"
        echo "  ✓ Service files and unit configurations"
    fi
    
    if [[ "$INCLUDE_SECRETS" == true ]]; then
        echo "Sensitive files:"
        echo "  ✓ Tokens, credentials, and keys"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi