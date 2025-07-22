# GitHub Actions Runner Monitoring System

## Overview

This comprehensive monitoring system provides health checks, metrics collection, alerting, and visualization for the GitHub Actions runner infrastructure. It integrates with existing homelab monitoring systems and provides proactive monitoring capabilities.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Health Check   │    │ Metrics         │    │ Alert Manager   │
│  Scripts        │    │ Collector       │    │ System          │
│                 │    │                 │    │                 │
│ • health-check  │    │ • Custom metrics│    │ • Alert routing │
│ • Auto-recovery │    │ • Prometheus    │    │ • Escalation    │
│ • Validation    │    │ • Export        │    │ • Integration   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                    ┌─────────────────┐
                    │   Prometheus    │
                    │   & Grafana     │
                    │                 │
                    │ • Data storage  │
                    │ • Visualization │
                    │ • Alerting      │
                    └─────────────────┘
```

## Components

### 1. Health Check System (`scripts/health-check.sh`)

**Purpose**: Comprehensive health validation and monitoring

**Features**:
- Container health monitoring
- GitHub API connectivity checks
- Private network reachability tests
- Resource utilization monitoring
- Service dependency checks
- Auto-recovery mechanisms
- Integration with homelab-gitops-auditor

**Usage**:
```bash
# Basic health check
./scripts/health-check.sh

# With auto-recovery enabled
./scripts/health-check.sh --auto-recovery

# Report generation only
./scripts/health-check.sh --report-only
```

**Health Check Categories**:
- **Container Health**: Monitors all runner containers
- **GitHub API**: Tests connectivity to GitHub services
- **Private Network**: Checks homelab infrastructure access
- **Resource Usage**: CPU, memory, and disk utilization
- **Service Dependencies**: Prometheus, Fluent Bit, Nginx status
- **Runner Metrics**: Job processing and connection status

### 2. Metrics Collection (`scripts/metrics-collector.sh`)

**Purpose**: Custom metrics gathering and Prometheus integration

**Features**:
- GitHub Actions job metrics
- System resource metrics
- Container performance metrics
- Network connectivity metrics
- Business metrics (deployment success rates, etc.)
- Prometheus-compatible format export

**Usage**:
```bash
# Collect metrics once
./scripts/metrics-collector.sh collect

# Start continuous collection server
./scripts/metrics-collector.sh server

# Export to textfile collector
./scripts/metrics-collector.sh export

# Check collector health
./scripts/metrics-collector.sh health
```

**Metrics Categories**:
- **Job Metrics**: Success/failure rates, duration, throughput
- **System Metrics**: CPU, memory, disk, load average
- **Container Metrics**: Status, restarts, resource usage
- **Network Metrics**: Connectivity, error rates
- **Business Metrics**: Deployment success, SLA tracking

### 3. Alert Management (`scripts/alert-manager.sh`)

**Purpose**: Alert processing, routing, and escalation

**Features**:
- Multi-channel alert routing (Slack, email, webhook)
- Alert escalation and tracking
- Integration with homelab-gitops-auditor
- Alert lifecycle management
- Configurable severity levels

**Usage**:
```bash
# Send manual alert
./scripts/alert-manager.sh send critical "Title" "Message"

# Resolve alert
./scripts/alert-manager.sh resolve alert-id "Resolution message"

# List active alerts
./scripts/alert-manager.sh list active

# Get alert statistics
./scripts/alert-manager.sh stats

