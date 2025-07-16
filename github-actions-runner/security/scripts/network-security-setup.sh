#!/bin/bash
# Network Security Setup Script
# Configures firewall rules and network isolation for GitHub Actions runner

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${SECURITY_DIR}/config/network-security.yml"
LOG_FILE="/var/log/network-security-setup.log"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root for firewall configuration"
    fi
}

# Install required packages
install_dependencies() {
    log "${YELLOW}Installing network security dependencies...${NC}"
    
    # Update package list
    apt-get update
    
    # Install required packages
    local packages=(
        "iptables"
        "iptables-persistent"
        "ufw"
        "fail2ban"
        "netfilter-persistent"
        "conntrack"
        "tcpdump"
        "wireshark-common"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  ${package} "; then
            log "Installing ${package}..."
            apt-get install -y "${package}"
        else
            log "${package} already installed"
        fi
    done
    
    log "${GREEN}Dependencies installed successfully${NC}"
}

# Configure iptables rules
setup_iptables() {
    log "${YELLOW}Configuring iptables firewall rules...${NC}"
    
    # Save current rules
    iptables-save > /etc/iptables/rules.v4.backup."$(date +%Y%m%d_%H%M%S)"
    
    # Flush existing rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    # Set default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback traffic
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow established and related connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSH (for management)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Docker-specific rules for GitHub runner network
    # Allow communication within runner network
    iptables -A FORWARD -s 172.20.0.0/24 -d 172.20.0.0/24 -j DROP  # Block inter-container communication
    
    # Allow outbound GitHub API access
    iptables -A FORWARD -s 172.20.0.0/24 -p tcp --dport 443 -d 140.82.112.0/20 -j ACCEPT    # GitHub API
    iptables -A FORWARD -s 172.20.0.0/24 -p tcp --dport 443 -d 140.82.113.0/20 -j ACCEPT    # GitHub API
    iptables -A FORWARD -s 172.20.0.0/24 -p tcp --dport 22 -d 140.82.112.0/20 -j ACCEPT     # GitHub SSH
    iptables -A FORWARD -s 172.20.0.0/24 -p tcp --dport 9418 -d 140.82.112.0/20 -j ACCEPT   # GitHub Git
    
    # Allow DNS resolution
    iptables -A FORWARD -s 172.20.0.0/24 -p udp --dport 53 -j ACCEPT
    iptables -A FORWARD -s 172.20.0.0/24 -p tcp --dport 53 -j ACCEPT
    
    # Allow NTP
    iptables -A FORWARD -s 172.20.0.0/24 -p udp --dport 123 -j ACCEPT
    
    # Block access to metadata services
    iptables -A FORWARD -s 172.20.0.0/24 -d 169.254.169.254 -j DROP
    iptables -A FORWARD -s 172.20.0.0/24 -d 169.254.0.0/16 -j DROP
    
    # Block access to private networks
    iptables -A FORWARD -s 172.20.0.0/24 -d 10.0.0.0/8 -j DROP
    iptables -A FORWARD -s 172.20.0.0/24 -d 172.16.0.0/12 ! -d 172.20.0.0/24 ! -d 172.21.0.0/24 -j DROP
    iptables -A FORWARD -s 172.20.0.0/24 -d 192.168.0.0/16 -j DROP
    
    # Rate limiting for security
    iptables -A FORWARD -s 172.20.0.0/24 -m limit --limit 100/min --limit-burst 200 -j ACCEPT
    
    # Logging rules for monitoring
    iptables -A INPUT -j LOG --log-prefix "RUNNER-INPUT-DROP: " --log-level 4
    iptables -A FORWARD -j LOG --log-prefix "RUNNER-FORWARD-DROP: " --log-level 4
    
    # Save rules
    netfilter-persistent save
    
    log "${GREEN}iptables rules configured successfully${NC}"
}

# Configure UFW for additional security
setup_ufw() {
    log "${YELLOW}Configuring UFW (Uncomplicated Firewall)...${NC}"
    
    # Reset UFW
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default deny outgoing
    ufw default deny forward
    
    # Allow SSH
    ufw allow 22/tcp
    
    # Allow Docker management
    ufw allow from 172.17.0.0/16
    ufw allow from 172.20.0.0/24
    ufw allow from 172.21.0.0/24
    
    # Enable UFW
    ufw --force enable
    
    log "${GREEN}UFW configured successfully${NC}"
}

# Configure fail2ban
setup_fail2ban() {
    log "${YELLOW}Configuring fail2ban...${NC}"
    
    # Create custom jail for Docker networks
    cat > /etc/fail2ban/jail.d/docker-security.conf << 'EOF'
[docker-runner]
enabled = true
port = all
filter = docker-runner
logpath = /var/log/docker-runner-security.log
maxretry = 5
bantime = 3600
findtime = 600

[ssh-docker]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

    # Create custom filter for docker runner
    cat > /etc/fail2ban/filter.d/docker-runner.conf << 'EOF'
[Definition]
failregex = ^.*RUNNER-.*-DROP:.* SRC=<HOST> DST=.*$
            ^.*SECURITY VIOLATION:.* from <HOST>.*$
            ^.*Suspicious activity detected from <HOST>.*$
ignoreregex =
EOF

    # Restart fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "${GREEN}fail2ban configured successfully${NC}"
}

# Create Docker network with security settings
create_docker_networks() {
    log "${YELLOW}Creating secure Docker networks...${NC}"
    
    # Remove existing networks if they exist
    docker network rm github-runner-net 2>/dev/null || true
    docker network rm monitoring-net 2>/dev/null || true
    
    # Create GitHub runner network with security settings
    docker network create \
        --driver bridge \
        --subnet=172.20.0.0/24 \
        --gateway=172.20.0.1 \
        --opt com.docker.network.bridge.name=github-runner-br \
        --opt com.docker.network.bridge.enable_icc=false \
        --opt com.docker.network.bridge.enable_ip_masquerade=true \
        --opt com.docker.network.driver.mtu=1500 \
        --label security.isolation=high \
        --label network.type=runner \
        github-runner-net
    
    # Create monitoring network
    docker network create \
        --driver bridge \
        --subnet=172.21.0.0/24 \
        --gateway=172.21.0.1 \
        --opt com.docker.network.bridge.name=monitoring-br \
        --opt com.docker.network.bridge.enable_icc=true \
        --label security.isolation=medium \
        --label network.type=monitoring \
        monitoring-net
    
    log "${GREEN}Docker networks created successfully${NC}"
}

# Setup network monitoring
setup_network_monitoring() {
    log "${YELLOW}Setting up network monitoring...${NC}"
    
    # Create monitoring script
    cat > /usr/local/bin/network-security-monitor.sh << 'EOF'
#!/bin/bash
# Network Security Monitoring Script

LOGFILE="/var/log/network-security-monitor.log"
ALERT_THRESHOLD=100

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOGFILE}"
}

