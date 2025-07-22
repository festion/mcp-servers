#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command not found: $1"
        return 1
    fi
}

check_file() {
    if [[ ! -f "$1" ]]; then
        log_error "Required file not found: $1"
        return 1
    fi
}

check_directory() {
    if [[ ! -d "$1" ]]; then
        log_error "Required directory not found: $1"
        return 1
    fi
}

wait_for_service() {
    local service_name="$1"
    local health_check_url="$2"
    local timeout="${3:-60}"
    local interval="${4:-5}"
    
    log_info "Waiting for $service_name to be ready..."
    
    local count=0
    while (( count < timeout )); do
        if curl -s -o /dev/null -w "%{http_code}" "$health_check_url" | grep -q "200"; then
            log_success "$service_name is ready"
            return 0
        fi
        
        sleep "$interval"
        count=$((count + interval))
    done
    
    log_error "$service_name failed to start within $timeout seconds"
    return 1
}

backup_file() {
    local file="$1"
    local backup_dir="${2:-/tmp/deployment-backups}"
    
    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/$(basename "$file").$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup_file"
        log_info "Backed up $file to $backup_file"
    fi
}

restore_file() {
    local backup_file="$1"
    local target_file="$2"
    
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$target_file"
        log_info "Restored $target_file from $backup_file"
    else
        log_error "Backup file not found: $backup_file"
        return 1
    fi
}

get_container_status() {
    local container_name="$1"
    docker ps --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

get_service_logs() {
    local service_name="$1"
    local lines="${2:-50}"
    
    if command -v docker &> /dev/null; then
        docker logs --tail "$lines" "$service_name" 2>/dev/null || true
    fi
    
    if command -v systemctl &> /dev/null; then
        systemctl --user status "$service_name" 2>/dev/null || true
    fi
}

check_port() {
    local port="$1"
    local host="${2:-localhost}"
    
    if nc -z "$host" "$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

generate_config() {
    local template_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    log_info "Generating configuration from template: $template_file"
    
    envsubst < "$template_file" > "$output_file"
    
    log_success "Configuration generated: $output_file"
}

send_notification() {
    local message="$1"
    local level="${2:-info}"
    
    case "$level" in
        error)
            log_error "$message"
            ;;
        warn)
            log_warn "$message"
            ;;
        success)
            log_success "$message"
            ;;
        *)
            log_info "$message"
            ;;
    esac
    
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
}

retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    
    local attempt=1
    while (( attempt <= max_attempts )); do
        if "$@"; then
            return 0
        fi
        
        log_warn "Command failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts"
    return 1
}

validate_json() {
    local json_file="$1"
    
    if ! jq . "$json_file" > /dev/null 2>&1; then
        log_error "Invalid JSON in file: $json_file"
        return 1
    fi
    
    log_success "JSON validation passed: $json_file"
}

validate_yaml() {
    local yaml_file="$1"
    
    if ! python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
        log_error "Invalid YAML in file: $yaml_file"
        return 1
    fi
    
    log_success "YAML validation passed: $yaml_file"
}

calculate_checksum() {
    local file="$1"
    local algorithm="${2:-sha256}"
    
    case "$algorithm" in
        md5)
            md5sum "$file" | cut -d' ' -f1
            ;;
        sha1)
            sha1sum "$file" | cut -d' ' -f1
            ;;
        sha256)
            sha256sum "$file" | cut -d' ' -f1
            ;;
        *)
            log_error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
}

verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    
    local actual_checksum
    actual_checksum=$(calculate_checksum "$file" "$algorithm")
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_success "Checksum verification passed for: $file"
        return 0
    else
        log_error "Checksum verification failed for: $file"
        log_error "Expected: $expected_checksum"
        log_error "Actual: $actual_checksum"
        return 1
    fi
}