#!/bin/bash
# Access Control Setup Script
# Configures authentication, authorization, and access policies

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_DIR="${SECURITY_DIR}/config"
LOG_FILE="/var/log/access-control-setup.log"
RUNNER_USER="runner"
RUNNER_UID=1001
RUNNER_GID=1001

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running as root for system configuration
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root for system configuration"
    fi
}

# Create runner user and group
create_runner_user() {
    log "${YELLOW}Creating runner user and group...${NC}"
    
    # Create group if it doesn't exist
    if ! getent group "${RUNNER_USER}" >/dev/null 2>&1; then
        groupadd -g "${RUNNER_GID}" "${RUNNER_USER}"
        log "Created group: ${RUNNER_USER} (GID: ${RUNNER_GID})"
    else
        log "Group ${RUNNER_USER} already exists"
    fi
    
    # Create user if it doesn't exist
    if ! getent passwd "${RUNNER_USER}" >/dev/null 2>&1; then
        useradd -r -u "${RUNNER_UID}" -g "${RUNNER_USER}" -m -d "/home/${RUNNER_USER}" -s /bin/bash "${RUNNER_USER}"
        log "Created user: ${RUNNER_USER} (UID: ${RUNNER_UID})"
    else
        log "User ${RUNNER_USER} already exists"
    fi
    
    # Set up home directory permissions
    chmod 750 "/home/${RUNNER_USER}"
    chown "${RUNNER_USER}:${RUNNER_USER}" "/home/${RUNNER_USER}"
    
    log "${GREEN}Runner user and group configured successfully${NC}"
}

# Configure SSH access and keys
setup_ssh_security() {
    log "${YELLOW}Configuring SSH security...${NC}"
    
    local ssh_dir="/home/${RUNNER_USER}/.ssh"
    
    # Create SSH directory
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    chown "${RUNNER_USER}:${RUNNER_USER}" "${ssh_dir}"
    
    # Configure SSH client settings
    cat > "${ssh_dir}/config" << 'EOF'
# SSH Client Configuration for GitHub Actions Runner
Host github.com
    HostName github.com
    User git
    Port 22
    IdentityFile ~/.ssh/github_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    
    # Security settings
    Protocol 2
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
    MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
    HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521
    
    # Disable dangerous options
    ForwardAgent no
    ForwardX11 no
    PermitLocalCommand no
    GatewayPorts no
    Tunnel no
EOF

    chmod 600 "${ssh_dir}/config"
    chown "${RUNNER_USER}:${RUNNER_USER}" "${ssh_dir}/config"
    
    # Add GitHub's SSH host keys
    cat > "${ssh_dir}/known_hosts" << 'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF

    chmod 600 "${ssh_dir}/known_hosts"
    chown "${RUNNER_USER}:${RUNNER_USER}" "${ssh_dir}/known_hosts"
    
    log "${GREEN}SSH security configured successfully${NC}"
}

