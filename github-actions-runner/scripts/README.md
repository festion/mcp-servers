# GitHub Actions Runner Management Scripts

This directory contains comprehensive management scripts for deploying, operating, and maintaining GitHub Actions self-hosted runners in a production environment.

## Overview

The management scripts provide a complete automation framework for:
- **Setup and Deployment**: Automated installation and configuration
- **Operational Management**: Service lifecycle management (start, stop, restart, status)
- **Health and Monitoring**: Continuous monitoring, alerting, and diagnostics
- **Backup and Recovery**: Data protection and disaster recovery
- **Maintenance**: Routine maintenance, cleanup, and optimization

## Quick Start

1. **Initial Setup**:
   ```bash
   sudo ./setup-comprehensive.sh --environment prod --repo owner/repo --token ghp_xxx
   ```

2. **Deploy Runner**:
   ```bash
   ./deploy-enhanced.sh --environment prod
   ```

3. **Check Status**:
   ```bash
   ./status.sh
   ```

4. **Monitor Health**:
   ```bash
   ./monitor.sh start
   ```

## Script Categories

### 1. Setup and Deployment

#### `setup-comprehensive.sh`
Complete environment setup and runner installation.

**Usage**:
```bash
./setup-comprehensive.sh [OPTIONS]

Options:
  -e, --environment ENV   Environment (dev|staging|prod)
  -r, --repo REPO         GitHub repository (owner/repo)
  -t, --token TOKEN       GitHub runner registration token
  -u, --user USER         User to run services as
  -p, --path PATH         Installation path
  --skip-deps             Skip dependency installation
  --skip-docker           Skip Docker setup
  --skip-monitoring       Skip monitoring setup
```

**Features**:
- System dependency installation
- User and directory setup
- Docker configuration
- Runner download and configuration
- Systemd service creation
- Security hardening
- Monitoring setup

#### `deploy-enhanced.sh`
Production deployment with validation and rollback capability.

**Usage**:
```bash
./deploy-enhanced.sh [OPTIONS]

Options:
  -e, --environment ENV   Environment (dev|staging|prod)
  -c, --config-file FILE  Configuration file path
  --skip-backup           Skip initial backup creation
  --skip-health-check     Skip health checks
  --force                 Force deployment even if issues detected
```

**Features**:
- Pre-deployment validation
- Automatic backup creation
- Service management
- Health verification
- Rollback on failure

### 2. Operational Management

#### `start.sh`
Start GitHub Actions runner services with validation.

**Usage**:
```bash
./start.sh [OPTIONS]

Options:
  -s, --service-only      Start only systemd service
  -d, --docker-only       Start only Docker containers
  -w, --wait SECONDS      Wait timeout for service startup
  -f, --force             Force start even if already running
```

#### `stop.sh`
Gracefully stop runner services with job draining.

**Usage**:
```bash
./stop.sh [OPTIONS]

Options:
  -s, --service-only      Stop only systemd service
  -d, --docker-only       Stop only Docker containers
  -w, --wait SECONDS      Wait timeout for graceful shutdown
  -f, --force             Force stop if graceful fails
  -k, --kill              Immediate kill (no graceful stop)
  --drain                 Wait for current jobs to finish
```

#### `restart.sh`
Restart services with comprehensive validation.

**Usage**:
```bash
./restart.sh [OPTIONS]

Options:
  -f, --force             Force restart
  --drain                 Drain jobs before stopping
  --health-check          Run health check after restart
  --update                Pull latest images/updates before restart
```

#### `status.sh`
Display comprehensive status information.

**Usage**:
```bash
./status.sh [OPTIONS]

Options:
  -j, --json              JSON output format
  -s, --summary           Show summary only
  -d, --detailed          Show detailed information
  -w, --watch             Watch mode (refresh every N seconds)
```

### 3. Health and Monitoring

#### `monitor.sh`
Continuous monitoring with alerting.

**Usage**:
```bash
./monitor.sh [OPTIONS] COMMAND

Commands:
  check                   Run monitoring checks once
  start                   Start continuous monitoring
  stop                    Stop continuous monitoring
  status                  Show monitoring status
  alerts                  Check and process alerts
  report                  Generate monitoring report

Options:
  -i, --interval SECONDS  Monitoring interval
  --alert-threshold TYPE  Set alert thresholds (disk:90,memory:85,cpu:90)
  --webhook-url URL       Webhook URL for notifications
  --email EMAIL           Email address for alerts
```

#### `alerts.sh`
Alert management and notification system.

**Usage**:
```bash
./alerts.sh [OPTIONS] COMMAND

Commands:
  check                   Check for active alerts
  clear                   Clear all alerts
  clear-by-id ID          Clear specific alert by ID
  send                    Send test notification
  configure               Configure alert settings
  history                 Show alert history
  summary                 Show alert summary

Options:
  --webhook-url URL       Webhook URL for notifications
  --email EMAIL           Email address for alerts
  --severity LEVEL        Filter by severity (info|warning|critical)
  --category TYPE         Filter by category (service|resources|network)
  --since DURATION        Show alerts since duration (1h, 1d, 1w)
```

