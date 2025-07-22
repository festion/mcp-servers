# GitHub Actions Runner - Quick Reference

## Essential Commands

### 🚀 Setup & Deployment
```bash
# Initial setup
sudo ./setup-comprehensive.sh --environment prod --repo owner/repo --token ghp_xxx

# Deploy runner
./deploy-enhanced.sh --environment prod

# Quick validation
./status.sh
```

### 🔧 Service Management
```bash
# Start services
./start.sh

# Stop services (graceful)
./stop.sh --drain

# Restart with health check
./restart.sh --health-check

# Force restart
./restart.sh --force

# Service status
./status.sh --detailed
```

### 📊 Monitoring & Health
```bash
# Start monitoring
./monitor.sh start --interval 60

# Check current health
./monitor.sh check

# View alerts
./alerts.sh check

# Generate diagnostic package
./diagnostics.sh package --output /tmp/diag
```

### 💾 Backup & Recovery
```bash
# Create backup
./backup-enhanced.sh create

# List backups
./backup-enhanced.sh list

# Restore backup
./backup-enhanced.sh restore backup-20240115-143022

# Verify backup
./backup-enhanced.sh verify backup-20240115-143022
```

### 🧹 Maintenance & Cleanup
```bash
# Routine maintenance
./maintenance.sh routine

# Clean logs (7 days)
./cleanup.sh logs --age 7

# Full cleanup
./cleanup.sh all --force

# Performance optimization
./maintenance.sh performance
```

## Status Indicators

### Service Status
- ✅ `active` - Service running normally
- ⚠️ `inactive` - Service stopped
- ❌ `failed` - Service in error state

### Health Status
- 🟢 `healthy` - All systems operational
- 🟡 `warning` - Minor issues detected
- 🔴 `critical` - Immediate attention required

## Common Troubleshooting

### Service Won't Start
```bash
./diagnostics.sh service --json
journalctl -u github-runner --no-pager -n 50
./restart.sh --force
```

### High Resource Usage
```bash
./monitor.sh check
./cleanup.sh all
./maintenance.sh performance --force
```

### Runner Not Visible in GitHub
```bash
cd /opt/github-runner
sudo -u github-runner ./config.sh --check
./restart.sh --health-check
```

### Disk Space Issues
```bash
./cleanup.sh all --force
./backup-enhanced.sh cleanup --retention-days 7
./maintenance.sh disk --disk-threshold 70
```

## File Locations

| Component | Location |
|-----------|----------|
| Runner Installation | `/opt/github-runner` |
| Configuration | `/etc/github-runner/config.env` |
| Logs | `/var/log/github-runner/` |
| Backups | `/var/backups/github-runner/` |
| Scripts | `/opt/github-runner/scripts/` |

## Key Configuration

```bash
# /etc/github-runner/config.env
ENVIRONMENT=prod
REPO=owner/repo
USER=github-runner
INSTALL_PATH=/opt/github-runner

# Monitoring thresholds
DISK_SPACE_WARNING_THRESHOLD=80
MEMORY_WARNING_THRESHOLD=85

# Backup settings
BACKUP_RETENTION_DAYS=30
BACKUP_LOCATION="/var/backups/github-runner"
```

## Emergency Procedures

### Complete Service Recovery
```bash
# 1. Stop everything
./stop.sh --force

# 2. Run diagnostics
./diagnostics.sh package --output /tmp/emergency

# 3. Restore from backup if needed
./backup-enhanced.sh restore [BACKUP_ID]

# 4. Restart services
./start.sh --force

# 5. Verify health
./status.sh --detailed
```

### Reset Runner Registration
```bash
# 1. Stop service
./stop.sh

# 2. Remove registration
cd /opt/github-runner
sudo -u github-runner ./config.sh remove

# 3. Re-register with new token
sudo -u github-runner ./config.sh --url https://github.com/owner/repo --token NEW_TOKEN

# 4. Start service
./start.sh
```

## Automation Examples

### Daily Cron Jobs
```bash
# /etc/crontab
0 2 * * * root /opt/github-runner/scripts/backup-enhanced.sh create
0 3 * * 0 root /opt/github-runner/scripts/cleanup.sh all
0 4 * * 1-5 root /opt/github-runner/scripts/maintenance.sh routine
0 * * * * root /opt/github-runner/scripts/monitor.sh check
```

### Systemd Timer (Alternative)
```bash
# Create timer for daily maintenance
sudo systemctl edit --force --full github-runner-maintenance.timer
sudo systemctl enable github-runner-maintenance.timer
sudo systemctl start github-runner-maintenance.timer
```

## Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Disk Usage | 80% | 90% |
| Memory Usage | 85% | 95% |
| CPU Usage | 90% | 95% |
| Service Down | N/A | Immediate |
| GitHub Connectivity | 30s timeout | 60s timeout |

## Script Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration error |
| 3 | Permission error |
| 4 | Network error |
| 5 | Service error |

---
**📋 Quick Tip**: Use `--help` with any script for detailed usage information
**🔍 Debug Mode**: Add `-v` or `--verbose` to any script for detailed output
**🧪 Test Mode**: Use `--dry-run` to preview changes without executing them