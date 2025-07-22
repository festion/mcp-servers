# Prompt 06: Security Hardening Implementation

## Task
Implement comprehensive security hardening for the GitHub Actions runner deployment with container isolation, network security, and access controls.

## Context
- Production deployment requires security best practices
- Container isolation and network security critical
- Integration with existing homelab security infrastructure
- Protection against common attack vectors

## Requirements
Create security implementation in `/home/dev/workspace/github-actions-runner/`:

1. **Container Security**
   - Non-root user execution
   - Minimal base image selection
   - Capability dropping and seccomp profiles
   - Read-only filesystem where possible
   - Resource limits and quotas

2. **Network Security**
   - Network segmentation and isolation
   - Firewall rules and port restrictions
   - SSL/TLS certificate management
   - VPN or secure tunnel configuration
   - Network monitoring and intrusion detection

3. **Access Control**
   - GitHub token security and rotation
   - SSH key management for deployments
   - Role-based access control
   - Audit logging and monitoring
   - Multi-factor authentication where applicable

4. **Secret Management**
   - Encrypted secret storage
   - Secret rotation procedures
   - Environment variable security
   - Backup encryption and security
   - Key management best practices

5. **Monitoring and Compliance**
   - Security event logging
   - Compliance checking automation
   - Vulnerability scanning
   - Security incident response procedures
   - Regular security audits

## Deliverables
- Complete security configuration
- Security hardening scripts
- Access control implementation
- Secret management system
- Security monitoring configuration
- Compliance documentation

## Success Criteria
- All containers run with minimal privileges
- Network access is properly restricted
- Secrets are encrypted and rotated
- Security events are logged and monitored
- System passes security audit requirements