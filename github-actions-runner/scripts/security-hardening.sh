#!/bin/bash

set -euo pipefail

# GitHub Actions Runner Security Hardening Script
# This script applies security hardening measures to the runner environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/security.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

harden_file_permissions() {
    log "Hardening file permissions..."
    
    # Set strict permissions on configuration files
    chmod 600 "$PROJECT_DIR/config/runner.env"
    chmod 600 "$PROJECT_DIR/config/fluent-bit.conf"
    chmod 644 "$PROJECT_DIR/docker-compose.yml"
    
    # Set permissions on scripts
    chmod 755 "$PROJECT_DIR/scripts/"*.sh
    
    # Set permissions on logs directory
    chmod 755 "$PROJECT_DIR/logs"
    chmod 644 "$PROJECT_DIR/logs/"*.log 2>/dev/null || true
    
    # Set ownership
    chown -R dev:dev "$PROJECT_DIR"
    chown -R dev:docker "$PROJECT_DIR/config"
    
    log "File permissions hardened"
}

configure_docker_security() {
    log "Configuring Docker security..."
    
    # Create Docker daemon configuration for security
    local docker_config="/etc/docker/daemon.json"
    
    if [[ ! -f "$docker_config" ]]; then
        sudo tee "$docker_config" > /dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "userland-proxy": false,
    "no-new-privileges": true,
    "seccomp-profile": "/etc/docker/seccomp-profile.json",
    "experimental": false,
    "live-restore": true
}
EOF
    fi
    
    # Create seccomp profile for containers
    local seccomp_profile="/etc/docker/seccomp-profile.json"
    
    if [[ ! -f "$seccomp_profile" ]]; then
        sudo tee "$seccomp_profile" > /dev/null <<EOF
{
    "defaultAction": "SCMP_ACT_ERRNO",
    "architectures": [
        "SCMP_ARCH_X86_64"
    ],
    "syscalls": [
        {
            "names": [
                "read",
                "write",
                "open",
                "close",
                "stat",
                "fstat",
                "lstat",
                "mmap",
                "mprotect",
                "munmap",
                "brk",
                "execve",
                "exit_group",
                "getpid",
                "getuid",
                "getgid",
                "geteuid",
                "getegid"
            ],
            "action": "SCMP_ACT_ALLOW"
        }
    ]
}
EOF
    fi
    
    log "Docker security configured"
}

setup_network_security() {
    log "Setting up network security..."
    
    # Configure iptables rules for container network
    sudo iptables -I DOCKER-USER -i docker0 -s 172.20.0.0/16 -d 192.168.1.0/24 -j ACCEPT
    sudo iptables -I DOCKER-USER -i docker0 -s 172.20.0.0/16 -d 0.0.0.0/0 -j DROP
    
    # Allow specific outbound connections
    sudo iptables -I DOCKER-USER -i docker0 -s 172.20.0.0/16 -d 8.8.8.8 -p tcp --dport 53 -j ACCEPT
    sudo iptables -I DOCKER-USER -i docker0 -s 172.20.0.0/16 -d 8.8.8.8 -p udp --dport 53 -j ACCEPT
    sudo iptables -I DOCKER-USER -i docker0 -s 172.20.0.0/16 -d 0.0.0.0/0 -p tcp --dport 443 -j ACCEPT
    sudo iptables -I DOCKER-USER -i docker0 -s 172.20.0.0/16 -d 0.0.0.0/0 -p tcp --dport 80 -j ACCEPT
    
    # Save iptables rules
    sudo iptables-save > /etc/iptables/rules.v4
    
    log "Network security configured"
}

configure_logging_security() {
    log "Configuring logging security..."
    
    # Set up log rotation
    local logrotate_config="/etc/logrotate.d/github-actions-runner"
    
    sudo tee "$logrotate_config" > /dev/null <<EOF
$PROJECT_DIR/logs/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 644 dev dev
    postrotate
        /usr/bin/docker-compose -f $PROJECT_DIR/docker-compose.yml restart log-aggregator
    endscript
}
EOF
    
    # Configure rsyslog for security events
    local rsyslog_config="/etc/rsyslog.d/50-github-runner.conf"
    
    sudo tee "$rsyslog_config" > /dev/null <<EOF
# GitHub Actions Runner security logging
local0.*    $PROJECT_DIR/logs/security.log
& stop
EOF
    
    sudo systemctl restart rsyslog
    
    log "Logging security configured"
}