# Process health check results
./scripts/alert-manager.sh process-health /path/to/health-report.json
```

**Alert Channels**:
- **Slack**: Rich notifications with color coding
- **Email**: Detailed alert information
- **Webhook**: Custom integration endpoints
- **Homelab Auditor**: Integration with existing monitoring

### 4. Prometheus Configuration (`configs/prometheus.yml`)

**Purpose**: Metrics collection and storage configuration

**Features**:
- Comprehensive scrape configuration
- Custom recording rules
- Integration with existing monitoring
- Blackbox monitoring for external endpoints
- Homelab infrastructure monitoring

**Scrape Jobs**:
- **prometheus**: Self-monitoring
- **node-exporter**: System metrics
- **github-runner-custom**: Custom runner metrics
- **docker**: Container daemon metrics
- **cadvisor**: Container resource metrics
- **blackbox**: External endpoint monitoring

### 5. Alert Rules (`alerts/runner-alerts.yml`)

**Purpose**: Automated alert generation based on metrics

**Alert Groups**:
- **Critical**: Service failures, resource exhaustion
- **Warning**: Performance degradation, elevated usage
- **Info**: Maintenance events, capacity planning
- **SLA**: Service level agreement violations

**Key Alerts**:
- `GitHubRunnerDisconnected`: Runner loses GitHub connection
- `GitHubRunnerContainerDown`: Container failures
- `GitHubRunnerHighResourceUsage`: CPU/memory/disk thresholds
- `GitHubAPIUnreachable`: GitHub API connectivity issues
- `GitHubRunnerHighJobFailureRate`: Job execution problems

### 6. Grafana Dashboards

**Overview Dashboard** (`dashboards/github-runner-overview.json`):
- System health score
- GitHub connection status
- Container status overview
- Job success rates
- Resource utilization trends
- Network connectivity monitoring

**Performance Dashboard** (`dashboards/github-runner-performance.json`):
- Job execution throughput
- Average job duration
- System load analysis
- Container resource usage
- Restart frequency tracking
- Network performance metrics

## Configuration

### Environment Variables

```bash
# Metrics collection
METRICS_PORT=9091
COLLECTION_INTERVAL=30
TEXTFILE_COLLECTOR_DIR=/var/lib/node_exporter/textfile_collector

# Alert configuration
ALERT_WEBHOOK_URL=https://your-webhook-endpoint
ALERT_EMAIL=admin@example.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

### Health Check Configuration

Edit `health-checks.yml`:

```yaml
health_checks:
  - name: github-runner
    endpoint: http://runner:8080/health
    timeout: 10
    interval: 30
    retries: 3

thresholds:
  cpu_usage: 80
  memory_usage: 80
  disk_usage: 85
  network_error_rate: 0.01

alerts:
  webhook_url: "https://your-webhook"
  email: "admin@example.com"
  slack_webhook: "https://hooks.slack.com/..."
```

## Integration with Homelab Infrastructure

### Homelab GitOps Auditor Integration

The monitoring system integrates with the existing homelab-gitops-auditor:

```bash
# Alert routing through auditor
/home/dev/workspace/homelab-gitops-auditor/scripts/send-alert.sh

# Shared monitoring infrastructure
# - Prometheus federation
# - Grafana dashboards
# - Alert consolidation
```

### Network Monitoring

Monitors critical homelab endpoints:
- **Home Assistant**: 192.168.1.155:8123
- **Proxmox**: 192.168.1.137:8006
- **WikiJS**: 192.168.1.90:3000

## Automation and Scheduling

### Cron Jobs

```bash
# Health checks every 5 minutes
*/5 * * * * /home/dev/workspace/github-actions-runner/monitoring/scripts/health-check.sh

# Metrics collection every 30 seconds (via systemd timer)
# Alert processing every minute
* * * * * /home/dev/workspace/github-actions-runner/monitoring/scripts/alert-manager.sh monitor
```

### Systemd Services

