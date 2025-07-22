# GitHub Actions Runner - Backup and Recovery System

A comprehensive backup and recovery solution for GitHub Actions runner deployments with automated backups, validation, and disaster recovery capabilities.

## 🚀 Features

### Backup Types
- **Full Backup**: Complete system backup including runner installation, configuration, data, and credentials
- **Incremental Backup**: Changes-only backup based on baseline full backup
- **Configuration Backup**: Configuration files, environment variables, and service definitions only

### Storage Options
- **Local Storage**: Direct filesystem storage with configurable retention
- **Remote Storage**: AWS S3, rsync, SCP, and FTP support
- **Encryption**: GPG-based encryption for sensitive data
- **Compression**: Configurable compression levels (0-9)

### Automation & Scheduling
- **Automated Scheduling**: Cron and systemd timer support
- **Retention Policies**: Automatic cleanup based on age and count
- **Health Monitoring**: Backup validation and integrity checking
- **Notifications**: Webhook, email, and Slack notifications

### Recovery Features
- **Full System Restore**: Complete disaster recovery capability
- **Selective Restore**: Configuration-only or component-specific restore
- **Safety Backups**: Automatic current state backup before restoration
- **Verification**: Post-restore validation and testing

## 📁 Directory Structure

```
backup/
├── scripts/                 # Main backup and restore scripts
│   ├── backup-full.sh      # Full system backup
│   ├── backup-incremental.sh # Incremental backup
│   ├── backup-config.sh    # Configuration backup
│   ├── backup-validate.sh  # Backup validation
│   ├── backup-schedule.sh  # Schedule management
│   ├── restore-full.sh     # Full system restore
│   ├── restore-config.sh   # Configuration restore
│   ├── recovery/           # Additional recovery scripts
│   └── common/             # Shared functions
├── config/                 # Configuration files
│   └── backup.conf         # Main backup configuration
├── storage/                # Storage management
│   └── storage-manager.sh  # Storage configuration and management
├── tests/                  # Testing framework
│   └── backup-test-suite.sh # Comprehensive test suite
└── README.md              # This documentation
```

## 🚀 Quick Start

### 1. Basic Setup

```bash
# Navigate to backup directory
cd /home/dev/workspace/github-actions-runner/backup

# Configure backup settings
cp config/backup.conf config/backup.conf.local
vim config/backup.conf.local

# Set up storage
./storage/storage-manager.sh setup --storage local --destination /var/backups/github-runner

# Test the configuration
./scripts/backup-validate.sh --list
```

### 2. Create Your First Backup

```bash
# Full backup
./scripts/backup-full.sh

# Configuration backup only
./scripts/backup-config.sh --include-secrets --include-env

# Incremental backup (requires existing full backup)
./scripts/backup-incremental.sh --auto-baseline
```

### 3. Set Up Automation

```bash
# Configure automated backups
./scripts/backup-schedule.sh setup

# Test the schedule
./scripts/backup-schedule.sh test

# Check schedule status
./scripts/backup-schedule.sh status
```

## 📖 Detailed Usage

### Backup Operations

#### Full System Backup
```bash
# Basic full backup
./scripts/backup-full.sh

# Full backup with all options
./scripts/backup-full.sh \
    --destination /var/backups/github-runner \
    --encrypt \
    --remote \
    --verify \
    --include-docker \
    --include-logs \
    --include-metrics \
    --parallel
```

#### Incremental Backup
```bash
# Auto-baseline incremental backup
./scripts/backup-incremental.sh --auto-baseline

# Specific baseline incremental backup
./scripts/backup-incremental.sh --baseline full-backup-20240115

# Track changes with detailed reporting
./scripts/backup-incremental.sh --auto-baseline --track-changes
```

#### Configuration Backup
```bash
# Basic configuration backup
./scripts/backup-config.sh

# Complete configuration backup
./scripts/backup-config.sh \
    --include-secrets \
    --include-env \
    --include-docker \
    --include-systemd \
    --encrypt \
    --verify
```

### Restore Operations

#### Full System Restore
```bash
# Basic full restore
./scripts/restore-full.sh full-backup-20240115

# Safe full restore with verification
./scripts/restore-full.sh \
    --backup-current \
    --stop-services \
    --start-services \
    --verify-after \
    --rollback-on-failure \
    full-backup-20240115
```

#### Configuration Restore
```bash
# Basic configuration restore
./scripts/restore-config.sh config-backup-20240115

# Selective configuration restore
./scripts/restore-config.sh \
    --config-only \
    --backup-current \
    --verify-syntax \
    --reload-services \
    config-backup-20240115
```

