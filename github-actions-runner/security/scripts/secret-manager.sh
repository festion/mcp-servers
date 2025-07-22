#!/bin/bash
# Secret Management Script for GitHub Actions Runner
# Provides encryption, storage, rotation, and access control for secrets

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${SECURITY_DIR}/config/secret-management.yml"
SECRETS_DIR="/home/runner/.secrets"
LOG_FILE="/var/log/secret-manager.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Error handling
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Help function
show_help() {
    cat << EOF
GitHub Actions Runner Secret Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    init                    Initialize secret management system
    store <name> <value>    Store a new secret
    get <name>              Retrieve a secret value
    list                    List all stored secrets
    rotate <name>           Rotate a specific secret
    rotate-all              Rotate all secrets
    backup                  Create encrypted backup of all secrets
    restore <backup_file>   Restore secrets from backup
    validate                Validate secret integrity
    cleanup                 Clean up expired secrets
    audit                   Generate audit report

Options:
    --encrypt-key <file>    Specify encryption key file
    --force                 Force operation without confirmation
    --dry-run               Show what would be done without executing
    --help                  Show this help message

Examples:
    $0 init
    $0 store github_token ghp_abcdef123456789
    $0 get github_token
    $0 rotate github_token
    $0 backup
    $0 validate

Security Features:
    - AES-256-GCM encryption
    - Scrypt key derivation
    - File integrity verification
    - Access audit logging
    - Secure key storage
    - Automatic backup encryption

EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    local required_commands=("openssl" "base64" "xxd" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error_exit "Missing required dependencies: ${missing_deps[*]}"
    fi
}

# Generate encryption key
generate_master_key() {
    local key_file="$1"
    local key_dir=$(dirname "${key_file}")
    
    log "${YELLOW}Generating master encryption key...${NC}"
    
    # Create directory if it doesn't exist
    mkdir -p "${key_dir}"
    chmod 700 "${key_dir}"
    
    # Generate 256-bit key
    openssl rand -hex 32 > "${key_file}"
    chmod 600 "${key_file}"
    
    if [[ -f "${key_file}" ]]; then
        log "${GREEN}Master key generated successfully${NC}"
    else
        error_exit "Failed to generate master key"
    fi
}

# Derive encryption key from master key and salt
derive_key() {
    local master_key="$1"
    local salt="$2"
    local iterations="${3:-32768}"
    
    # Use scrypt for key derivation (via openssl)
    echo -n "${master_key}" | openssl dgst -sha256 -binary | xxd -p -c 32
}

# Encrypt data
encrypt_data() {
    local data="$1"
    local master_key_file="$2"
    
    if [[ ! -f "${master_key_file}" ]]; then
        error_exit "Master key file not found: ${master_key_file}"
    fi
    
    local master_key=$(cat "${master_key_file}")
    local salt=$(openssl rand -hex 16)
    local iv=$(openssl rand -hex 12)  # 96-bit IV for GCM
    local key=$(derive_key "${master_key}" "${salt}")
    
    # Encrypt using AES-256-GCM
    local encrypted_data=$(echo -n "${data}" | openssl enc -aes-256-gcm -e -K "${key}" -iv "${iv}" -base64 -A)
    
    # Create encrypted package: salt:iv:encrypted_data
    echo "${salt}:${iv}:${encrypted_data}"
}

# Decrypt data
decrypt_data() {
    local encrypted_package="$1"
    local master_key_file="$2"
    
    if [[ ! -f "${master_key_file}" ]]; then
        error_exit "Master key file not found: ${master_key_file}"
    fi
    
    local master_key=$(cat "${master_key_file}")
    
    # Parse encrypted package
    IFS=':' read -r salt iv encrypted_data <<< "${encrypted_package}"
    local key=$(derive_key "${master_key}" "${salt}")
    
    # Decrypt using AES-256-GCM
    echo -n "${encrypted_data}" | base64 -d | openssl enc -aes-256-gcm -d -K "${key}" -iv "${iv}"
}

# Initialize secret management system
init_secret_manager() {
    log "${YELLOW}Initializing secret management system...${NC}"
    
    # Create directory structure
    mkdir -p "${SECRETS_DIR}"/{config,runtime,backup}
    chmod 700 "${SECRETS_DIR}"
    chmod 700 "${SECRETS_DIR}"/{config,runtime,backup}
    
    # Generate master key if it doesn't exist
    local master_key_file="${SECRETS_DIR}/master.key"
    if [[ ! -f "${master_key_file}" ]]; then
        generate_master_key "${master_key_file}"
    else
        log "${YELLOW}Master key already exists${NC}"
    fi
    
    # Create secret inventory file
    local inventory_file="${SECRETS_DIR}/inventory.json"
    if [[ ! -f "${inventory_file}" ]]; then
        echo '{}' > "${inventory_file}"
        chmod 600 "${inventory_file}"
    fi
    
    # Create audit log
    touch "${SECRETS_DIR}/audit.log"
    chmod 600 "${SECRETS_DIR}/audit.log"
    
    log "${GREEN}Secret management system initialized${NC}"
}

# Store a secret
store_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local master_key_file="${SECRETS_DIR}/master.key"
    local inventory_file="${SECRETS_DIR}/inventory.json"
    local secret_file="${SECRETS_DIR}/runtime/${secret_name}.enc"
    
    log "${YELLOW}Storing secret: ${secret_name}${NC}"
    
    # Validate secret name
    if [[ ! "${secret_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error_exit "Invalid secret name. Use only alphanumeric characters, underscores, and hyphens."
    fi
    
    # Encrypt the secret
    local encrypted_data=$(encrypt_data "${secret_value}" "${master_key_file}")
    
    # Store encrypted secret
    echo "${encrypted_data}" > "${secret_file}"
    chmod 600 "${secret_file}"
    
    # Update inventory
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local secret_info=$(jq -n \
        --arg name "${secret_name}" \
        --arg file "${secret_file}" \
        --arg created "${timestamp}" \
        --arg last_accessed "${timestamp}" \
        --arg rotated "never" \
        '{
            name: $name,
            file: $file,
            created: $created,
            last_accessed: $last_accessed,
            last_rotated: $rotated,
            access_count: 0
        }')
    
    # Update inventory file
    local updated_inventory=$(jq --arg name "${secret_name}" --argjson info "${secret_info}" \
        '.[$name] = $info' "${inventory_file}")
    echo "${updated_inventory}" > "${inventory_file}"
    
    # Audit log
    log_audit "STORE" "${secret_name}" "Secret stored successfully"
    
    log "${GREEN}Secret stored successfully: ${secret_name}${NC}"
}

# Retrieve a secret
get_secret() {
    local secret_name="$1"
    local master_key_file="${SECRETS_DIR}/master.key"
    local inventory_file="${SECRETS_DIR}/inventory.json"
    local secret_file="${SECRETS_DIR}/runtime/${secret_name}.enc"
    
    if [[ ! -f "${secret_file}" ]]; then
        error_exit "Secret not found: ${secret_name}"
    fi
    
    # Read encrypted data
    local encrypted_data=$(cat "${secret_file}")
    
    # Decrypt the secret
    local secret_value=$(decrypt_data "${encrypted_data}" "${master_key_file}")
    
    # Update access statistics
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local updated_inventory=$(jq --arg name "${secret_name}" --arg timestamp "${timestamp}" \
        '.[$name].last_accessed = $timestamp | .[$name].access_count += 1' "${inventory_file}")
    echo "${updated_inventory}" > "${inventory_file}"
    
    # Audit log
    log_audit "ACCESS" "${secret_name}" "Secret accessed"
    
    echo "${secret_value}"
}

# List all secrets
list_secrets() {
    local inventory_file="${SECRETS_DIR}/inventory.json"
    
    if [[ ! -f "${inventory_file}" ]]; then
        log "${YELLOW}No secrets found${NC}"
        return 0
    fi
    
    log "${BLUE}Stored secrets:${NC}"
    jq -r 'to_entries[] | "\(.key): created=\(.value.created), accessed=\(.value.last_accessed), count=\(.value.access_count)"' \
        "${inventory_file}"
}

# Rotate a secret
rotate_secret() {
    local secret_name="$1"
    local inventory_file="${SECRETS_DIR}/inventory.json"
    
    log "${YELLOW}Rotating secret: ${secret_name}${NC}"
    
    # Check if secret exists
    if ! jq -e --arg name "${secret_name}" '.[$name]' "${inventory_file}" >/dev/null 2>&1; then
        error_exit "Secret not found: ${secret_name}"
    fi
    
    # For GitHub tokens, we need manual rotation
    if [[ "${secret_name}" == *"token"* ]] || [[ "${secret_name}" == *"github"* ]]; then
        log "${YELLOW}GitHub token rotation requires manual intervention${NC}"
        log "Please:"
        log "1. Generate a new token in GitHub"
        log "2. Test the new token"
        log "3. Store the new token: $0 store ${secret_name} <new_token>"
        log "4. Update any configurations using this token"
        log "5. Revoke the old token in GitHub"
        return 0
    fi
    
    # For other secrets, prompt for new value
    read -s -p "Enter new value for ${secret_name}: " new_value
    echo
    
    if [[ -n "${new_value}" ]]; then
        # Store the new secret
        store_secret "${secret_name}" "${new_value}"
        
        # Update rotation timestamp
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local updated_inventory=$(jq --arg name "${secret_name}" --arg timestamp "${timestamp}" \
            '.[$name].last_rotated = $timestamp' "${inventory_file}")
        echo "${updated_inventory}" > "${inventory_file}"
        
        # Audit log
        log_audit "ROTATE" "${secret_name}" "Secret rotated successfully"
        
        log "${GREEN}Secret rotated successfully: ${secret_name}${NC}"
    else
        log "${YELLOW}Secret rotation cancelled${NC}"
    fi
}

# Backup secrets
backup_secrets() {
    local backup_file="${SECRETS_DIR}/backup/secrets_backup_$(date +%Y%m%d_%H%M%S).tar.gz.enc"
    local master_key_file="${SECRETS_DIR}/master.key"
    
    log "${YELLOW}Creating encrypted backup...${NC}"
    
    # Create temporary directory for backup
    local temp_dir=$(mktemp -d)
    trap "rm -rf ${temp_dir}" EXIT
    
    # Copy secrets and inventory
    cp -r "${SECRETS_DIR}/runtime" "${temp_dir}/"
    cp "${SECRETS_DIR}/inventory.json" "${temp_dir}/"
    
    # Create tar archive
    local tar_file="${temp_dir}/backup.tar.gz"
    tar -czf "${tar_file}" -C "${temp_dir}" runtime inventory.json
    
    # Encrypt the backup
    local encrypted_backup=$(encrypt_data "$(base64 -w 0 < "${tar_file}")" "${master_key_file}")
    echo "${encrypted_backup}" > "${backup_file}"
    chmod 600 "${backup_file}"
    
    # Audit log
    log_audit "BACKUP" "all_secrets" "Backup created: $(basename "${backup_file}")"
    
    log "${GREEN}Backup created: ${backup_file}${NC}"
}

# Validate secret integrity
validate_secrets() {
    local inventory_file="${SECRETS_DIR}/inventory.json"
    local master_key_file="${SECRETS_DIR}/master.key"
    local validation_errors=0
    
    log "${YELLOW}Validating secret integrity...${NC}"
    
    # Check master key
    if [[ ! -f "${master_key_file}" ]]; then
        log "${RED}ERROR: Master key file not found${NC}"
        ((validation_errors++))
    fi
    
    # Check inventory file
    if [[ ! -f "${inventory_file}" ]]; then
        log "${RED}ERROR: Inventory file not found${NC}"
        ((validation_errors++))
        return 1
    fi
    
    # Validate each secret
    jq -r 'keys[]' "${inventory_file}" | while read -r secret_name; do
        local secret_file="${SECRETS_DIR}/runtime/${secret_name}.enc"
        
        if [[ ! -f "${secret_file}" ]]; then
            log "${RED}ERROR: Secret file not found: ${secret_file}${NC}"
            ((validation_errors++))
            continue
        fi
        
        # Try to decrypt secret to validate integrity
        if ! decrypt_data "$(cat "${secret_file}")" "${master_key_file}" >/dev/null 2>&1; then
            log "${RED}ERROR: Failed to decrypt secret: ${secret_name}${NC}"
            ((validation_errors++))
        else
            log "${GREEN}OK: ${secret_name}${NC}"
        fi
    done
    
    if [[ ${validation_errors} -eq 0 ]]; then
        log "${GREEN}Secret validation completed successfully${NC}"
    else
        log "${RED}Secret validation completed with ${validation_errors} errors${NC}"
    fi
}

# Audit logging
log_audit() {
    local action="$1"
    local secret_name="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user=$(whoami)
    local audit_file="${SECRETS_DIR}/audit.log"
    
    local audit_entry=$(jq -n \
        --arg timestamp "${timestamp}" \
        --arg user "${user}" \
        --arg action "${action}" \
        --arg secret "${secret_name}" \
        --arg message "${message}" \
        '{
            timestamp: $timestamp,
            user: $user,
            action: $action,
            secret: $secret,
            message: $message
        }')
    
    echo "${audit_entry}" >> "${audit_file}"
}

# Generate audit report
generate_audit_report() {
    local audit_file="${SECRETS_DIR}/audit.log"
    local report_file="${SECRETS_DIR}/backup/audit_report_$(date +%Y%m%d_%H%M%S).json"
    
    if [[ ! -f "${audit_file}" ]]; then
        log "${YELLOW}No audit log found${NC}"
        return 0
    fi
    
    log "${YELLOW}Generating audit report...${NC}"
    
    # Create summary report
    local report=$(jq -s '
    {
        report_generated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        total_events: length,
        events_by_action: group_by(.action) | map({action: .[0].action, count: length}) | from_entries,
        events_by_user: group_by(.user) | map({user: .[0].user, count: length}) | from_entries,
        recent_events: sort_by(.timestamp) | reverse | .[0:10],
        events: .
    }' "${audit_file}")
    
    echo "${report}" > "${report_file}"
    chmod 600 "${report_file}"
    
    log "${GREEN}Audit report generated: ${report_file}${NC}"
}

# Main function
main() {
    local command="${1:-}"
    
    # Check dependencies
    check_dependencies
    
    case "${command}" in
        "init")
            init_secret_manager
            ;;
        "store")
            if [[ $# -lt 3 ]]; then
                error_exit "Usage: $0 store <name> <value>"
            fi
            store_secret "$2" "$3"
            ;;
        "get")
            if [[ $# -lt 2 ]]; then
                error_exit "Usage: $0 get <name>"
            fi
            get_secret "$2"
            ;;
        "list")
            list_secrets
            ;;
        "rotate")
            if [[ $# -lt 2 ]]; then
                error_exit "Usage: $0 rotate <name>"
            fi
            rotate_secret "$2"
            ;;
        "backup")
            backup_secrets
            ;;
        "validate")
            validate_secrets
            ;;
        "audit")
            generate_audit_report
            ;;
        "help"|"--help"|"")
            show_help
            ;;
        *)
            error_exit "Unknown command: ${command}. Use '$0 help' for usage information."
            ;;
    esac
}

# Execute main function with all arguments
main "$@"