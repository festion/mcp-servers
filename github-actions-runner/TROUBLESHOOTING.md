# GitHub Actions Runner Troubleshooting Guide

## Table of Contents
1. [Quick Reference](#quick-reference)
2. [Common Issues and Solutions](#common-issues-and-solutions)
3. [Diagnostic Procedures](#diagnostic-procedures)
4. [Error Analysis Framework](#error-analysis-framework)
5. [Performance Issues](#performance-issues)
6. [Recovery Procedures](#recovery-procedures)
7. [Emergency Response](#emergency-response)
8. [Tools and Scripts](#tools-and-scripts)

## Quick Reference

### Emergency Contacts
- **System Administrator**: Primary contact for infrastructure issues
- **Security Team**: For security-related incidents
- **On-Call Engineer**: 24/7 support for critical issues

### Quick Commands
```bash
# Check system status
./scripts/status.sh

# View logs
docker logs github-runner
docker logs github-runner-nginx
docker logs github-runner-prometheus

# Restart services
./scripts/restart.sh

# Health check
./scripts/health-check.sh

# Emergency stop
./scripts/stop.sh --force
```

### Log Locations
- **Container logs**: `docker logs <container_name>`
- **Application logs**: `./logs/`
- **System logs**: `/var/log/syslog`
- **Audit logs**: `./security/audit/`

## Common Issues and Solutions

### 1. Container Startup Failures

#### Issue: Container fails to start
**Symptoms:**
- `docker-compose up` fails
- Container status shows "Exited"
- Error messages in docker logs

**Diagnostic Steps:**
```bash
# Check container status
docker ps -a

# View container logs
docker logs github-runner

# Check resource usage
docker stats

# Verify configuration
./config/validate-config.sh
```

**Common Causes & Solutions:**

**Port conflicts:**
```bash
# Check port usage
netstat -tlnp | grep -E ':(80|443|9090|3000)'

# Solution: Update port mappings in docker-compose.yml
```

**Insufficient resources:**
```bash
# Check system resources
free -h
df -h
docker system df

# Solution: Free up space or allocate more resources
docker system prune -f
```

**Configuration errors:**
```bash
# Validate configuration
./config/validate-config.sh

# Check environment variables
cat .env | grep -v '^#'

# Solution: Fix configuration errors identified
```

### 2. GitHub API Connectivity Issues

#### Issue: Runner cannot connect to GitHub API
**Symptoms:**
- Registration failures
- API rate limit errors
- Network timeout errors

**Diagnostic Steps:**
```bash
# Test GitHub connectivity
curl -I https://api.github.com

# Check DNS resolution
nslookup api.github.com

# Test authentication
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Check proxy settings
echo $HTTP_PROXY $HTTPS_PROXY
```

**Solutions:**

**Network connectivity:**
```bash
# Check firewall rules
iptables -L
ufw status

# Test connectivity through proxy
curl --proxy $HTTP_PROXY https://api.github.com
```

**Authentication issues:**
```bash
# Validate token
./config/token-manager.sh validate

# Regenerate token if needed
./config/token-manager.sh regenerate
```

### 3. Private Network Access Problems

#### Issue: Runner cannot access internal resources
**Symptoms:**
- Build failures when accessing internal services
- DNS resolution failures for internal domains
- Connection timeouts to private resources

**Diagnostic Steps:**
```bash
# Test internal connectivity from container
docker exec github-runner ping internal-service.local

# Check DNS configuration
docker exec github-runner cat /etc/resolv.conf

# Test network routes
docker exec github-runner ip route
```

**Solutions:**

**DNS configuration:**
```bash
# Update docker-compose.yml DNS settings
# Add to docker-compose.yml:
services:
  github-runner:
    dns:
      - 192.168.1.1
      - 8.8.8.8
```

**Network routing:**
```bash
# Add custom networks in docker-compose.yml
networks:
  runner-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 4. Runner Registration Failures

#### Issue: Runner fails to register with GitHub
**Symptoms:**
- Registration token errors
- Runner not appearing in GitHub repository settings
- Authentication failures during registration

**Diagnostic Steps:**
```bash
# Check registration logs
docker logs github-runner | grep -i registration

# Verify token validity
./config/token-manager.sh verify

# Check runner configuration
cat ./config/runner-config.yml
```

**Solutions:**

**Token issues:**
```bash
# Generate new registration token
./scripts/generate-token.sh

# Update runner configuration
./config/update-config.sh --token <new_token>
```

**Configuration problems:**
```bash
# Reset runner configuration
./scripts/cleanup.sh --full
./scripts/setup.sh
```

### 5. Job Execution Timeouts

#### Issue: Jobs timeout or hang indefinitely
**Symptoms:**
- Jobs stuck in "Running" state
- Timeout errors in job logs
- Resource exhaustion

**Diagnostic Steps:**
```bash
# Monitor running processes
docker exec github-runner ps aux

# Check resource usage
docker stats github-runner

# Review job logs
docker logs github-runner | tail -100
```

**Solutions:**

**Resource limits:**
```bash
# Update docker-compose.yml resource limits
services:
  github-runner:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
```

**Timeout configuration:**
```bash
# Update runner timeout settings
# In runner-config.yml:
timeout_minutes: 60
```

## Diagnostic Procedures

### System Health Check

```bash
#!/bin/bash
# Enhanced health check procedure

echo "=== GitHub Actions Runner Health Check ==="

# 1. Container Status
echo "1. Checking container status..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Resource Usage
echo "2. Checking resource usage..."
docker stats --no-stream

# 3. Network Connectivity
echo "3. Testing network connectivity..."
docker exec github-runner curl -s -I https://api.github.com | head -1

# 4. Disk Space
echo "4. Checking disk space..."
df -h | grep -E '(Filesystem|/dev/)'

# 5. Log Analysis
echo "5. Analyzing recent logs..."
docker logs github-runner --tail 50 | grep -E '(ERROR|WARN|FATAL)'

# 6. Configuration Validation
echo "6. Validating configuration..."
./config/validate-config.sh --quiet

echo "=== Health Check Complete ==="
```

### Log Analysis Techniques

#### Structured Log Analysis
```bash
# Error pattern analysis
docker logs github-runner 2>&1 | grep -E 'ERROR|FATAL' | tail -20

# Performance metrics extraction
docker logs github-runner 2>&1 | grep -E 'duration:|timing:' | tail -10

# Authentication issues
docker logs github-runner 2>&1 | grep -i 'auth\|token\|permission'

# Network issues
docker logs github-runner 2>&1 | grep -E 'connection|timeout|refused'
```

#### Log Correlation
```bash
# Correlate container logs with system logs
journalctl -u docker.service --since "1 hour ago" | grep github-runner

# Cross-reference with monitoring data
curl -s "http://localhost:9090/api/v1/query?query=container_memory_usage_bytes{name=\"github-runner\"}"
```

### Network Connectivity Testing

```bash
#!/bin/bash
# Comprehensive network test

echo "=== Network Connectivity Test ==="

# External connectivity
echo "Testing external connectivity..."
docker exec github-runner curl -s -I https://github.com | head -1
docker exec github-runner curl -s -I https://api.github.com | head -1

# Internal network
echo "Testing internal network..."
docker exec github-runner ping -c 3 gateway

# DNS resolution
echo "Testing DNS resolution..."
docker exec github-runner nslookup github.com
docker exec github-runner nslookup api.github.com

# Port accessibility
echo "Testing required ports..."
docker exec github-runner nc -zv github.com 443
docker exec github-runner nc -zv api.github.com 443

echo "=== Network Test Complete ==="
```

## Error Analysis Framework

### Error Classification System

#### Severity Levels
1. **CRITICAL** - Service unavailable, data loss risk
2. **HIGH** - Major functionality impaired
3. **MEDIUM** - Minor functionality affected
4. **LOW** - Cosmetic or minor issues

#### Error Categories
- **INFRA** - Infrastructure and system errors
- **CONFIG** - Configuration-related issues
- **AUTH** - Authentication and authorization
- **NETWORK** - Network connectivity problems
- **RESOURCE** - Resource exhaustion or limits
- **APPLICATION** - Application logic errors

### Symptom-to-Cause Mapping

| Symptom | Likely Cause | Investigation Steps | Priority |
|---------|--------------|-------------------|----------|
| Container won't start | Resource constraints, config errors | Check resources, validate config | HIGH |
| Registration fails | Token issues, network problems | Verify token, test connectivity | HIGH |
| Jobs timeout | Resource limits, infinite loops | Monitor resources, check job logs | MEDIUM |
| High memory usage | Memory leaks, large artifacts | Analyze memory patterns, check artifacts | MEDIUM |
| Network timeouts | Firewall, proxy, DNS issues | Test connectivity, check network config | HIGH |

### Escalation Procedures

#### Level 1 - Self-Service
- Check this troubleshooting guide
- Run automated diagnostic scripts
- Review recent changes

#### Level 2 - Team Support
- Contact team lead or senior engineer
- Provide diagnostic output
- Include timeline of events

#### Level 3 - Emergency Response
- Critical system failure
- Security incident
- Data integrity concerns

## Performance Issues

### Resource Exhaustion Handling

#### Memory Issues
```bash
# Monitor memory usage patterns
docker stats github-runner --format "table {{.MemUsage}}\t{{.MemPerc}}"

# Check for memory leaks
docker exec github-runner cat /proc/meminfo

# Solution: Restart container if memory usage > 90%
if [ $(docker stats github-runner --no-stream --format "{{.MemPerc}}" | cut -d'%' -f1) -gt 90 ]; then
    ./scripts/restart.sh
fi
```

#### CPU Issues
```bash
# Monitor CPU usage
docker stats github-runner --format "table {{.CPUPerc}}"

# Check running processes
docker exec github-runner top -b -n1

# Solution: Identify and terminate resource-intensive processes
```

#### Disk Space Issues
```bash
# Check disk usage
docker exec github-runner df -h

# Clean up build artifacts
docker exec github-runner find /work -name "*.tmp" -delete
docker exec github-runner find /work -name "node_modules" -type d -exec rm -rf {} +

# Automated cleanup
./scripts/cleanup.sh --artifacts
```

### Network Latency Problems

```bash
# Measure network latency
docker exec github-runner ping -c 10 api.github.com

# Test download speeds
docker exec github-runner curl -w "@curl-format.txt" -o /dev/null -s https://github.com/test-file

# Solutions:
# 1. Use CDN or mirror repositories
# 2. Implement caching strategies
# 3. Optimize network routes
```

### Scaling and Capacity Planning

#### Horizontal Scaling
```bash
# Deploy additional runners
docker-compose scale github-runner=3

# Load balancing configuration
# Update nginx configuration for multiple runners
```

#### Vertical Scaling
```bash
# Increase resource limits
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 8G
      cpus: '4.0'
```

## Recovery Procedures

### Service Restart Procedures

#### Graceful Restart
```bash
#!/bin/bash
# Graceful service restart

echo "Initiating graceful restart..."

# 1. Stop accepting new jobs
docker exec github-runner touch /tmp/maintenance_mode

# 2. Wait for current jobs to complete (max 30 minutes)
timeout 1800 bash -c 'while docker exec github-runner pgrep -f "runner.Worker"; do sleep 30; done'

# 3. Stop services
docker-compose down

# 4. Perform maintenance
./scripts/cleanup.sh --logs
./scripts/health-check.sh --pre-start

# 5. Start services
docker-compose up -d

# 6. Verify startup
./scripts/health-check.sh --post-start

echo "Graceful restart complete"
```

#### Emergency Restart
```bash
#!/bin/bash
# Emergency restart procedure

echo "Initiating emergency restart..."

# 1. Force stop all containers
docker-compose down --timeout 30
docker kill $(docker ps -q) 2>/dev/null || true

# 2. Clean up resources
docker system prune -f
docker volume prune -f

# 3. Restart services
docker-compose up -d

# 4. Immediate health check
./scripts/health-check.sh --critical

echo "Emergency restart complete"
```

### Configuration Rollback

```bash
#!/bin/bash
# Configuration rollback procedure

BACKUP_DIR="./backups/config"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 1. Create current state backup
mkdir -p "$BACKUP_DIR/pre-rollback-$TIMESTAMP"
cp -r ./config/* "$BACKUP_DIR/pre-rollback-$TIMESTAMP/"

# 2. List available backups
echo "Available configuration backups:"
ls -la "$BACKUP_DIR"

# 3. Restore from backup
read -p "Enter backup directory to restore from: " RESTORE_DIR
if [ -d "$BACKUP_DIR/$RESTORE_DIR" ]; then
    cp -r "$BACKUP_DIR/$RESTORE_DIR"/* ./config/
    echo "Configuration restored from $RESTORE_DIR"
    
    # 4. Restart services with restored config
    ./scripts/restart.sh
    ./scripts/health-check.sh
else
    echo "Backup directory not found"
    exit 1
fi
```

### Backup Restoration

```bash
#!/bin/bash
# Comprehensive backup restoration

BACKUP_PATH="$1"
if [ -z "$BACKUP_PATH" ]; then
    echo "Usage: $0 <backup_path>"
    exit 1
fi

echo "Restoring from backup: $BACKUP_PATH"

# 1. Stop all services
docker-compose down

# 2. Restore data volumes
docker run --rm -v github-runner-data:/data -v "$BACKUP_PATH":/backup alpine tar xzf /backup/data.tar.gz -C /data

# 3. Restore configuration
tar xzf "$BACKUP_PATH/config.tar.gz" -C ./

# 4. Restore logs (optional)
tar xzf "$BACKUP_PATH/logs.tar.gz" -C ./logs/

# 5. Start services
docker-compose up -d

# 6. Verify restoration
./scripts/health-check.sh --full

echo "Backup restoration complete"
```

## Emergency Response

### Security Incident Response

#### Immediate Actions
1. **Isolate affected systems**
   ```bash
   # Disconnect from network
   docker network disconnect bridge github-runner
   
   # Stop container
   docker stop github-runner
   ```

2. **Preserve evidence**
   ```bash
   # Create forensic backup
   docker commit github-runner incident-$(date +%Y%m%d_%H%M%S)
   
   # Export logs
   docker logs github-runner > incident-logs-$(date +%Y%m%d_%H%M%S).log
   ```

3. **Assess impact**
   ```bash
   # Check for unauthorized access
   docker exec github-runner last -20
   
   # Review audit logs
   cat ./security/audit/*.log | grep -E 'UNAUTHORIZED|SUSPICIOUS'
   ```

### Data Recovery Scenarios

#### Corrupted Data Volume
```bash
# Check filesystem integrity
docker run --rm -v github-runner-data:/data alpine fsck /data

# Restore from backup if corrupted
./scripts/backup.sh restore --data-only
```

#### Configuration Corruption
```bash
# Validate current configuration
./config/validate-config.sh

# Restore from last known good configuration
./config/restore-config.sh --latest-stable
```

### Disaster Recovery Protocols

#### Complete System Failure
1. **Assessment Phase**
   - Determine scope of failure
   - Identify recovery requirements
   - Estimate recovery time

2. **Recovery Phase**
   ```bash
   # Deploy to backup infrastructure
   ./scripts/deploy.sh --disaster-recovery
   
   # Restore from offsite backups
   ./scripts/backup.sh restore --offsite
   
   # Reconfigure networking
   ./scripts/network-recovery.sh
   ```

3. **Verification Phase**
   ```bash
   # Comprehensive system test
   ./scripts/verify-installation.sh --full
   
   # Performance baseline test
   ./scripts/performance-test.sh
   
   # Security audit
   ./scripts/security-audit.sh
   ```

## Tools and Scripts

### Diagnostic Tools

#### System Information Collector
```bash
#!/bin/bash
# File: ./scripts/collect-diagnostics.sh

DIAG_DIR="./diagnostics/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DIAG_DIR"

echo "Collecting diagnostic information..."

# System information
uname -a > "$DIAG_DIR/system-info.txt"
docker version > "$DIAG_DIR/docker-version.txt"
docker-compose version > "$DIAG_DIR/compose-version.txt"

# Container information
docker ps -a > "$DIAG_DIR/containers.txt"
docker images > "$DIAG_DIR/images.txt"
docker network ls > "$DIAG_DIR/networks.txt"
docker volume ls > "$DIAG_DIR/volumes.txt"

# Resource usage
docker stats --no-stream > "$DIAG_DIR/stats.txt"
df -h > "$DIAG_DIR/disk-usage.txt"
free -h > "$DIAG_DIR/memory-usage.txt"

# Logs
docker logs github-runner > "$DIAG_DIR/runner-logs.txt" 2>&1
docker logs github-runner-nginx > "$DIAG_DIR/nginx-logs.txt" 2>&1

# Configuration
cp -r ./config "$DIAG_DIR/"
cp docker-compose.yml "$DIAG_DIR/"

echo "Diagnostics collected in: $DIAG_DIR"
tar czf "$DIAG_DIR.tar.gz" -C ./diagnostics "$(basename "$DIAG_DIR")"
echo "Archive created: $DIAG_DIR.tar.gz"
```

#### Log Analyzer
```bash
#!/bin/bash
# File: ./scripts/analyze-logs.sh

LOG_FILE="$1"
if [ -z "$LOG_FILE" ]; then
    LOG_FILE="$(docker logs github-runner 2>&1)"
fi

echo "=== Log Analysis Report ==="

# Error summary
echo "Error Summary:"
echo "$LOG_FILE" | grep -E 'ERROR|FATAL' | sort | uniq -c | sort -nr

# Warning summary
echo -e "\nWarning Summary:"
echo "$LOG_FILE" | grep 'WARN' | sort | uniq -c | sort -nr

# Performance metrics
echo -e "\nPerformance Metrics:"
echo "$LOG_FILE" | grep -E 'duration:|timing:' | tail -10

# Recent activity
echo -e "\nRecent Activity (last 20 entries):"
echo "$LOG_FILE" | tail -20
```

### Monitoring Integration

#### Alert Integration Script
```bash
#!/bin/bash
# File: ./scripts/alert-handler.sh

ALERT_TYPE="$1"
ALERT_MESSAGE="$2"

case "$ALERT_TYPE" in
    "critical")
        # Emergency response
        ./scripts/emergency-restart.sh
        # Notify on-call engineer
        curl -X POST "$SLACK_WEBHOOK" -d "{\"text\":\"CRITICAL: $ALERT_MESSAGE\"}"
        ;;
    "warning")
        # Automated remediation
        ./scripts/health-check.sh --fix-issues
        # Log for review
        echo "$(date): WARNING - $ALERT_MESSAGE" >> ./logs/alerts.log
        ;;
    "info")
        # Log only
        echo "$(date): INFO - $ALERT_MESSAGE" >> ./logs/alerts.log
        ;;
esac
```

### Maintenance Tools

#### Automated Cleanup
```bash
#!/bin/bash
# File: ./scripts/automated-cleanup.sh

echo "Starting automated cleanup..."

# Clean Docker resources
docker system prune -f
docker volume prune -f

# Clean old logs (keep last 7 days)
find ./logs -name "*.log" -mtime +7 -delete

# Clean build artifacts
docker exec github-runner find /work -name "*.tmp" -delete
docker exec github-runner find /work -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null

# Clean old backups (keep last 30 days)
find ./backups -name "*.tar.gz" -mtime +30 -delete

echo "Automated cleanup complete"
```

## Contact Information

### Support Channels
- **Primary Support**: support@organization.com
- **Emergency Hotline**: +1-XXX-XXX-XXXX
- **Slack Channel**: #github-runners-support
- **Documentation**: https://wiki.organization.com/github-runners

### Escalation Matrix
| Issue Severity | First Contact | Response Time | Escalation |
|----------------|---------------|---------------|------------|
| Critical | On-call Engineer | 15 minutes | CTO |
| High | Team Lead | 1 hour | Engineering Manager |
| Medium | Senior Engineer | 4 hours | Team Lead |
| Low | Any Team Member | Next business day | N/A |

---

**Document Version**: 1.0  
**Last Updated**: $(date +%Y-%m-%d)  
**Maintained By**: Infrastructure Team  
**Review Schedule**: Monthly