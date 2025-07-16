#!/bin/bash

# GitHub Actions Runner Token Manager
# Secure token storage, rotation, and validation system

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TOKEN_DIR="/run/secrets"
BACKUP_DIR="$PROJECT_DIR/backups/tokens"
LOG_FILE="$PROJECT_DIR/logs/token-manager.log"

# Token files
GITHUB_TOKEN_FILE="$TOKEN_DIR/github_runner_token"
HA_TOKEN_FILE="$TOKEN_DIR/ha_token"
BACKUP_KEYS_FILE="$TOKEN_DIR/backup_keys"

# Lock file for atomic operations
LOCK_FILE="/tmp/token-manager.lock"
LOCK_TIMEOUT=300

# Encryption settings
ENCRYPTION_ENABLED=true
ENCRYPTION_KEY_FILE="$TOKEN_DIR/encryption.key"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
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

# Encryption functions
generate_encryption_key() {
    if [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
        log "Generating encryption key..."
        openssl rand -base64 32 > "$ENCRYPTION_KEY_FILE"
        chmod 600 "$ENCRYPTION_KEY_FILE"
        log "Encryption key generated"
    fi
}

encrypt_data() {
    local data="$1"
    if [ "$ENCRYPTION_ENABLED" = "true" ] && [ -f "$ENCRYPTION_KEY_FILE" ]; then
        echo "$data" | openssl enc -aes-256-cbc -base64 -pass file:"$ENCRYPTION_KEY_FILE"
    else
        echo "$data"
    fi
}

decrypt_data() {
    local encrypted_data="$1"
    if [ "$ENCRYPTION_ENABLED" = "true" ] && [ -f "$ENCRYPTION_KEY_FILE" ]; then
        echo "$encrypted_data" | openssl enc -aes-256-cbc -d -base64 -pass file:"$ENCRYPTION_KEY_FILE"
    else
        echo "$encrypted_data"
    fi
}

# Token validation functions
validate_github_token() {
    local token="$1"
    local repo_url="${2:-}"
    
    log "Validating GitHub token..."
    
    # Basic format validation
    if [[ ! "$token" =~ ^(ghp_|gho_|ghu_|ghs_|ghr_)[a-zA-Z0-9_]{36,255}$ ]]; then
        error "Invalid GitHub token format"
        return 1
    fi
    
    # API validation
    local response
    response=$(curl -s -w "%{http_code}" -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user" -o /tmp/token_validation.json)
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log "GitHub token validation successful"
        
        # Check token permissions if repository URL provided
        if [ -n "$repo_url" ]; then
            local repo_path
            repo_path=$(echo "$repo_url" | sed 's/https:\/\/github.com\///' | sed 's/\.git$//')
            
            local repo_response
            repo_response=$(curl -s -w "%{http_code}" -H "Authorization: token $token" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$repo_path" -o /tmp/repo_validation.json)
            
            local repo_http_code="${repo_response: -3}"
            
            if [ "$repo_http_code" = "200" ]; then
                log "Repository access validation successful"
            else
                error "Token does not have access to repository: $repo_path"
                return 1
            fi
        fi
        
        return 0
    else
        error "GitHub token validation failed (HTTP $http_code)"
        return 1
    fi
}

validate_ha_token() {
    local token="$1"
    local ha_host="${2:-192.168.1.155}"
    local ha_port="${3:-8123}"
    
    log "Validating Home Assistant token..."
    
    # Basic format validation (HA tokens are typically long alphanumeric strings)
    if [[ ! "$token" =~ ^[a-zA-Z0-9._-]{20,}$ ]]; then
        error "Invalid Home Assistant token format"
        return 1
    fi
    
    # API validation
    local response
    response=$(curl -s -w "%{http_code}" --max-time 10 \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        "http://$ha_host:$ha_port/api/" -o /tmp/ha_validation.json)
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log "Home Assistant token validation successful"
        return 0
    else
        error "Home Assistant token validation failed (HTTP $http_code)"
        return 1
    fi
}

# Token storage functions
store_token() {
    local token_type="$1"
    local token_value="$2"
    local validate="${3:-true}"
    
    if ! acquire_lock; then
        return 1
    fi
    
    log "Storing $token_type token..."
    
    # Validate token before storing
    if [ "$validate" = "true" ]; then
        case "$token_type" in
            "github")
                if ! validate_github_token "$token_value"; then
                    release_lock
                    return 1
                fi
                ;;
            "ha")
                if ! validate_ha_token "$token_value"; then
                    release_lock
                    return 1
                fi
                ;;
        esac
    fi
    
    # Create token directory if it doesn't exist
    mkdir -p "$TOKEN_DIR"
    chmod 700 "$TOKEN_DIR"
    
    # Generate encryption key if needed
    if [ "$ENCRYPTION_ENABLED" = "true" ]; then
        generate_encryption_key
    fi
    
    # Store token
    local token_file
    case "$token_type" in
        "github")
            token_file="$GITHUB_TOKEN_FILE"
            ;;
        "ha")
            token_file="$HA_TOKEN_FILE"
            ;;
        *)
            error "Unknown token type: $token_type"
            release_lock
            return 1
            ;;
    esac
    
    # Backup existing token if it exists
    if [ -f "$token_file" ]; then
        backup_token "$token_type"
    fi
    
    # Encrypt and store new token
    local encrypted_token
    encrypted_token=$(encrypt_data "$token_value")
    echo "$encrypted_token" > "$token_file"
    chmod 600 "$token_file"
    
    # Store metadata
    cat > "${token_file}.meta" << EOF
{
    "type": "$token_type",
    "stored_at": "$(date -Iseconds)",
    "stored_by": "$(whoami)",
    "encrypted": $ENCRYPTION_ENABLED,
    "validated": $validate
}
EOF
    chmod 600 "${token_file}.meta"
    
    log "$token_type token stored successfully"
    release_lock
    return 0
}