### Validation and Testing

#### Backup Validation
```bash
# Validate specific backup
./scripts/backup-validate.sh full-backup-20240115

# Comprehensive validation
./scripts/backup-validate.sh \
    --all \
    --deep \
    --checksum \
    --structure \
    --restore-test

# Generate validation report
./scripts/backup-validate.sh \
    --all \
    --report /tmp/backup-validation-report.txt
```

#### Test Suite
```bash
# Run all tests
./tests/backup-test-suite.sh all

# Run specific test suites
./tests/backup-test-suite.sh unit --verbose
./tests/backup-test-suite.sh integration --parallel
./tests/backup-test-suite.sh performance --format json
./tests/backup-test-suite.sh disaster-recovery --no-cleanup
```

### Storage Management

#### Setup Storage
```bash
# Local storage
./storage/storage-manager.sh setup --storage local --destination /var/backups

# AWS S3 storage
./storage/storage-manager.sh setup --storage s3 --destination s3://my-bucket/backups

# Rsync storage
./storage/storage-manager.sh setup --storage rsync --destination user@host:/backup/path
```

#### Storage Operations
```bash
# Test storage connectivity
./storage/storage-manager.sh test

# Sync to remote storage
./storage/storage-manager.sh sync

# Monitor storage usage
./storage/storage-manager.sh monitor

# Clean up old backups
./storage/storage-manager.sh cleanup --dry-run
```

## ⚙️ Configuration

### Main Configuration File

Edit `config/backup.conf` to customize backup behavior:

```bash
# Enable/disable backup system
BACKUP_ENABLED=true

# Default backup destination
BACKUP_DESTINATION="/var/backups/github-runner"

# Retention policies
BACKUP_RETENTION_FULL_DAYS=90
BACKUP_RETENTION_INCREMENTAL_DAYS=14
BACKUP_RETENTION_CONFIG_DAYS=30

# Compression and encryption
BACKUP_COMPRESSION_LEVEL=6
BACKUP_ENCRYPTION_ENABLED=false

# Remote storage
BACKUP_REMOTE_ENABLED=false
BACKUP_REMOTE_TYPE="rsync"
BACKUP_REMOTE_DESTINATION=""

# Notifications
BACKUP_NOTIFICATIONS_ENABLED=false
BACKUP_NOTIFICATION_URL=""
```

### Environment-Specific Configuration

Create environment-specific configurations:

```bash
# Development environment
cp config/backup.conf config/backup-dev.conf

# Production environment  
cp config/backup.conf config/backup-prod.conf

# Use specific configuration
./scripts/backup-full.sh --config config/backup-prod.conf
```

## 🔐 Security

### Encryption Setup

1. **Generate GPG Key**:
```bash
gpg --gen-key
```

2. **Configure Encryption**:
```bash
# In backup.conf
BACKUP_ENCRYPTION_ENABLED=true
BACKUP_ENCRYPTION_KEY_ID="your-key-id"
```

3. **Encrypt Existing Backups**:
```bash
./storage/storage-manager.sh encrypt
```

### File Permissions

The backup system automatically sets secure permissions:
- Backup files: `640` (rw-r-----)
- Backup directories: `750` (rwxr-x---)
- Credential files: `600` (rw-------)

## 📊 Monitoring and Alerts

### Health Monitoring

```bash
# Check backup health
./scripts/backup-validate.sh --all --checksum

# Storage monitoring
./storage/storage-manager.sh monitor

# Test all components
./tests/backup-test-suite.sh all --format json
```

### Notification Setup

#### Webhook Notifications
```bash
# In backup.conf
BACKUP_NOTIFICATIONS_ENABLED=true
BACKUP_NOTIFICATION_URL="https://your-webhook-url.com/backup"
BACKUP_NOTIFICATION_EVENTS="failure,warning"
```

#### Email Notifications
```bash
BACKUP_EMAIL_ENABLED=true
BACKUP_EMAIL_SMTP_SERVER="smtp.example.com"
BACKUP_EMAIL_FROM="backups@example.com"
BACKUP_EMAIL_TO="admin@example.com"
```

#### Slack Notifications
```bash
BACKUP_SLACK_ENABLED=true
BACKUP_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
BACKUP_SLACK_CHANNEL="#backups"
```

## 🏥 Disaster Recovery

### Complete System Recovery

1. **Assess Damage**:
```bash
./tests/backup-test-suite.sh disaster-recovery
```