# Monitor connection count
check_connections() {
    local conn_count=$(netstat -an | grep ESTABLISHED | wc -l)
    if [[ ${conn_count} -gt ${ALERT_THRESHOLD} ]]; then
        log "ALERT: High connection count: ${conn_count}"
        # Send alert (implement webhook/email here)
    fi
}

# Monitor suspicious network activity
check_suspicious_activity() {
    # Check for port scans
    local port_scans=$(grep "RUNNER-.*-DROP" /var/log/kern.log | tail -100 | wc -l)
    if [[ ${port_scans} -gt 10 ]]; then
        log "ALERT: Potential port scan detected: ${port_scans} dropped packets"
    fi
    
    # Check for unusual destinations
    netstat -rn | grep -E "(169\.254\.|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168\.)" | while read line; do
        log "WARNING: Connection to private network detected: ${line}"
    done
}

# Main monitoring loop
while true; do
    check_connections
    check_suspicious_activity
    sleep 60
done
EOF

    chmod +x /usr/local/bin/network-security-monitor.sh
    
    # Create systemd service for network monitoring
    cat > /etc/systemd/system/network-security-monitor.service << 'EOF'
[Unit]
Description=Network Security Monitor for GitHub Actions Runner
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/network-security-monitor.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable network-security-monitor.service
    systemctl start network-security-monitor.service
    
    log "${GREEN}Network monitoring configured successfully${NC}"
}

# Validate network security configuration
validate_network_security() {
    log "${YELLOW}Validating network security configuration...${NC}"
    
    local validation_errors=0
    
    # Check iptables rules
    if ! iptables -L -n | grep -q "DROP"; then
        log "${RED}ERROR: iptables DROP rules not found${NC}"
        ((validation_errors++))
    fi
    
    # Check Docker networks
    if ! docker network ls | grep -q "github-runner-net"; then
        log "${RED}ERROR: github-runner-net network not found${NC}"
        ((validation_errors++))
    fi
    
    # Check fail2ban status
    if ! systemctl is-active --quiet fail2ban; then
        log "${RED}ERROR: fail2ban service is not running${NC}"
        ((validation_errors++))
    fi
    
    # Check UFW status
    if ! ufw status | grep -q "Status: active"; then
        log "${RED}ERROR: UFW is not active${NC}"
        ((validation_errors++))
    fi
    
    # Check network monitoring service
    if ! systemctl is-active --quiet network-security-monitor; then
        log "${RED}ERROR: Network security monitor is not running${NC}"
        ((validation_errors++))
    fi
    
    if [[ ${validation_errors} -eq 0 ]]; then
        log "${GREEN}Network security validation passed${NC}"
        return 0
    else
        log "${RED}Network security validation failed with ${validation_errors} errors${NC}"
        return 1
    fi
}

# Main setup function
main() {
    log "${GREEN}Starting network security setup for GitHub Actions runner${NC}"
    
    check_root
    install_dependencies
    setup_iptables
    setup_ufw
    setup_fail2ban
    create_docker_networks
    setup_network_monitoring
    
    if validate_network_security; then
        log "${GREEN}Network security setup completed successfully${NC}"
        log "Next steps:"
        log "1. Review firewall rules: iptables -L -n"
        log "2. Check UFW status: ufw status verbose"
        log "3. Monitor fail2ban: fail2ban-client status"
        log "4. Check network monitoring: systemctl status network-security-monitor"
    else
        error_exit "Network security setup validation failed"
    fi
}

# Execute main function
main "$@"