retrieve_token() {
    local token_type="$1"
    local validate="${2:-false}"
    
    local token_file
    case "$token_type" in
        "github")
            token_file="$GITHUB_TOKEN_FILE"
            ;;
        "ha")
            token_file="$HA_TOKEN_FILE"
            ;;
        *)
            error "Unknown token type: $token_type"
            return 1
            ;;
    esac
    
    if [ ! -f "$token_file" ]; then
        error "$token_type token not found"
        return 1
    fi
    
    # Decrypt and retrieve token
    local encrypted_token
    encrypted_token=$(cat "$token_file")
    local token_value
    token_value=$(decrypt_data "$encrypted_token")
    
    # Validate token if requested
    if [ "$validate" = "true" ]; then
        case "$token_type" in
            "github")
                if ! validate_github_token "$token_value"; then
                    return 1
                fi
                ;;
            "ha")
                if ! validate_ha_token "$token_value"; then
                    return 1
                fi
                ;;
        esac
    fi
    
    echo "$token_value"
    return 0
}

# Token backup and restore
backup_token() {
    local token_type="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    
    local token_file
    case "$token_type" in
        "github")
            token_file="$GITHUB_TOKEN_FILE"
            ;;
        "ha")
            token_file="$HA_TOKEN_FILE"
            ;;
        *)
            error "Unknown token type: $token_type"
            return 1
            ;;
    esac
    
    if [ -f "$token_file" ]; then
        cp "$token_file" "$BACKUP_DIR/${token_type}_token_${timestamp}"
        cp "${token_file}.meta" "$BACKUP_DIR/${token_type}_token_${timestamp}.meta" 2>/dev/null || true
        log "Backed up $token_type token to $BACKUP_DIR/${token_type}_token_${timestamp}"
    fi
}

restore_token() {
    local token_type="$1"
    local backup_file="$2"
    
    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
        return 1
    fi
    
    if ! acquire_lock; then
        return 1
    fi
    
    log "Restoring $token_type token from $backup_file..."
    
    local token_file
    case "$token_type" in
        "github")
            token_file="$GITHUB_TOKEN_FILE"
            ;;
        "ha")
            token_file="$HA_TOKEN_FILE"
            ;;
        *)
            error "Unknown token type: $token_type"
            release_lock
            return 1
            ;;
    esac
    
    # Backup current token
    if [ -f "$token_file" ]; then
        backup_token "$token_type"
    fi
    
    # Restore from backup
    cp "$backup_file" "$token_file"
    cp "${backup_file}.meta" "${token_file}.meta" 2>/dev/null || true
    chmod 600 "$token_file"
    chmod 600 "${token_file}.meta" 2>/dev/null || true
    
    log "$token_type token restored successfully"
    release_lock
    return 0
}

# Token rotation
rotate_token() {
    local token_type="$1"
    local new_token="$2"
    
    log "Rotating $token_type token..."
    
    # Store new token
    if store_token "$token_type" "$new_token" true; then
        log "$token_type token rotation completed successfully"
        
        # Restart services if needed
        restart_services_after_rotation "$token_type"
        
        return 0
    else
        error "$token_type token rotation failed"
        return 1
    fi
}

restart_services_after_rotation() {
    local token_type="$1"
    
    case "$token_type" in
        "github")
            log "Restarting GitHub runner services after token rotation..."
            if command -v docker-compose >/dev/null 2>&1; then
                cd "$PROJECT_DIR"
                docker-compose restart runner 2>/dev/null || true
            fi
            ;;
        "ha")
            log "Home Assistant token rotated - no service restart needed"
            ;;
    esac
}