#### `diagnostics.sh`
Comprehensive diagnostic information collection.

**Usage**:
```bash
./diagnostics.sh [OPTIONS] [COMMAND]

Commands:
  collect                 Collect all diagnostic information
  system                  System information only
  service                 Service status and logs
  network                 Network connectivity tests
  performance             Performance metrics
  logs                    Collect and analyze logs
  package                 Create diagnostic package

Options:
  -o, --output DIR        Output directory
  --include-logs          Include log files in output
  --log-lines LINES       Number of log lines to include
  --since DURATION        Collect logs since duration
  --sensitive             Include potentially sensitive information
```

### 4. Backup and Recovery

#### `backup-enhanced.sh`
Comprehensive backup and recovery system.

**Usage**:
```bash
./backup-enhanced.sh [OPTIONS] COMMAND

Commands:
  create                  Create a new backup
  list                    List available backups
  restore BACKUP_ID       Restore from specific backup
  verify BACKUP_ID        Verify backup integrity
  cleanup                 Clean up old backups
  schedule                Set up automated backup schedule

Options:
  -d, --destination DIR   Backup destination
  -c, --compress LEVEL    Compression level 0-9
  -e, --encrypt           Encrypt backup with GPG
  -k, --key-id KEY        GPG key ID for encryption
  --retention-days DAYS   Retention period
  --exclude PATTERN       Exclude files matching pattern
  --include-logs          Include log files in backup
```

### 5. Maintenance and Updates

#### `maintenance.sh`
Routine maintenance and optimization.

**Usage**:
```bash
./maintenance.sh [OPTIONS] COMMAND

Commands:
  routine                 Run routine maintenance tasks
  logs                    Log cleanup and rotation
  disk                    Disk space cleanup
  security                Security updates and checks
  performance             Performance optimization
  health                  Health check and repair
  full                    Complete maintenance cycle

Options:
  -f, --force             Force maintenance even if runner is active
  --dry-run               Show what would be done without executing
  --skip-backup           Skip backup before maintenance
  --retention-days DAYS   Log retention period
  --disk-threshold PCT    Disk cleanup threshold
```

#### `cleanup.sh`
Targeted cleanup of logs, cache, and temporary files.

**Usage**:
```bash
./cleanup.sh [OPTIONS] [TARGET]

Targets:
  logs                    Clean log files
  cache                   Clean cache and temporary files
  work                    Clean runner work directories
  docker                  Clean Docker resources
  backups                 Clean old backup files
  all                     Clean all targets

Options:
  -a, --age DAYS          Clean files older than N days
  --cache-age DAYS        Cache retention period
  --work-age DAYS         Work directory retention
  --backup-age DAYS       Backup retention period
  -s, --size-threshold GB Minimum size threshold for cleanup
  -f, --force             Force cleanup without confirmation
  --dry-run               Show what would be cleaned
```

## Common Utilities

### `common/logging.sh`
Centralized logging system with multiple levels and formatting.

**Features**:
- Color-coded console output
- File logging with rotation
- Log level filtering (DEBUG, INFO, WARN, ERROR, FATAL)
- Structured logging for automation

### `common/utils.sh`
Shared utility functions used across all scripts.

**Functions**:
- System information gathering
- Service management helpers
- File and directory operations
- Network and connectivity checks
- Notification and alerting
- Lock file management
- Resource monitoring

## Configuration

### Environment Variables
Scripts read configuration from multiple sources:

1. **Primary Config**: `/etc/github-runner/config.env`
2. **Fallback Config**: `$PROJECT_ROOT/config/runner.env`
3. **Environment Variables**: Override any config value

### Example Configuration (`config.env`)
```bash
# GitHub Actions Runner Configuration
ENVIRONMENT=prod
REPO=owner/repo
USER=github-runner
INSTALL_PATH=/opt/github-runner
LOG_LEVEL=INFO
DOCKER_ENABLED=true
MONITORING_ENABLED=true

# Resource Limits
MAX_CONCURRENT_JOBS=2
MAX_JOB_TIMEOUT=3600
DISK_SPACE_WARNING_THRESHOLD=80
MEMORY_WARNING_THRESHOLD=80

# Backup Configuration
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30
BACKUP_LOCATION="/var/backups/github-runner"

# Alerting
WEBHOOK_URL=https://hooks.slack.com/services/...
ALERT_EMAIL=admin@example.com
```

## Automation and Scheduling

### Cron Job Examples
```bash
# Daily backup at 2 AM
0 2 * * * /path/to/scripts/backup-enhanced.sh create

# Weekly cleanup on Sunday at 3 AM
0 3 * * 0 /path/to/scripts/cleanup.sh all

# Hourly health monitoring
0 * * * * /path/to/scripts/monitor.sh check

# Daily maintenance on weekdays at 4 AM
0 4 * * 1-5 /path/to/scripts/maintenance.sh routine
```

