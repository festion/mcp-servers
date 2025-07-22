# GitHub Actions Runner Security Hardening

This directory contains a comprehensive security hardening implementation for GitHub Actions runners, designed to provide enterprise-grade security through multiple layers of protection.

## 🛡️ Security Components

### 1. Container Security Hardening
- **Non-root execution**: Runs as dedicated user (UID 1001)
- **Minimal base image**: Ubuntu 22.04-minimal with essential packages only
- **Capability restrictions**: Drops ALL capabilities, adds only essential ones
- **Seccomp profile**: Custom security profile restricting system calls
- **Read-only filesystem**: Immutable root filesystem with tmpfs mounts
- **Resource limits**: CPU, memory, and process limits

### 2. Network Security & Isolation
- **Custom bridge networks**: Isolated container networking
- **Firewall rules**: iptables-based access control
- **Intrusion detection**: fail2ban with custom rules
- **Traffic monitoring**: Real-time network activity monitoring
- **DNS security**: Secure DNS resolution with filtering

### 3. Access Control & Authentication
- **User management**: Dedicated runner user with minimal privileges
- **SSH security**: Ed25519 keys with secure configuration
- **Sudo restrictions**: Limited, audited sudo access
- **Audit logging**: Comprehensive access audit trail
- **PAM configuration**: Enhanced authentication policies

### 4. Secret Management System
- **Encryption**: AES-256-GCM with scrypt key derivation
- **Secure storage**: Encrypted file-based secret storage
- **Access control**: Audited secret access patterns
- **Rotation policies**: Automated and manual rotation procedures
- **Backup encryption**: Secure backup with separate encryption

### 5. Security Monitoring & Compliance
- **Real-time monitoring**: Continuous security event monitoring
- **CIS compliance**: Docker Benchmark Level 1 compliance
- **Vulnerability scanning**: Container and dependency scanning
- **Incident response**: Automated response procedures
- **Compliance reporting**: Regular security posture reports

## 📁 Directory Structure

```
security/
├── config/                          # Security configuration files
│   ├── access-control.yml            # Access control policies
│   ├── monitoring-compliance.yml     # Monitoring configuration
│   ├── network-security.yml          # Network security policies
│   ├── secret-management.yml         # Secret management configuration
│   ├── security-policy.yml           # Main security policy
│   └── seccomp-profile.json          # Container seccomp profile
├── scripts/                          # Security management scripts
│   ├── access-control-setup.sh       # Access control configuration
│   ├── container-security-check.sh   # Container security validation
│   ├── entrypoint-security.sh        # Secure container entrypoint
│   ├── network-security-setup.sh     # Network security configuration
│   ├── secret-manager.sh             # Secret management tool
│   ├── security-hardening-master.sh  # Master hardening script
│   └── security-monitor.sh           # Security monitoring daemon
├── Dockerfile.hardened               # Security-hardened container image
└── README.md                         # This documentation
```

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04+ or similar Linux distribution
- Root access for system-level configuration
- Docker engine
- Basic networking tools (iptables, fail2ban)

### Complete Security Hardening

1. **Run the master hardening script**:
   ```bash
   sudo ./security/scripts/security-hardening-master.sh
   ```

2. **Configure secrets**:
   ```bash
   # Initialize secret management
   sudo -u runner ./security/scripts/secret-manager.sh init
   
   # Store GitHub token
   sudo -u runner ./security/scripts/secret-manager.sh store github_token "ghp_your_token_here"
   ```

3. **Deploy hardened runner**:
   ```bash
   # Set environment variables
   export RUNNER_NAME="github-runner-hardened"
   export RUNNER_URL="https://github.com/your-org/your-repo"
   export RUNNER_TOKEN="$(sudo -u runner ./security/scripts/secret-manager.sh get github_token)"
   
   # Deploy using hardened configuration
   docker-compose -f docker-compose.hardened.yml up -d
   ```

