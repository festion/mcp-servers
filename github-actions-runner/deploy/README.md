# GitHub Actions Runner Deployment Automation

This directory contains a comprehensive deployment automation system for GitHub Actions runners with support for multiple environments, automated testing, and rollback capabilities.

## Features

- **One-command deployment** across dev, staging, and production environments
- **Environment-specific configurations** with proper secret management
- **Automated testing and validation** including health checks, functional tests, performance tests, and security scans
- **Rollback capabilities** with automated backup and restore procedures
- **Continuous deployment pipeline** with GitHub Actions integration
- **Infrastructure as Code** with Docker Compose, Terraform, and Ansible support
- **Comprehensive monitoring** with Prometheus and Grafana integration

## Directory Structure

```
deploy/
├── deploy.sh                    # Main deployment orchestration script
├── environments/               # Environment-specific configurations
│   ├── dev.env                 # Development environment
│   ├── staging.env             # Staging environment
│   └── prod.env                # Production environment
├── scripts/                    # Deployment scripts
│   ├── common.sh               # Common functions and utilities
│   ├── pre-deploy.sh           # Pre-deployment validation
│   ├── post-deploy.sh          # Post-deployment verification
│   ├── deploy-config.sh        # Configuration deployment
│   ├── deploy-app.sh           # Application deployment
│   └── rollback.sh             # Rollback procedures
├── infrastructure/             # Infrastructure as Code
│   ├── docker-compose.yml.template
│   ├── deploy-infrastructure.sh
│   ├── terraform/              # Terraform configurations
│   ├── ansible/                # Ansible playbooks
│   └── kubernetes/             # Kubernetes manifests
├── validation/                 # Testing and validation
│   ├── health-check.sh         # Health monitoring
│   ├── functional-tests.sh     # Functional testing
│   ├── performance-tests.sh    # Performance testing
│   └── security-scan.sh        # Security validation
├── pipelines/                  # CI/CD pipelines
│   ├── deploy.yml              # Main deployment pipeline
│   └── rollback.yml            # Rollback pipeline
└── logs/                       # Deployment logs
    ├── deployments.log         # Deployment history
    └── rollbacks.log           # Rollback history
```

## Quick Start

### 1. Environment Setup

Configure your environment variables in the appropriate `.env` file:

```bash
# Example for development
cp environments/dev.env.example environments/dev.env
# Edit the file with your actual values
```

### 2. Deploy to Development

```bash
./deploy.sh dev deploy latest
```

### 3. Deploy to Staging

```bash
./deploy.sh staging deploy v1.0.0
```

### 4. Deploy to Production

```bash
./deploy.sh prod deploy v1.0.0
```

## Environment Configuration

Each environment has its own configuration file in the `environments/` directory:

- `dev.env` - Development environment with debug enabled
- `staging.env` - Staging environment with SSL and monitoring
- `prod.env` - Production environment with full security and high availability

Key configuration parameters:

- `GITHUB_TOKEN` - GitHub personal access token for runner registration
- `GITHUB_ORG` - GitHub organization name
- `GITHUB_RUNNER_COUNT` - Number of runners to deploy
- `DEPLOY_HOST` - Target deployment host
- `ENABLE_SSL` - Enable SSL/TLS (required for production)
- `MONITORING_PORT` - Prometheus monitoring port
- `BACKUP_DIR` - Backup storage directory

## Deployment Commands

### Basic Deployment

```bash
./deploy.sh <environment> <operation> [version]
```

**Operations:**
- `deploy` - Deploy application
- `rollback` - Rollback to previous version
- `status` - Show deployment status

**Examples:**
```bash
# Deploy latest version to development
./deploy.sh dev deploy

# Deploy specific version to production
./deploy.sh prod deploy v1.2.3

# Show deployment status
./deploy.sh prod status

# Rollback to previous version
./deploy.sh prod rollback
```

### Advanced Operations

```bash
# Run pre-deployment validation only
./scripts/pre-deploy.sh prod

# Run post-deployment verification
./scripts/post-deploy.sh prod

# Execute rollback to specific version
./scripts/rollback.sh prod v1.1.0
```

## Testing and Validation

### Health Checks

```bash
./validation/health-check.sh <environment>
```

Validates:
- Service health and availability
- GitHub runner registration
- Container status
- Network connectivity
- Resource usage
- Log aggregation
- Backup system
- Security configuration

### Functional Tests

```bash
./validation/functional-tests.sh <environment>
```

Tests:
- Runner registration with GitHub
- Workflow execution capabilities
- Container networking
- Volume mounts
- Service discovery
- Monitoring integration
- Log aggregation
- Backup functionality
- Security configuration
- Rollback capability