2. **Identify Latest Backup**:
```bash
./scripts/backup-validate.sh --list
```

3. **Perform Recovery**:
```bash
./scripts/restore-full.sh \
    --backup-current \
    --stop-services \
    --start-services \
    --verify-after \
    latest-backup-id
```

### Emergency Backup

```bash
# Quick emergency backup
./scripts/backup-config.sh \
    --include-secrets \
    --destination /tmp/emergency-backup \
    --compression 9
```

## 🔧 Troubleshooting

### Common Issues

#### Backup Fails
```bash
# Check logs
tail -f /var/log/github-runner-backup.log

# Validate environment
./tests/backup-test-suite.sh unit

# Check storage
./storage/storage-manager.sh test
```

#### Restore Fails
```bash
# Verify backup integrity
./scripts/backup-validate.sh --deep backup-id

# Check available space
df -h

# Validate permissions
ls -la /opt/github-runner
```

#### Schedule Issues
```bash
# Check cron jobs
crontab -l | grep backup

# Check systemd timers
systemctl list-timers | grep backup

# Test schedule configuration
./scripts/backup-schedule.sh test
```

### Debug Mode

Enable debug logging:
```bash
export LOG_LEVEL="DEBUG"
./scripts/backup-full.sh --verbose
```

## 📈 Performance Optimization

### Storage Performance
```bash
# Test storage performance
./storage/storage-manager.sh test

# Optimize compression
# Level 0: Fast, large files
# Level 6: Balanced (default)  
# Level 9: Slow, small files
```

### Parallel Operations
```bash
# Enable parallel backups
./scripts/backup-full.sh --parallel

# Configure parallel tests
./tests/backup-test-suite.sh all --parallel
```

## 🔄 Integration

### Homelab Integration

```bash
# Enable homelab integration
# In backup.conf
BACKUP_HOMELAB_INTEGRATION=true
BACKUP_HOMELAB_TYPE="proxmox"
BACKUP_HOMELAB_DESTINATION="proxmox-server:/backup/github-runner"
```

### CI/CD Integration

```yaml
# GitHub Actions workflow example
name: Backup Validation
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
  
jobs:
  validate-backups:
    runs-on: self-hosted
    steps:
      - name: Validate Backups
        run: |
          cd /home/dev/workspace/github-actions-runner/backup
          ./scripts/backup-validate.sh --all --checksum
          
      - name: Run Test Suite
        run: |
          ./tests/backup-test-suite.sh all --format junit
```

## 📚 API Reference

### Script Parameters

All scripts support common parameters:
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--dry-run`: Preview operations without executing
- `--config FILE`: Use specific configuration file

### Exit Codes

- `0`: Success
- `1`: General error
- `2`: Configuration error
- `3`: Permission error
- `4`: Storage error
- `5`: Validation error

## 🤝 Contributing

### Development Setup

1. **Clone and Setup**:
```bash
git clone <repository>
cd github-actions-runner/backup
./tests/backup-test-suite.sh unit
```

2. **Testing**:
```bash
# Run unit tests
./tests/backup-test-suite.sh unit

# Run integration tests  
./tests/backup-test-suite.sh integration

# Run all tests
./tests/backup-test-suite.sh all
```

3. **Code Style**:
- Follow existing shell script conventions
- Add logging to all functions
- Include error handling
- Document all parameters

## 📄 License

This backup and recovery system is part of the GitHub Actions runner deployment and follows the same licensing terms.

## 🆘 Support

### Getting Help

1. **Check Documentation**: This README and inline help
2. **Run Diagnostics**: `./tests/backup-test-suite.sh all`
3. **Check Logs**: `/var/log/github-runner-backup*.log`
4. **Validate Configuration**: `./scripts/backup-validate.sh --all`

### Reporting Issues

Include the following information:
- Operating system and version
- Backup configuration (`config/backup.conf`)
- Error logs and messages
- Output of diagnostic tests
- Steps to reproduce the issue

---

**📍 Quick Reference Card**

| Operation | Command |
|-----------|---------|
| Full Backup | `./scripts/backup-full.sh` |
| Config Backup | `./scripts/backup-config.sh --include-secrets` |
| Full Restore | `./scripts/restore-full.sh backup-id` |
| Validate All | `./scripts/backup-validate.sh --all` |
| Setup Schedule | `./scripts/backup-schedule.sh setup` |
| Test Storage | `./storage/storage-manager.sh test` |
| Run Tests | `./tests/backup-test-suite.sh all` |

For detailed command options, use `--help` with any script.