```ini
# /etc/systemd/system/github-runner-metrics.service
[Unit]
Description=GitHub Actions Runner Metrics Collector
After=network.target

[Service]
Type=simple
User=monitoring
ExecStart=/home/dev/workspace/github-actions-runner/monitoring/scripts/metrics-collector.sh server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Monitoring Best Practices

### 1. Health Check Strategy
- **Frequency**: Every 5 minutes for critical checks
- **Thresholds**: Conservative to avoid false positives
- **Auto-recovery**: Enabled for non-destructive actions
- **Escalation**: Progressive alert escalation

### 2. Metrics Collection
- **Retention**: 30 days for detailed metrics
- **Aggregation**: 5-minute windows for rates
- **Storage**: Efficient using Prometheus TSDB
- **Export**: Compatible with external systems

### 3. Alert Management
- **Severity Levels**: Critical, warning, info classification
- **Routing**: Context-aware channel selection
- **Escalation**: Time-based escalation policies
- **Correlation**: Related alert grouping

### 4. Performance Optimization
- **Scrape Intervals**: Balanced for accuracy vs. load
- **Query Optimization**: Efficient PromQL queries
- **Dashboard Performance**: Optimized visualizations
- **Resource Usage**: Monitoring system overhead

## Troubleshooting

### Common Issues

1. **High Resource Usage**:
   ```bash
   # Check system resources
   ./scripts/health-check.sh --report-only
   
   # Analyze metrics
   ./scripts/metrics-collector.sh collect
   ```

2. **GitHub Connection Issues**:
   ```bash
   # Test GitHub API
   curl -s https://api.github.com
   
   # Check runner logs
   docker logs github-runner
   ```

3. **Alert Fatigue**:
   ```bash
   # Review alert thresholds
   vim monitoring/alerts/runner-alerts.yml
   
   # Check alert statistics
   ./scripts/alert-manager.sh stats
   ```

### Debug Mode

Enable debug logging:
```bash
export DEBUG=1
./scripts/health-check.sh
```

### Log Locations

- **Health Check**: `logs/health-check.log`
- **Metrics Collector**: `logs/metrics-collector.log`
- **Alert Manager**: `logs/alert-manager.log`
- **Health Reports**: `data/metrics/health-report-*.json`

## Security Considerations

### Access Control
- **Metrics endpoints**: Restricted to monitoring network
- **Alert channels**: Authenticated webhooks
- **Log files**: Appropriate file permissions
- **Secrets**: Environment variable configuration

### Data Protection
- **Metrics scraping**: Internal network only
- **Alert content**: Sanitized sensitive information
- **Log retention**: Automated cleanup policies
- **Backup strategy**: Configuration and historical data

## Maintenance

### Regular Tasks

1. **Weekly**:
   - Review alert statistics
   - Check disk usage trends
   - Update dashboard queries

2. **Monthly**:
   - Review threshold settings
   - Analyze performance trends
   - Update alert rules

3. **Quarterly**:
   - Capacity planning review
   - Security audit
   - Documentation updates

### Updates and Upgrades

```bash
# Update monitoring scripts
git pull origin main

# Restart services
systemctl restart github-runner-metrics
systemctl restart github-runner-health-check

# Verify functionality
./scripts/health-check.sh
```

## Support and Documentation

### Resources
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/
- **GitHub Actions**: https://docs.github.com/en/actions
- **Docker Monitoring**: https://docs.docker.com/config/daemon/prometheus/

### Contact
- **Homelab GitOps Auditor**: Integrated monitoring system
- **GitHub Issues**: For bug reports and feature requests
- **Documentation**: This README and inline comments

---

## Quick Start

1. **Deploy monitoring system**:
   ```bash
   cd /home/dev/workspace/github-actions-runner
   docker-compose up -d
   ```

2. **Start metrics collection**:
   ```bash
   ./monitoring/scripts/metrics-collector.sh server &
   ```

3. **Run initial health check**:
   ```bash
   ./monitoring/scripts/health-check.sh --auto-recovery
   ```

4. **Access dashboards**:
   - Grafana: http://localhost:3000
   - Prometheus: http://localhost:9090

5. **Configure alerts**:
   ```bash
   vim monitoring/health-checks.yml
   ```

The monitoring system is now ready to provide comprehensive oversight of your GitHub Actions runner infrastructure!