setup_monitoring_security() {
    log "Setting up monitoring security..."
    
    # Create monitoring user with limited privileges
    if ! id -u monitoring >/dev/null 2>&1; then
        sudo useradd -r -s /bin/false -d /nonexistent monitoring
    fi
    
    # Configure fail2ban for runner protection
    local fail2ban_config="/etc/fail2ban/jail.d/github-runner.conf"
    
    sudo tee "$fail2ban_config" > /dev/null <<EOF
[github-runner]
enabled = true
port = 8080
filter = github-runner
logpath = $PROJECT_DIR/logs/security.log
maxretry = 5
bantime = 3600
findtime = 600
EOF
    
    # Create fail2ban filter
    local fail2ban_filter="/etc/fail2ban/filter.d/github-runner.conf"
    
    sudo tee "$fail2ban_filter" > /dev/null <<EOF
[Definition]
failregex = ^.*\[.*\] ERROR: Unauthorized access attempt from <HOST>.*$
            ^.*\[.*\] ERROR: Authentication failed for <HOST>.*$
            ^.*\[.*\] ERROR: Rate limit exceeded for <HOST>.*$
ignoreregex =
EOF
    
    sudo systemctl restart fail2ban
    
    log "Monitoring security configured"
}

create_security_audit_script() {
    log "Creating security audit script..."
    
    local audit_script="$PROJECT_DIR/scripts/security-audit.sh"
    
    cat > "$audit_script" <<'EOF'
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/security-audit.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

audit_file_permissions() {
    log "Auditing file permissions..."
    
    # Check configuration files
    local config_perms=$(stat -c "%a" "$PROJECT_DIR/config/runner.env")
    if [[ "$config_perms" != "600" ]]; then
        log "WARNING: runner.env permissions are $config_perms, should be 600"
    fi
    
    # Check script permissions
    for script in "$PROJECT_DIR/scripts/"*.sh; do
        local script_perms=$(stat -c "%a" "$script")
        if [[ "$script_perms" != "755" ]]; then
            log "WARNING: $script permissions are $script_perms, should be 755"
        fi
    done
    
    log "File permissions audit completed"
}

audit_container_security() {
    log "Auditing container security..."
    
    # Check if containers are running with correct security settings
    local runner_security=$(docker inspect github-actions-runner --format '{{.HostConfig.SecurityOpt}}')
    if [[ "$runner_security" != *"no-new-privileges"* ]]; then
        log "WARNING: Runner container not using no-new-privileges"
    fi
    
    # Check for privileged containers
    local privileged=$(docker inspect github-actions-runner --format '{{.HostConfig.Privileged}}')
    if [[ "$privileged" == "true" ]]; then
        log "WARNING: Runner container is running in privileged mode"
    fi
    
    log "Container security audit completed"
}

audit_network_security() {
    log "Auditing network security..."
    
    # Check iptables rules
    if ! sudo iptables -L DOCKER-USER | grep -q "172.20.0.0/16"; then
        log "WARNING: Docker network isolation rules not found"
    fi
    
    # Check for exposed ports
    local exposed_ports=$(docker ps --format "table {{.Ports}}" | grep -v "PORTS" | grep "0.0.0.0" || true)
    if [[ -n "$exposed_ports" ]]; then
        log "WARNING: Containers have exposed ports: $exposed_ports"
    fi
    
    log "Network security audit completed"
}

main() {
    log "Starting security audit..."
    
    audit_file_permissions
    audit_container_security
    audit_network_security
    
    log "Security audit completed"
}

main "$@"
EOF
    
    chmod 755 "$audit_script"
    
    log "Security audit script created"
}

setup_automatic_security_updates() {
    log "Setting up automatic security updates..."
    
    # Configure unattended-upgrades
    sudo apt-get install -y unattended-upgrades
    
    local unattended_config="/etc/apt/apt.conf.d/50unattended-upgrades"
    
    sudo tee "$unattended_config" > /dev/null <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}:\${distro_codename}-updates";
};

Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF
    
    # Enable automatic updates
    sudo systemctl enable unattended-upgrades
    sudo systemctl start unattended-upgrades
    
    log "Automatic security updates configured"
}

main() {
    log "Starting security hardening..."
    
    harden_file_permissions
    configure_docker_security
    setup_network_security
    configure_logging_security
    setup_monitoring_security
    create_security_audit_script
    setup_automatic_security_updates
    
    log "Security hardening completed"
    log "Run $PROJECT_DIR/scripts/security-audit.sh to perform security audit"
}

main "$@"