4. **Monitor security status**:
   ```bash
   # Check security monitoring service
   sudo systemctl status github-runner-security-monitor
   
   # View security alerts
   sudo tail -f /var/log/security-alerts.log
   
   # Run manual security check
   sudo ./security/scripts/security-monitor.sh check
   ```

## 🔧 Component Setup

### Container Security Only
```bash
sudo ./security/scripts/security-hardening-master.sh container-only
```

### Network Security Only
```bash
sudo ./security/scripts/security-hardening-master.sh network-only
```

### Access Control Only
```bash
sudo ./security/scripts/security-hardening-master.sh access-only
```

### Secret Management Only
```bash
sudo ./security/scripts/security-hardening-master.sh secrets-only
```

### Monitoring & Compliance Only
```bash
sudo ./security/scripts/security-hardening-master.sh monitoring-only
```

## 🔑 Secret Management

### Initialize Secret Store
```bash
sudo -u runner ./security/scripts/secret-manager.sh init
```

### Store Secrets
```bash
# GitHub token
sudo -u runner ./security/scripts/secret-manager.sh store github_token "ghp_..."

# SSH private key
sudo -u runner ./security/scripts/secret-manager.sh store ssh_private_key "$(cat ~/.ssh/id_ed25519)"

# Docker registry credentials
sudo -u runner ./security/scripts/secret-manager.sh store docker_credentials "username:password"
```

### Retrieve Secrets
```bash
# Get GitHub token
sudo -u runner ./security/scripts/secret-manager.sh get github_token

# List all secrets
sudo -u runner ./security/scripts/secret-manager.sh list
```

### Rotate Secrets
```bash
# Rotate specific secret
sudo -u runner ./security/scripts/secret-manager.sh rotate github_token

# Backup all secrets
sudo -u runner ./security/scripts/secret-manager.sh backup
```

## 📊 Security Monitoring

### Start/Stop Monitoring
```bash
# Start security monitoring
sudo ./security/scripts/security-monitor.sh start

# Stop security monitoring
sudo ./security/scripts/security-monitor.sh stop

# Check status
sudo ./security/scripts/security-monitor.sh status
```

### Security Checks
```bash
# Run immediate security check
sudo ./security/scripts/security-monitor.sh check

# Run compliance check
sudo ./security/scripts/security-monitor.sh compliance

# View recent alerts
sudo ./security/scripts/security-monitor.sh logs
```

### Monitoring Integration
Set up webhook notifications for security alerts:
```bash
export SECURITY_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

## 🔍 Compliance & Auditing

### CIS Docker Benchmark
The implementation follows CIS Docker Benchmark v1.6.0 Level 1 requirements:

- ✅ **2.1**: Network traffic restricted between containers
- ✅ **2.5**: AUFS storage driver avoided
- ✅ **4.1**: Non-root user for containers
- ✅ **5.3**: Linux kernel capabilities restricted
- ✅ **5.7**: Privileged ports not mapped
- ✅ **5.9**: Host network namespace not shared
- ✅ **5.10**: Memory usage limited
- ✅ **5.11**: CPU priority set appropriately
- ✅ **5.25**: Container restart policies configured

### Audit Logs
Security events are logged to:
- `/var/log/audit/audit.log` - System audit events
- `/var/log/security-alerts.log` - Security alert events
- `/var/log/runner-audit/` - Runner-specific audit logs
- `/home/runner/.secrets/audit.log` - Secret access audit

### Compliance Reports
Generate compliance reports:
```bash
sudo ./security/scripts/security-monitor.sh compliance
```

## 🚨 Incident Response

### Alert Severity Levels

- **Critical**: Immediate threat (response: 15 minutes)
  - Active security breach
  - Malware detected
  - Data exfiltration in progress

- **High**: Significant concern (response: 1 hour)
  - Failed intrusion attempt
  - Privilege escalation detected
  - Suspicious network activity

- **Medium**: Requires investigation (response: 4 hours)
  - Multiple failed login attempts
  - Configuration drift detected
  - Policy violation

- **Low**: Informational (response: 24 hours)
  - Routine security alert
  - Maintenance activity
  - User access request

### Response Procedures

1. **Immediate Response**
   - Isolate affected systems
   - Preserve evidence
   - Assess scope and impact
   - Notify stakeholders

2. **Investigation**
   - Collect forensic evidence
   - Analyze attack vectors
   - Identify root cause
   - Document findings

3. **Containment**
   - Implement containment measures
   - Patch vulnerabilities
   - Update security controls
   - Monitor for persistence

4. **Recovery**
   - Restore affected systems
   - Validate system integrity
   - Implement additional controls
   - Monitor for recurrence

## 🔧 Configuration

### Environment Variables
```bash
# Security webhook for alerts
export SECURITY_WEBHOOK_URL="https://hooks.slack.com/services/..."

