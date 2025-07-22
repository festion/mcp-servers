# GitHub Actions Self-Hosted Runner - Docker Compose Setup

This repository contains a production-ready Docker Compose configuration for GitHub Actions self-hosted runners with comprehensive monitoring, logging, and fault-tolerance capabilities.

## Features

- **Fault-Tolerant Runner**: Auto-recovery mechanisms and health monitoring
- **Comprehensive Monitoring**: Prometheus metrics collection with Grafana-ready dashboards
- **Centralized Logging**: Fluent Bit log aggregation with structured logging
- **Security Hardening**: Nginx reverse proxy with SSL/TLS termination and rate limiting
- **Automated Backups**: Scheduled backup service with retention policies
- **Resource Management**: CPU and memory limits with proper resource allocation
- **Network Isolation**: Secure container networking with bridge networks

## Architecture

### Services

1. **Runner**: GitHub Actions runner container
2. **Health Monitor**: Node Exporter for system metrics
3. **Log Aggregator**: Fluent Bit for log collection and forwarding
4. **Metrics Collector**: Prometheus for metrics storage and alerting
5. **Backup Service**: Automated backup with configurable retention
6. **Nginx Proxy**: Reverse proxy with SSL termination and security headers
7. **Watchdog**: Service health monitoring and auto-recovery

### Networks

- **runner_network**: Internal container communication (172.20.0.0/16)
- **host_network**: Host network access for private IP connectivity (192.168.100.0/24)

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- GitHub repository with Actions enabled
- GitHub Personal Access Token with appropriate permissions

### Setup

1. **Clone and prepare the environment**:
   ```bash
   cd /home/dev/workspace/github-actions-runner
   cp .env.example .env
   ```

2. **Configure environment variables**:
   ```bash
   nano .env
   ```
   
   Required variables:
   - `RUNNER_TOKEN`: GitHub runner registration token
   - `RUNNER_REPOSITORY_URL`: GitHub repository URL
   - `RUNNER_NAME`: Unique runner name

3. **Generate SSL certificates** (for production):
   ```bash
   # Self-signed certificate (for testing)
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout nginx/ssl/key.pem \
     -out nginx/ssl/cert.pem \
     -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
   ```

4. **Start the services**:
   ```bash
   docker-compose up -d
   ```

5. **Verify deployment**:
   ```bash
   docker-compose ps
   curl -k https://localhost/health
   ```

## Configuration

### Environment Variables

Key configuration options in `.env`:

```bash
# Runner Configuration
RUNNER_NAME=homelab-runner
RUNNER_TOKEN=your_github_runner_token_here
RUNNER_REPOSITORY_URL=https://github.com/your-org/your-repo
RUNNER_LABELS=homelab,docker,self-hosted,linux

# Resource Limits
RUNNER_CPU_LIMIT=2.0
RUNNER_MEMORY_LIMIT=4G
RUNNER_CPU_RESERVE=0.5
RUNNER_MEMORY_RESERVE=1G

# Backup Configuration
BACKUP_INTERVAL=3600
BACKUP_RETENTION_DAYS=7
BACKUP_COMPRESSION=gzip

# Watchdog Configuration
WATCHDOG_INTERVAL=60
RESTART_UNHEALTHY=true
MAX_RESTART_ATTEMPTS=3
```

### Service Endpoints

- **Runner Health**: https://localhost/runner/health
- **Prometheus Metrics**: https://localhost/metrics/
- **Node Exporter**: https://localhost/monitor/
- **Nginx Status**: http://localhost:8080/nginx_status

## Monitoring

### Prometheus Metrics

The setup includes comprehensive metrics collection:

- System metrics (CPU, memory, disk, network)
- Container metrics (Docker stats, health checks)
- Application metrics (runner performance, job statistics)
- Custom alerts for critical conditions

### Alerting Rules

Pre-configured alerts for:
- Runner service downtime
- High resource usage (CPU, memory, disk)
- Container health failures
- Network connectivity issues
- Log processing lag

### Health Checks

All services include comprehensive health checks:
- HTTP endpoint monitoring
- Resource threshold checking
- Automatic restart on failure
- Escalation to manual intervention

## Backup and Recovery

### Automated Backups

The backup service automatically:
- Creates compressed backups of all persistent data
- Maintains configurable retention policies
- Logs all backup operations
- Provides restore capabilities

### Manual Backup

```bash
# Create immediate backup
docker-compose exec backup_service /backup/backup.sh

# List backup files
ls -la backups/

# Restore from backup
docker-compose down
# Restore volumes manually
docker-compose up -d
```

## Security

### Network Security

- Container-to-container communication isolated
- External access through nginx proxy only
- Rate limiting on all endpoints
- SSL/TLS termination with strong ciphers

### Access Control

- Metrics endpoints restricted to internal networks
- Health endpoints require authentication
- File permissions properly configured
- No-new-privileges security option

### Hardening

- Minimal container privileges
- Read-only filesystem where possible
- Security headers in nginx configuration
- Regular security updates via container rebuilds

## Troubleshooting

### Common Issues

1. **Runner not connecting to GitHub**:
   - Check `RUNNER_TOKEN` validity
   - Verify repository URL
   - Check network connectivity

2. **High resource usage**:
   - Review resource limits in docker-compose.yml
   - Check for memory leaks in logs
   - Monitor metrics in Prometheus

3. **Backup failures**:
   - Check disk space availability
   - Verify backup script permissions
   - Review backup service logs

### Logs

View logs for specific services:
```bash
# Runner logs
docker-compose logs runner

# All service logs
docker-compose logs -f

# Specific service logs
docker-compose logs -f health_monitor
```

### Health Status

Check service health:
```bash
# Overall health
curl -k https://localhost/health

# Individual service health
docker-compose ps
docker-compose exec watchdog /watchdog.sh
```

## Maintenance

### Updates

Update container images:
```bash
docker-compose pull
docker-compose up -d --force-recreate
```

### Cleanup

Remove old containers and volumes:
```bash
docker-compose down
docker system prune -a
```

### Performance Tuning

Adjust resource limits based on workload:
1. Monitor resource usage in Prometheus
2. Adjust CPU and memory limits in docker-compose.yml
3. Update backup intervals based on change frequency
4. Tune log retention policies

## Network Access

The configuration supports access to private IP `192.168.1.155`:
- Host network bridge configured
- Container routing enabled
- Firewall rules may need adjustment

## Production Considerations

1. **SSL Certificates**: Replace self-signed certificates with proper CA-signed certificates
2. **External Monitoring**: Integrate with external monitoring systems
3. **Log Forwarding**: Configure log forwarding to external systems
4. **Backup Storage**: Use external backup storage for disaster recovery
5. **Resource Scaling**: Adjust resource limits based on actual workload

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review service logs
3. Verify configuration against requirements
4. Monitor system resources and health endpoints