# Token cleanup
cleanup_old_backups() {
    local retention_days="${1:-30}"
    
    log "Cleaning up token backups older than $retention_days days..."
    
    if [ -d "$BACKUP_DIR" ]; then
        find "$BACKUP_DIR" -name "*_token_*" -mtime +$retention_days -delete 2>/dev/null || true
    fi
    
    log "Token backup cleanup completed"
}

# Health check
health_check() {
    log "Running token manager health check..."
    
    local health_status=0
    
    # Check token directory
    if [ ! -d "$TOKEN_DIR" ]; then
        error "Token directory not found: $TOKEN_DIR"
        health_status=1
    fi
    
    # Check GitHub token
    if [ -f "$GITHUB_TOKEN_FILE" ]; then
        if retrieve_token "github" true >/dev/null 2>&1; then
            log "GitHub token is valid"
        else
            error "GitHub token validation failed"
            health_status=1
        fi
    else
        error "GitHub token not found"
        health_status=1
    fi
    
    # Check HA token
    if [ -f "$HA_TOKEN_FILE" ]; then
        if retrieve_token "ha" true >/dev/null 2>&1; then
            log "Home Assistant token is valid"
        else
            error "Home Assistant token validation failed"
            health_status=1
        fi
    else
        log "Home Assistant token not found (optional)"
    fi
    
    # Check encryption key
    if [ "$ENCRYPTION_ENABLED" = "true" ] && [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
        error "Encryption key not found"
        health_status=1
    fi
    
    if [ $health_status -eq 0 ]; then
        log "Token manager health check passed"
    else
        error "Token manager health check failed"
    fi
    
    return $health_status
}

# Usage information
usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    store <type> <token>     Store a new token
    retrieve <type>          Retrieve and display a token
    validate <type>          Validate an existing token
    rotate <type> <token>    Rotate a token
    backup <type>            Backup a token
    restore <type> <file>    Restore a token from backup
    health                   Run health check
    cleanup [days]           Clean up old backups (default: 30 days)

Token Types:
    github                   GitHub runner token
    ha                       Home Assistant token

Options:
    --no-validate           Skip token validation (for store command)
    --force                 Force operation without confirmation

Examples:
    $0 store github ghp_xxxxxxxxxxxxxxxxxxxx
    $0 retrieve github
    $0 validate github
    $0 rotate github ghp_yyyyyyyyyyyyyyyyyyyy
    $0 backup github
    $0 restore github /path/to/backup
    $0 health
    $0 cleanup 7
EOF
}

# Main function
main() {
    local command="${1:-}"
    
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$TOKEN_DIR"
    mkdir -p "$BACKUP_DIR"
    
    case "$command" in
        "store")
            local token_type="${2:-}"
            local token_value="${3:-}"
            local validate=true
            
            if [ "$4" = "--no-validate" ]; then
                validate=false
            fi
            
            if [ -z "$token_type" ] || [ -z "$token_value" ]; then
                error "Token type and value are required"
                usage
                exit 1
            fi
            
            store_token "$token_type" "$token_value" "$validate"
            ;;
        "retrieve")
            local token_type="${2:-}"
            local validate=false
            
            if [ "$3" = "--validate" ]; then
                validate=true
            fi
            
            if [ -z "$token_type" ]; then
                error "Token type is required"
                usage
                exit 1
            fi
            
            retrieve_token "$token_type" "$validate"
            ;;
        "validate")
            local token_type="${2:-}"
            
            if [ -z "$token_type" ]; then
                error "Token type is required"
                usage
                exit 1
            fi
            
            retrieve_token "$token_type" true >/dev/null
            ;;
        "rotate")
            local token_type="${2:-}"
            local new_token="${3:-}"
            
            if [ -z "$token_type" ] || [ -z "$new_token" ]; then
                error "Token type and new token are required"
                usage
                exit 1
            fi
            
            rotate_token "$token_type" "$new_token"
            ;;
        "backup")
            local token_type="${2:-}"
            
            if [ -z "$token_type" ]; then
                error "Token type is required"
                usage
                exit 1
            fi
            
            backup_token "$token_type"
            ;;
        "restore")
            local token_type="${2:-}"
            local backup_file="${3:-}"
            
            if [ -z "$token_type" ] || [ -z "$backup_file" ]; then
                error "Token type and backup file are required"
                usage
                exit 1
            fi
            
            restore_token "$token_type" "$backup_file"
            ;;
        "health")
            health_check
            ;;
        "cleanup")
            local retention_days="${2:-30}"
            cleanup_old_backups "$retention_days"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"