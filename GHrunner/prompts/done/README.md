# GitHub Self-Hosted Runner Implementation
## Fault-Tolerant & Stable Configuration for Home Assistant CI/CD

### Overview
This project implements a production-ready GitHub Actions self-hosted runner to resolve CI/CD deployment issues caused by GitHub's hosted runners being unable to access private network infrastructure (specifically `192.168.1.155`).

### Problem Statement
- GitHub Actions hosted runners cannot reach private IP addresses
- Home Assistant CI/CD pipeline failing at SSH connection step
- Need for reliable, fault-tolerant deployment automation

### Architecture Decision
- **Container Strategy**: Dedicated container for production stability
- **Repository Strategy**: New repository `homelab-github-runner` for focused management
- **Location**: `/home/dev/workspace/github-actions-runner/`

### Key Features
- **Fault Tolerance**: Multi-layer health monitoring and auto-recovery
- **Security**: Container isolation, network security, secure token management
- **Monitoring**: Integration with homelab-gitops-auditor infrastructure
- **Stability**: Dedicated resources, proper service management, comprehensive logging

### Documentation Structure
- [`ARCHITECTURE.md`](ARCHITECTURE.md) - Technical architecture and design decisions
- [`INSTALLATION.md`](INSTALLATION.md) - Step-by-step installation guide
- [`CONFIGURATION.md`](CONFIGURATION.md) - Configuration options and settings
- [`MONITORING.md`](MONITORING.md) - Health monitoring and alerting setup
- [`SECURITY.md`](SECURITY.md) - Security hardening and best practices
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Common issues and solutions
- [`MAINTENANCE.md`](MAINTENANCE.md) - Ongoing maintenance procedures

### Quick Start
1. Follow the [Installation Guide](INSTALLATION.md)
2. Configure the runner using [Configuration Guide](CONFIGURATION.md)
3. Set up monitoring per [Monitoring Guide](MONITORING.md)
4. Implement security hardening from [Security Guide](SECURITY.md)

### Repository Structure
```
/home/dev/workspace/github-actions-runner/
├── README.md                 # This file
├── ARCHITECTURE.md           # Technical architecture
├── INSTALLATION.md           # Installation guide
├── CONFIGURATION.md          # Configuration guide
├── MONITORING.md             # Monitoring setup
├── SECURITY.md               # Security hardening
├── TROUBLESHOOTING.md        # Troubleshooting guide
├── MAINTENANCE.md            # Maintenance procedures
├── docker-compose.yml        # Container orchestration
├── config/                   # Configuration files
│   ├── runner.env           # Environment variables
│   ├── systemd/             # Service files
│   └── nginx/               # Reverse proxy config
├── scripts/                  # Management scripts
│   ├── setup.sh             # Initial setup
│   ├── health-check.sh      # Health monitoring
│   ├── backup.sh            # Backup procedures
│   └── update.sh            # Update management
├── monitoring/               # Monitoring configuration
│   ├── prometheus.yml       # Metrics collection
│   ├── grafana/             # Dashboards
│   └── alerting/            # Alert rules
└── logs/                     # Log files
    ├── runner.log           # Runner logs
    ├── health.log           # Health check logs
    └── security.log         # Security events
```

### Prerequisites
- Docker and Docker Compose installed
- Access to GitHub repository with admin permissions
- Network connectivity to `192.168.1.155`
- Sufficient system resources (2GB RAM, 20GB storage minimum)

### Support
For issues and questions:
1. Check [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review logs in `/logs/` directory
3. Consult monitoring dashboards
4. Create issue in repository

### Contributing
1. Follow security best practices
2. Update documentation for any changes
3. Test thoroughly before deployment
4. Maintain backward compatibility

### License
Internal homelab infrastructure - Not for external distribution