### Performance Tests

```bash
./validation/performance-tests.sh <environment>
```

Evaluates:
- Response time
- Throughput
- Resource utilization
- Concurrent workflow handling
- Scaling performance
- Database performance
- Network performance
- Monitoring performance

### Security Scans

```bash
./validation/security-scan.sh <environment>
```

Scans for:
- Container vulnerabilities
- Secrets exposure
- Network security
- File permissions
- SSL configuration
- Docker security
- GitHub security
- Backup security

## Rollback Procedures

### Automatic Rollback

The deployment system automatically creates backups and supports rollback:

```bash
# Rollback to previous version
./deploy.sh prod rollback

# Rollback to specific version
./scripts/rollback.sh prod v1.1.0
```

### Manual Rollback

```bash
# 1. Stop current services
docker-compose -f infrastructure/docker-compose.yml down

# 2. Restore configuration
cp -r /backup/version-v1.1.0/* ./

# 3. Start services
docker-compose -f infrastructure/docker-compose.yml up -d

# 4. Verify deployment
./validation/health-check.sh prod
```

## Continuous Deployment

### GitHub Actions Integration

The deployment system includes GitHub Actions workflows:

- **Deploy Pipeline** (`pipelines/deploy.yml`): Automated deployment on push/PR
- **Rollback Pipeline** (`pipelines/rollback.yml`): Manual rollback workflow

### Pipeline Features

- Automated testing and validation
- Multi-environment deployment (dev → staging → prod)
- Approval gates for production deployments
- Automatic rollback on failure
- Slack/email notifications
- Deployment tracking and reporting

## Monitoring and Logging

### Prometheus Metrics

The deployment includes Prometheus monitoring:

- GitHub runner metrics
- Container health and resource usage
- Deployment success/failure rates
- Performance metrics

### Grafana Dashboards

Pre-configured dashboards for:

- Runner status and activity
- System resource utilization
- Deployment history
- Error rates and alerts

### Log Aggregation

Centralized logging with:

- Structured JSON logging
- Log rotation and retention
- Error tracking and alerting
- Audit trail for deployments

## Security

### Best Practices

- **Secret Management**: Use Docker secrets and environment variables
- **Network Security**: Isolated Docker networks with firewall rules
- **SSL/TLS**: Required for production environments
- **Access Control**: Least privilege principle for GitHub tokens
- **Vulnerability Scanning**: Regular container and dependency scans
- **Backup Security**: Encrypted backups with proper permissions

### Security Validation

The security scan validates:

- Container vulnerabilities (CVE scanning)
- Secrets exposure detection
- Network configuration security
- File and directory permissions
- SSL/TLS configuration
- Docker security best practices
- GitHub token permissions
- Backup security

## Troubleshooting

### Common Issues

1. **Deployment Failures**
   ```bash
   # Check logs
   docker-compose logs
   
   # Validate environment
   ./scripts/pre-deploy.sh <env>
   
   # Check system resources
   df -h && free -h
   ```

2. **GitHub Runner Issues**
   ```bash
   # Check runner status
   curl -H "Authorization: token $GITHUB_TOKEN" \
        https://api.github.com/orgs/$GITHUB_ORG/actions/runners
   
   # Check container logs
   docker logs github-runner-1
   ```

3. **Network Issues**
   ```bash
   # Test connectivity
   ./validation/health-check.sh <env>
   
   # Check Docker networks
   docker network ls
   docker network inspect github-runner-network
   ```

### Recovery Procedures

1. **Service Recovery**
   ```bash
   # Restart services
   docker-compose restart
   
   # Rebuild and restart
   docker-compose up -d --force-recreate
   ```

2. **Database Recovery**
   ```bash
   # Restore from backup
   ./scripts/restore-database.sh <backup-file>
   ```

3. **Full System Recovery**
   ```bash
   # Complete rollback
   ./scripts/rollback.sh <env> <version>
   ```

## Contributing

1. **Development Workflow**
   - Create feature branch
   - Test on development environment
   - Submit pull request
   - Automated testing and validation
   - Deploy to staging for integration testing
   - Deploy to production after approval

2. **Testing Requirements**
   - All scripts must pass shellcheck
   - Deployment must pass all validation tests
   - Security scans must pass
   - Performance tests must meet thresholds

3. **Documentation**
   - Update README for new features
   - Document configuration changes
   - Update troubleshooting guide

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review deployment logs in `logs/`
3. Run validation scripts for diagnostics
4. Check GitHub Actions workflow logs
5. Contact the platform team

## License

This deployment automation system is part of the GitHub Actions runner infrastructure and follows the same licensing terms as the main project.