# Configure sudo permissions
setup_sudo_permissions() {
    log "${YELLOW}Configuring sudo permissions...${NC}"
    
    # Create sudoers file for runner user with minimal permissions
    cat > "/etc/sudoers.d/${RUNNER_USER}" << EOF
# Sudoers configuration for GitHub Actions runner
# Minimal permissions for package management and service operations

# Allow specific package management commands
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/apt-get update
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/apt-get install
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/apt-get remove
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/dpkg -i *
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/snap install *
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/snap remove *

# Allow Docker operations (if Docker is installed)
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/docker
${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/bin/docker-compose

# Allow systemctl for service management (limited)
${RUNNER_USER} ALL=(ALL) NOPASSWD: /bin/systemctl start
${RUNNER_USER} ALL=(ALL) NOPASSWD: /bin/systemctl stop
${RUNNER_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart
${RUNNER_USER} ALL=(ALL) NOPASSWD: /bin/systemctl status

# Security restrictions
Defaults:${RUNNER_USER} !visiblepw
Defaults:${RUNNER_USER} always_set_home
Defaults:${RUNNER_USER} match_group_by_gid
Defaults:${RUNNER_USER} always_query_group_plugin
Defaults:${RUNNER_USER} env_reset
Defaults:${RUNNER_USER} env_keep="COLORS DISPLAY HOSTNAME HISTSIZE KDEDIR LS_COLORS"
Defaults:${RUNNER_USER} env_keep+="MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE"
Defaults:${RUNNER_USER} env_keep+="LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES"
Defaults:${RUNNER_USER} env_keep+="LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE"
Defaults:${RUNNER_USER} env_keep+="LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"
Defaults:${RUNNER_USER} secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Explicitly deny dangerous commands
${RUNNER_USER} ALL=!/usr/bin/passwd
${RUNNER_USER} ALL=!/usr/bin/su
${RUNNER_USER} ALL=!/bin/su
${RUNNER_USER} ALL=!/usr/bin/sudo
${RUNNER_USER} ALL=!/bin/mount
${RUNNER_USER} ALL=!/bin/umount
${RUNNER_USER} ALL=!/sbin/mount
${RUNNER_USER} ALL=!/sbin/umount
${RUNNER_USER} ALL=!/usr/bin/chsh
${RUNNER_USER} ALL=!/usr/bin/chfn
${RUNNER_USER} ALL=!/usr/sbin/visudo
${RUNNER_USER} ALL=!/bin/rm -rf /
${RUNNER_USER} ALL=!/rm -rf /
EOF

    chmod 440 "/etc/sudoers.d/${RUNNER_USER}"
    
    # Validate sudoers file
    if ! visudo -c -f "/etc/sudoers.d/${RUNNER_USER}"; then
        error_exit "Invalid sudoers configuration"
    fi
    
    log "${GREEN}Sudo permissions configured successfully${NC}"
}

# Configure file system permissions
setup_filesystem_permissions() {
    log "${YELLOW}Configuring filesystem permissions...${NC}"
    
    local runner_home="/home/${RUNNER_USER}"
    
    # Set up actions-runner directory
    local actions_dir="${runner_home}/actions-runner"
    mkdir -p "${actions_dir}"
    chown -R "${RUNNER_USER}:${RUNNER_USER}" "${actions_dir}"
    chmod 750 "${actions_dir}"
    
    # Set up work directory (for GitHub Actions workflows)
    local work_dir="${runner_home}/actions-runner/_work"
    mkdir -p "${work_dir}"
    chown -R "${RUNNER_USER}:${RUNNER_USER}" "${work_dir}"
    chmod 750 "${work_dir}"
    
    # Set up temporary directories
    mkdir -p /tmp/runner /var/tmp/runner
    chown "${RUNNER_USER}:${RUNNER_USER}" /tmp/runner /var/tmp/runner
    chmod 750 /tmp/runner /var/tmp/runner
    
    # Create audit log directory
    mkdir -p /var/log/runner-audit
    chown "${RUNNER_USER}:${RUNNER_USER}" /var/log/runner-audit
    chmod 750 /var/log/runner-audit
    
    # Set up configuration directory permissions
    if [[ -d "${CONFIG_DIR}" ]]; then
        chown -R root:root "${CONFIG_DIR}"
        find "${CONFIG_DIR}" -type f -exec chmod 600 {} \;
        find "${CONFIG_DIR}" -type d -exec chmod 700 {} \;
    fi
    
    log "${GREEN}Filesystem permissions configured successfully${NC}"
}

# Install and configure audit tools
setup_audit_logging() {
    log "${YELLOW}Setting up audit logging...${NC}"
    
    # Install auditd if not present
    if ! command -v auditctl >/dev/null 2>&1; then
        apt-get update
        apt-get install -y auditd audispd-plugins
    fi
    
    # Configure audit rules for runner user
    cat > /etc/audit/rules.d/runner-audit.rules << EOF
# Audit rules for GitHub Actions runner security monitoring

# Monitor file access in runner home directory
-w /home/${RUNNER_USER} -p wa -k runner_home_access

# Monitor SSH key access
-w /home/${RUNNER_USER}/.ssh -p wa -k ssh_key_access

# Monitor sudo usage
-w /var/log/auth.log -p wa -k sudo_usage

# Monitor process execution
-a always,exit -F arch=b64 -S execve -F uid=${RUNNER_UID} -k runner_process_exec
-a always,exit -F arch=b32 -S execve -F uid=${RUNNER_UID} -k runner_process_exec

# Monitor file permission changes
-a always,exit -F arch=b64 -S chmod -F uid=${RUNNER_UID} -k runner_perm_change
-a always,exit -F arch=b32 -S chmod -F uid=${RUNNER_UID} -k runner_perm_change

# Monitor network connections
-a always,exit -F arch=b64 -S socket -F uid=${RUNNER_UID} -k runner_network

# Monitor file deletion
-a always,exit -F arch=b64 -S unlink -F uid=${RUNNER_UID} -k runner_file_delete
-a always,exit -F arch=b64 -S unlinkat -F uid=${RUNNER_UID} -k runner_file_delete

# Monitor configuration file changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Make audit configuration immutable
-e 2
EOF

    # Restart auditd
    systemctl restart auditd
    systemctl enable auditd
    
    # Create audit log monitoring script
    cat > /usr/local/bin/audit-monitor.sh << 'EOF'
#!/bin/bash
# Audit Log Monitoring Script for GitHub Actions Runner

AUDIT_LOG="/var/log/audit/audit.log"
ALERT_LOG="/var/log/runner-security-alerts.log"
WEBHOOK_URL="${SECURITY_WEBHOOK_URL:-}"

# Function to send alerts
send_alert() {
    local message="$1"
    local severity="$2"
    
    # Log the alert
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${severity}] ${message}" >> "${ALERT_LOG}"
    
    # Send webhook notification if configured
    if [[ -n "${WEBHOOK_URL}" ]]; then
        curl -s -X POST "${WEBHOOK_URL}" \
             -H "Content-Type: application/json" \
             -d "{\"text\":\"Runner Security Alert [${severity}]: ${message}\"}" || true
    fi
}

# Monitor audit events
monitor_events() {
    tail -F "${AUDIT_LOG}" | while read line; do
        # Check for suspicious sudo usage
        if echo "${line}" | grep -q "runner_sudo_usage"; then
            send_alert "Sudo usage detected by runner user" "WARNING"
        fi
        
        # Check for SSH key access
        if echo "${line}" | grep -q "ssh_key_access"; then
            send_alert "SSH key access detected" "INFO"
        fi
        
        # Check for file permission changes
        if echo "${line}" | grep -q "runner_perm_change"; then
            send_alert "File permission change by runner user" "WARNING"
        fi
        
        # Check for network connections
        if echo "${line}" | grep -q "runner_network"; then
            send_alert "Network connection initiated by runner" "INFO"
        fi
        
        # Check for file deletion
        if echo "${line}" | grep -q "runner_file_delete"; then
            send_alert "File deletion by runner user" "WARNING"
        fi
        
        # Check for configuration changes
        if echo "${line}" | grep -E "(passwd_changes|group_changes|shadow_changes|sudoers_changes)"; then
            send_alert "System configuration file changed" "CRITICAL"
        fi
    done
}

# Start monitoring
monitor_events &
EOF

    chmod +x /usr/local/bin/audit-monitor.sh
    
    # Create systemd service for audit monitoring
    cat > /etc/systemd/system/audit-monitor.service << 'EOF'
[Unit]
Description=Audit Monitor for GitHub Actions Runner
After=auditd.service
Requires=auditd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/audit-monitor.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable audit-monitor.service
    systemctl start audit-monitor.service
    
    log "${GREEN}Audit logging configured successfully${NC}"
}

# Configure PAM (Pluggable Authentication Modules)
setup_pam_security() {
    log "${YELLOW}Configuring PAM security...${NC}"
    
    # Install libpam-pwquality for password quality enforcement
    apt-get update
    apt-get install -y libpam-pwquality
    
    # Configure password quality requirements
    cat > /etc/security/pwquality.conf << 'EOF'
# Password quality requirements for GitHub Actions runner environment
minlen = 12
minclass = 3
maxrepeat = 2
maxsequence = 3
gecoscheck = 1
dictcheck = 1
usercheck = 1
enforcing = 1
retry = 3
EOF

    # Configure login security
    cat >> /etc/security/limits.conf << EOF

# GitHub Actions runner security limits
${RUNNER_USER} soft nproc 1000
${RUNNER_USER} hard nproc 1000
${RUNNER_USER} soft nofile 1024
${RUNNER_USER} hard nofile 1024
${RUNNER_USER} soft core 0
${RUNNER_USER} hard core 0
EOF

    log "${GREEN}PAM security configured successfully${NC}"
}

# Validate access control configuration
validate_access_control() {
    log "${YELLOW}Validating access control configuration...${NC}"
    
    local validation_errors=0
    
    # Check runner user exists
    if ! getent passwd "${RUNNER_USER}" >/dev/null 2>&1; then
        log "${RED}ERROR: Runner user ${RUNNER_USER} does not exist${NC}"
        ((validation_errors++))
    fi
    
    # Check SSH directory permissions
    local ssh_dir="/home/${RUNNER_USER}/.ssh"
    if [[ -d "${ssh_dir}" ]]; then
        local ssh_perms=$(stat -c "%a" "${ssh_dir}")
        if [[ "${ssh_perms}" != "700" ]]; then
            log "${RED}ERROR: SSH directory has incorrect permissions: ${ssh_perms}${NC}"
            ((validation_errors++))
        fi
    fi
    
    # Check sudoers configuration
    if [[ ! -f "/etc/sudoers.d/${RUNNER_USER}" ]]; then
        log "${RED}ERROR: Sudoers configuration for ${RUNNER_USER} not found${NC}"
        ((validation_errors++))
    fi
    
    # Check audit service
    if ! systemctl is-active --quiet auditd; then
        log "${RED}ERROR: Audit service is not running${NC}"
        ((validation_errors++))
    fi
    
    # Check audit monitor service
    if ! systemctl is-active --quiet audit-monitor; then
        log "${RED}ERROR: Audit monitor service is not running${NC}"
        ((validation_errors++))
    fi
    
    if [[ ${validation_errors} -eq 0 ]]; then
        log "${GREEN}Access control validation passed${NC}"
        return 0
    else
        log "${RED}Access control validation failed with ${validation_errors} errors${NC}"
        return 1
    fi
}

# Main setup function
main() {
    log "${GREEN}Starting access control setup for GitHub Actions runner${NC}"
    
    check_permissions
    create_runner_user
    setup_ssh_security
    setup_sudo_permissions
    setup_filesystem_permissions
    setup_audit_logging
    setup_pam_security
    
    if validate_access_control; then
        log "${GREEN}Access control setup completed successfully${NC}"
        log "Configuration summary:"
        log "- Runner user: ${RUNNER_USER} (UID: ${RUNNER_UID}, GID: ${RUNNER_GID})"
        log "- SSH directory: /home/${RUNNER_USER}/.ssh (permissions: 700)"
        log "- Sudo configuration: /etc/sudoers.d/${RUNNER_USER}"
        log "- Audit logging: enabled and monitoring"
        log "- PAM security: configured with password quality"
    else
        error_exit "Access control setup validation failed"
    fi
}

# Execute main function
main "$@"