### Systemd Integration
All scripts are designed to work with systemd for service management:

```bash
# Check service status
systemctl status github-runner

# View service logs
journalctl -u github-runner -f

# Restart service
systemctl restart github-runner
```

## Security Considerations

### File Permissions
```bash
# Script permissions
chmod +x /path/to/scripts/*.sh

# Configuration permissions (contains secrets)
chmod 640 /etc/github-runner/config.env
chown root:github-runner /etc/github-runner/config.env

# Log directory permissions
chmod 755 /var/log/github-runner
chown github-runner:github-runner /var/log/github-runner
```

### Secret Management
- Never commit tokens or secrets to version control
- Use environment variables or secure configuration files
- Regularly rotate GitHub runner tokens
- Consider using HashiCorp Vault or similar for secret management

### Network Security
- Configure firewall rules to allow only necessary traffic
- Use VPN or private networks when possible
- Monitor network connections for anomalies
- Implement fail2ban or similar intrusion detection

## Monitoring and Alerting

### Health Checks
The monitoring system checks:
- Service availability and health
- Resource usage (CPU, memory, disk)
- Network connectivity to GitHub
- Runner registration status
- Job execution metrics

### Alert Types
- **Critical**: Service down, GitHub connectivity lost
- **Warning**: High resource usage, job failures
- **Info**: Maintenance completed, backups created

### Notification Channels
- **Slack/Discord**: Webhook notifications
- **Email**: SMTP notifications
- **Log Files**: Structured logging for SIEM integration

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check system logs
journalctl -u github-runner --no-pager -n 50

# Run diagnostics
./diagnostics.sh service

# Check configuration
./status.sh --detailed
```

#### High Resource Usage
```bash
# Check performance metrics
./diagnostics.sh performance

# Run cleanup
./cleanup.sh all --force

# Optimize performance
./maintenance.sh performance
```

#### Network Connectivity Issues
```bash
# Test network connectivity
./diagnostics.sh network

# Check DNS resolution
nslookup github.com

# Test GitHub API
curl -s https://api.github.com/rate_limit
```

#### Runner Not Registering
```bash
# Check runner configuration
cd /opt/github-runner
sudo -u github-runner ./config.sh --check

# Re-register runner (requires new token)
sudo -u github-runner ./config.sh remove
sudo -u github-runner ./config.sh --url https://github.com/owner/repo --token NEW_TOKEN
```

### Log Locations
- **System Logs**: `/var/log/github-runner/`
- **Service Logs**: `journalctl -u github-runner`
- **Script Logs**: Script-specific log files in `/var/log/`
- **Application Logs**: `$INSTALL_PATH/_diag/` (if available)

### Recovery Procedures

#### Service Recovery
```bash
# Stop all services
./stop.sh --force

# Run health check
./diagnostics.sh collect

# Attempt automatic repair
./maintenance.sh health --force

# Restart services
./start.sh
```

#### Data Recovery
```bash
# List available backups
./backup-enhanced.sh list

# Verify backup integrity
./backup-enhanced.sh verify backup-20240115-143022

# Restore from backup
./stop.sh
./backup-enhanced.sh restore backup-20240115-143022
./start.sh
```

## Best Practices

### Operations
1. **Always test in non-production first**
2. **Create backups before major changes**
3. **Monitor logs and metrics regularly**
4. **Keep runners updated and patched**
5. **Use configuration management tools**

### Security
1. **Rotate tokens regularly**
2. **Keep systems updated**
3. **Monitor for suspicious activity**
4. **Use principle of least privilege**
5. **Audit access and changes**

### Performance
1. **Monitor resource usage trends**
2. **Clean up regularly**
3. **Optimize Docker usage**
4. **Scale horizontally when needed**
5. **Use appropriate hardware specs**

## Integration Examples

### CI/CD Pipeline Integration
```yaml
# .github/workflows/runner-maintenance.yml
name: Runner Maintenance
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday

jobs:
  maintenance:
    runs-on: self-hosted
    steps:
      - name: Run Maintenance
        run: |
          /opt/github-runner/scripts/maintenance.sh routine
          /opt/github-runner/scripts/cleanup.sh all
```

### Monitoring Integration
```bash
# Prometheus metrics endpoint
curl http://localhost:9100/metrics | grep github_runner

# Grafana dashboard queries
github_runner_status{job="github-runner"}
github_runner_memory_usage{job="github-runner"}
github_runner_disk_usage{job="github-runner"}
```

## Support and Contributing

### Getting Help
1. Check this documentation first
2. Review log files for error messages
3. Run diagnostics to gather system information
4. Check GitHub Issues for known problems

### Contributing
1. Follow existing code style and patterns
2. Add comprehensive error handling
3. Include logging for debugging
4. Test thoroughly in multiple environments
5. Update documentation

## License

These scripts are provided under the MIT License. See the project LICENSE file for details.

---

**Last Updated**: $(date)
**Version**: 1.0.0
**Maintainer**: System Administrator