# GitHub configuration
export RUNNER_NAME="github-runner-hardened"
export RUNNER_URL="https://github.com/your-org/your-repo"
export RUNNER_TOKEN="your-runner-token"

# Security settings
export SECURITY_LOG_LEVEL="info"
export ENABLE_VULNERABILITY_SCANNING="true"
export COMPLIANCE_FRAMEWORK="cis_docker"
```

### Custom Configuration
Modify security policies in:
- `config/security-policy.yml` - Main security configuration
- `config/network-security.yml` - Network policies
- `config/access-control.yml` - Access control policies
- `config/secret-management.yml` - Secret management settings
- `config/monitoring-compliance.yml` - Monitoring configuration

## 🐛 Troubleshooting

### Common Issues

1. **Container won't start as non-root**
   ```bash
   # Check user creation
   docker exec -it github-runner id
   
   # Verify file permissions
   docker exec -it github-runner ls -la /home/runner/
   ```

2. **Network connectivity issues**
   ```bash
   # Check iptables rules
   sudo iptables -L -n
   
   # Verify Docker networks
   docker network ls
   docker network inspect github-runner-net
   ```

3. **Secret access denied**
   ```bash
   # Check secret directory permissions
   ls -la /home/runner/.secrets/
   
   # Verify secret manager initialization
   sudo -u runner ./security/scripts/secret-manager.sh validate
   ```

4. **Monitoring service not starting**
   ```bash
   # Check service status
   sudo systemctl status github-runner-security-monitor
   
   # View service logs
   sudo journalctl -u github-runner-security-monitor -f
   ```

### Log Files
- `/var/log/security-hardening-master.log` - Master script execution
- `/var/log/network-security-setup.log` - Network configuration
- `/var/log/access-control-setup.log` - Access control setup
- `/var/log/secret-manager.log` - Secret management operations
- `/var/log/security-monitor.log` - Security monitoring daemon
- `/var/log/security-alerts.log` - Security alert events

### Validation Commands
```bash
# Validate complete security configuration
sudo ./security/scripts/security-hardening-master.sh validate

# Check individual components
sudo ./security/scripts/container-security-check.sh
sudo ./security/scripts/security-monitor.sh check
sudo -u runner ./security/scripts/secret-manager.sh validate
```

## 📚 Additional Resources

### Security Standards
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)

### Documentation
- [Security Architecture Design](../ARCHITECTURE.md)
- [Installation Guide](../INSTALLATION.md)
- [Monitoring Setup](../monitoring/README.md)
- [Backup Procedures](../backups/README.md)

## 🤝 Contributing

When contributing to security components:

1. Follow security-first design principles
2. Document all security implications
3. Include comprehensive tests
4. Update compliance mappings
5. Provide clear security justification

## 📜 License

This security implementation is provided as-is for educational and defensive security purposes only. Use responsibly and in accordance with applicable laws and regulations.

---

**⚠️ Security Notice**: This implementation provides strong security controls but requires proper configuration and ongoing maintenance. Regular security audits and updates are recommended.